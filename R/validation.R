#' Prepare an hourly station record for validation
#'
#' Puts hourly temperature observations on a regular hourly grid of complete
#' days, fills short gaps by linear interpolation and flags days that remain
#' incomplete. The result is the input of [validate_station()].
#'
#' @section Quality control:
#' * Timestamps are rounded down to the hour; several values within the same
#'   hour are averaged.
#' * Internal gaps of at most `max_gap` consecutive hours are filled by linear
#'   interpolation between the neighbouring observations. Longer gaps are left
#'   missing.
#' * A day is valid when all its 24 hours are available after filling.
#' * Values outside `range` (degrees C) are treated as missing before
#'   filling.
#'
#' @param time Observation times (`POSIXct`), in local standard time. Each
#'   value marks the start of its hour.
#' @param temperature Hourly air temperature in degrees C.
#' @param max_gap Longest run of missing hours filled by interpolation.
#' @param range Plausible temperature range; values outside are set to `NA`.
#' @return An object of class `"station_hourly"`: a list with `dates`,
#'   `hourly` (matrix, one row per day and 24 columns for hours 0-23),
#'   `valid` (logical per day), and `quality` (counts of hours observed,
#'   filled and missing, and of valid days).
#' @seealso [validate_station()]
#' @export
prepare_station_hourly <- function(time, temperature, max_gap = 2,
                                   range = c(-40, 55)) {
  if (!inherits(time, "POSIXct")) {
    stop("`time` must be POSIXct.", call. = FALSE)
  }
  check_numeric(temperature, "temperature")
  if (length(time) != length(temperature)) {
    stop("`time` and `temperature` must have the same length.", call. = FALSE)
  }
  check_scalar(max_gap, "max_gap")
  temperature[!is.na(temperature) &
                (temperature < range[1] | temperature > range[2])] <- NA
  tz <- attr(time, "tzone")
  if (is.null(tz) || !nzchar(tz)) tz <- "UTC"
  hour_start <- as.POSIXct(trunc(time, "hours"))
  keep <- !is.na(hour_start)
  agg <- tapply(temperature[keep], format(hour_start[keep], "%Y-%m-%d %H"),
                function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE))
  stamps <- as.POSIXct(names(agg), format = "%Y-%m-%d %H", tz = tz)
  days <- as.Date(format(stamps, "%Y-%m-%d"))
  dates <- seq(min(days), max(days), by = "day")
  grid <- as.POSIXct(paste(rep(format(dates), each = 24),
                           sprintf("%02d", rep(0:23, length(dates)))),
                     format = "%Y-%m-%d %H", tz = tz)
  values <- rep(NA_real_, length(grid))
  values[match(format(stamps, "%Y-%m-%d %H"),
               format(grid, "%Y-%m-%d %H"))] <- as.numeric(agg)
  n_observed <- sum(!is.na(values))
  filled <- fill_short_gaps(values, max_gap)
  n_filled <- sum(is.na(values) & !is.na(filled))
  hourly <- matrix(filled, ncol = 24, byrow = TRUE)
  valid <- stats::complete.cases(hourly)
  structure(list(
    dates = dates, hourly = hourly, valid = valid,
    quality = list(hours = length(values), observed = n_observed,
                   filled = n_filled,
                   missing = sum(is.na(filled)),
                   days = length(dates), valid_days = sum(valid),
                   max_gap = max_gap)),
    class = "station_hourly")
}

#' @export
print.station_hourly <- function(x, ...) {
  q <- x$quality
  cat("<station_hourly> ", format(min(x$dates)), " to ", format(max(x$dates)),
      "\n", sep = "")
  cat(sprintf("  days: %d (%d valid, %.1f%%)\n", q$days, q$valid_days,
              100 * q$valid_days / q$days))
  cat(sprintf("  hours: %d observed, %d filled (gaps <= %d h), %d missing\n",
              q$observed, q$filled, q$max_gap, q$missing))
  invisible(x)
}

# Linear interpolation of internal NA runs no longer than max_gap.
fill_short_gaps <- function(x, max_gap) {
  na <- is.na(x)
  if (!any(na) || all(na)) return(x)
  r <- rle(na)
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1L
  ok <- which(r$values & r$lengths <= max_gap & starts > 1L &
                ends < length(x))
  if (!length(ok)) return(x)
  idx <- seq_along(x)
  interp <- stats::approx(idx[!na], x[!na], xout = idx)$y
  for (k in ok) x[starts[k]:ends[k]] <- interp[starts[k]:ends[k]]
  x
}

#' Agreement metrics between estimated and observed values
#'
#' @param estimate,observed Numeric vectors of equal length.
#' @return A one-row data frame with `n`, `bias` (mean of estimate minus
#'   observed), `mae`, `rmse`, `rel_bias` (bias as a percentage of the mean
#'   observed value; `NA` when that mean is close to zero, for example for
#'   Utah units) and `r` (Pearson correlation; `NA` with fewer than three
#'   pairs or no variance).
#' @examples
#' validation_metrics(c(10, 12, 9), c(11, 11, 10))
#' @export
validation_metrics <- function(estimate, observed) {
  check_numeric(estimate, "estimate")
  check_numeric(observed, "observed")
  if (length(estimate) != length(observed)) {
    stop("`estimate` and `observed` must have the same length.", call. = FALSE)
  }
  ok <- !is.na(estimate) & !is.na(observed)
  e <- estimate[ok] - observed[ok]
  n <- sum(ok)
  mean_obs <- if (n) mean(observed[ok]) else NA_real_
  rel <- if (n && abs(mean_obs) > 1e-8 * max(1, max(abs(observed[ok])))) {
    100 * mean(e) / mean_obs
  } else {
    NA_real_
  }
  r <- if (n >= 3 && stats::sd(estimate[ok]) > 0 && stats::sd(observed[ok]) > 0)
    stats::cor(estimate[ok], observed[ok]) else NA_real_
  data.frame(n = n, bias = if (n) mean(e) else NA_real_,
             mae = if (n) mean(abs(e)) else NA_real_,
             rmse = if (n) sqrt(mean(e^2)) else NA_real_,
             rel_bias = rel, r = r)
}

#' Validate thermal-index estimates against an hourly station record
#'
#' Computes "observed" indices directly from hourly observations and compares
#' them with the estimates thermify produces from progressively less
#' information:
#'
#' * level `"daily"`: daily extremes of the same station, with the analytical
#'   daily methods (GDD, chilling hours) and with hourly reconstructions
#'   (Linvill, sine) for chilling hours, Utah units and chill portions. This
#'   isolates the error of the diurnal model.
#' * level `"monthly"`: the station's own monthly climatology (mean daily
#'   extremes per calendar month over all valid days), densified with
#'   `pchip_mp`. This adds the loss of day-to-day variability and of
#'   interannual variability: one climatological value is compared with each
#'   season.
#' * level `"gridded"` (optional): a monthly climatology from a gridded
#'   product, for example the WorldClim cell containing the station. This adds
#'   the spatial interpolation error and the difference between climate
#'   normal periods.
#'
#' Only complete seasons are evaluated: a season is excluded when any of its
#' days is invalid after gap filling (see [prepare_station_hourly()]) or when
#' the record does not cover the whole window. Excluded seasons are reported.
#'
#' @param station An object from [prepare_station_hourly()].
#' @param latitude Station latitude in decimal degrees (Linvill model).
#' @param indices Any of `"gdd"`, `"ch"`, `"cu"`, `"cp"`.
#' @param base,upper,cutoff GDD thresholds and cutoff (see [degree_days()]).
#' @param gdd_methods Daily GDD methods to evaluate.
#' @param hourly_methods Hourly reconstructions to evaluate: `"linvill"`
#'   and/or `"sine"`.
#' @param ch_lower,ch_upper Chilling interval (degrees C).
#' @param chill_period,heat_period Accumulation windows (see [thermify()]).
#' @param gridded Optional list with numeric vectors `tmin` and `tmax` of
#'   length 12 (monthly climatology at the station location).
#' @param temporal Densification engine for the monthly levels.
#' @return An object of class `"thermify_validation"`: a list with
#'   `seasons` (one row per season, index, level and method, with
#'   `estimate` and `observed`), `metrics` (one row per index, level and
#'   method, from [validation_metrics()]), `excluded` (seasons not evaluated
#'   and why) and `quality` (from the station object).
#' @seealso [prepare_station_hourly()], [validation_metrics()],
#'   `vignette("validation")`.
#' @export
validate_station <- function(station, latitude,
                             indices = c("gdd", "ch", "cu", "cp"),
                             base = 10, upper = NULL, cutoff = "horizontal",
                             gdd_methods = c("average", "single_sine",
                                             "single_triangle",
                                             "double_sine",
                                             "double_triangle"),
                             hourly_methods = c("linvill", "sine"),
                             ch_lower = 0, ch_upper = 7.2,
                             chill_period = c("05-01", "08-31"),
                             heat_period = c("09-01", "04-30"),
                             gridded = NULL,
                             temporal = c("native", "auto", "tempify")) {
  if (!inherits(station, "station_hourly")) {
    stop("`station` must come from prepare_station_hourly().", call. = FALSE)
  }
  temporal <- match.arg(temporal)
  check_scalar(latitude, "latitude")
  hourly_methods <- match.arg(hourly_methods, c("linvill", "sine"),
                              several.ok = TRUE)
  cfg <- thermal_config(indices, gdd_methods, base, upper, cutoff,
                        "sine", ch_lower, ch_upper, hourly_methods[1],
                        chill_period, heat_period)
  if (length(base) != 1L) {
    stop("Validate one `base` at a time.", call. = FALSE)
  }
  if (!is.null(gridded)) {
    if (!is.list(gridded) || length(gridded$tmin) != 12L ||
        length(gridded$tmax) != 12L) {
      stop("`gridded` must be a list with 12 monthly `tmin` and `tmax`.",
           call. = FALSE)
    }
  }

  dates <- station$dates
  hourly <- station$hourly
  tmin <- suppressWarnings(apply(hourly, 1L, min))
  tmax <- suppressWarnings(apply(hourly, 1L, max))
  doy <- as.integer(format(dates, "%j"))
  tmin_next <- c(tmin[-1L], NA_real_)

  # Hourly reconstructions from daily extremes over the whole record, so that
  # every day has its true neighbours. Invalid days propagate NA.
  recon <- lapply(hourly_methods, function(m) {
    h <- hourly_temperatures(ifelse(is.na(tmin), 0, tmin),
                             ifelse(is.na(tmax), 0, tmax), method = m,
                             latitude = latitude, doy = doy)
    h <- matrix(h, ncol = 24, byrow = TRUE)
    h[!station$valid, ] <- NA
    h
  })
  names(recon) <- hourly_methods

  rows <- list()
  excluded <- list()
  add <- function(season, index, period, level, method, estimate, observed) {
    rows[[length(rows) + 1L]] <<- data.frame(
      season = season, index = index, period = period, level = level,
      method = method, estimate = estimate, observed = observed,
      stringsAsFactors = FALSE)
  }
  flat <- function(m) as.vector(t(m))

  for (idx_name in cfg$indices) {
    is_heat <- idx_name == "gdd"
    window <- if (is_heat) cfg$heat_period else cfg$chill_period
    sel <- season_days(dates, window[1], window[2])
    labels <- attr(sel, "season")
    for (s in unique(labels)) {
      days <- sel[labels == s]
      expected <- window_length(s, window)
      if (length(days) != expected) {
        excluded[[length(excluded) + 1L]] <- data.frame(
          index = idx_name, season = s, reason = "incomplete window")
        next
      }
      if (!all(station$valid[days])) {
        excluded[[length(excluded) + 1L]] <- data.frame(
          index = idx_name, season = s,
          reason = sprintf("%d invalid day(s)", sum(!station$valid[days])))
        next
      }
      obs_h <- flat(hourly[days, , drop = FALSE])
      if (idx_name == "gdd") {
        observed <- sum(degree_hours(obs_h, base = base, upper = upper,
                                     cutoff = cutoff)) / 24
        for (m in cfg$gdd_methods) {
          nxt <- tmin_next[days]
          if (m %in% c("double_sine", "double_triangle") &&
              is.na(nxt[length(nxt)])) {
            nxt[length(nxt)] <- tmin[days[length(days)]]
          }
          est <- sum(degree_days(tmin[days], tmax[days], method = m,
                                 base = base, upper = upper, cutoff = cutoff,
                                 tmin_next = nxt))
          add(s, "gdd", paste(window, collapse = "/"), "daily", m, est,
              observed)
        }
      } else {
        observed <- switch(idx_name,
          ch = sum(chill_hours_hourly(obs_h, ch_lower, ch_upper,
                                      output = "hourly")),
          cu = as.vector(chill_units(obs_h, output = "total")),
          cp = as.vector(chill_portions(obs_h, output = "total")))
        if (idx_name == "ch") {
          add(s, "ch", paste(window, collapse = "/"), "daily", "sine",
              sum(chill_hours(tmin[days], tmax[days], lower = ch_lower,
                              upper = ch_upper)), observed)
        }
        for (m in hourly_methods) {
          rh <- flat(recon[[m]][days, , drop = FALSE])
          est <- switch(idx_name,
            ch = sum(chill_hours_hourly(rh, ch_lower, ch_upper,
                                        output = "hourly")),
            cu = as.vector(chill_units(rh, output = "total")),
            cp = as.vector(chill_portions(rh, output = "total")))
          add(s, idx_name, paste(window, collapse = "/"), "daily",
              paste0("hourly_", m), est, observed)
        }
      }
    }
  }
  seasons <- if (length(rows)) do.call(rbind, rows) else
    data.frame(season = integer(), index = character(), period = character(),
               level = character(), method = character(),
               estimate = numeric(), observed = numeric())

  # Monthly levels: one climatological estimate per index and method,
  # compared with every evaluated season.
  month <- as.integer(format(dates, "%m"))
  clim <- list(
    monthly = list(
      tmin = as.vector(tapply(tmin[station$valid], month[station$valid],
                              mean)),
      tmax = as.vector(tapply(tmax[station$valid], month[station$valid],
                              mean))))
  if (!is.null(gridded)) clim$gridded <- gridded
  evaluated <- unique(seasons[, c("season", "index", "period")])
  if (nrow(evaluated)) {
    for (lvl in names(clim)) {
      cl <- clim[[lvl]]
      if (length(cl$tmin) != 12L || anyNA(cl$tmin) || anyNA(cl$tmax)) {
        excluded[[length(excluded) + 1L]] <- data.frame(
          index = "all", season = NA_integer_,
          reason = sprintf("%s climatology incomplete", lvl))
        next
      }
      for (m in hourly_methods) {
        res <- thermify(cl$tmin, cl$tmax, input = "monthly",
                        latitude = latitude, temporal = temporal,
                        indices = cfg$indices, gdd_methods = cfg$gdd_methods,
                        base = base, upper = upper, cutoff = cutoff,
                        ch_methods = c("sine", "hourly"),
                        ch_lower = ch_lower, ch_upper = ch_upper,
                        hourly_method = m, chill_period = chill_period,
                        heat_period = heat_period)
        sm <- res$summary[res$summary$aggregation == "season", ]
        for (k in seq_len(nrow(sm))) {
          key <- sm$key[k]
          idx_name <- sub("_.*", "", key)
          method <- switch(idx_name,
            gdd = sub("^gdd_(.*)_b.*$", "\\1", key),
            ch = if (key == "ch_sine") "sine" else paste0("hourly_", m),
            paste0("hourly_", m))
          # Daily analytical methods do not depend on the hourly model: add
          # them only once.
          if (idx_name == "gdd" && m != hourly_methods[1]) next
          if (key == "ch_sine" && m != hourly_methods[1]) next
          ev <- evaluated[evaluated$index == idx_name, ]
          for (j in seq_len(nrow(ev))) {
            obs <- seasons$observed[seasons$index == idx_name &
                                      seasons$season == ev$season[j]][1]
            add(ev$season[j], idx_name, ev$period[j], lvl, method,
                sm$value[k], obs)
          }
        }
      }
    }
    seasons <- do.call(rbind, rows)
  }

  metrics <- if (nrow(seasons)) {
    groups <- unique(seasons[, c("index", "level", "method")])
    do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
      g <- groups[i, ]
      sub <- seasons[seasons$index == g$index & seasons$level == g$level &
                       seasons$method == g$method, ]
      cbind(g, validation_metrics(sub$estimate, sub$observed),
            row.names = NULL)
    }))
  } else {
    data.frame()
  }
  rownames(seasons) <- NULL
  structure(list(
    seasons = seasons, metrics = metrics,
    excluded = if (length(excluded)) do.call(rbind, excluded) else
      data.frame(index = character(), season = integer(),
                 reason = character()),
    quality = station$quality,
    config = list(latitude = latitude, base = base, upper = upper,
                  cutoff = cutoff, hourly_methods = hourly_methods,
                  chill_period = chill_period, heat_period = heat_period,
                  ch_lower = ch_lower, ch_upper = ch_upper,
                  temporal = temporal, gridded = !is.null(gridded))),
    class = "thermify_validation")
}

# Number of days of a seasonal window starting in calendar year `start_year`.
window_length <- function(start_year, window) {
  s <- as.Date(sprintf("%d-%s", start_year, window[1]))
  e_year <- if (parse_mmdd(window[1], "start") > parse_mmdd(window[2], "end"))
    start_year + 1L else start_year
  e <- as.Date(sprintf("%d-%s", e_year, window[2]))
  as.integer(e - s) + 1L
}

#' @export
print.thermify_validation <- function(x, ...) {
  n <- length(unique(x$seasons$season))
  cat("<thermify_validation> ", n, " season(s) evaluated, ",
      nrow(x$excluded), " excluded\n", sep = "")
  if (nrow(x$metrics)) {
    m <- x$metrics
    num <- vapply(m, is.numeric, logical(1))
    m[num] <- lapply(m[num], round, 2)
    print(m, row.names = FALSE)
  }
  invisible(x)
}
