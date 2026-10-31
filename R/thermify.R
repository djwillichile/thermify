#' Compute several thermal indices for one location
#'
#' Integrated workflow: (optionally) densify monthly climatologies to daily
#' extremes, (optionally) reconstruct hourly temperatures, and compute
#' growing degree-days, chilling hours, Utah chill units and Dynamic model
#' chill portions with explicit accumulation periods.
#'
#' @section Input frequency:
#' The frequency is never inferred from the number of values; set `input`:
#' * `"monthly"`: `tmin`, `tmax` are 12 climatological monthly means. They
#'   are densified with [densify_monthly()] for the reference `year` and
#'   treated as a closed annual cycle. Results are climatological estimates,
#'   not observations of `year`.
#' * `"daily"`: `tmin`, `tmax` are daily extremes on `dates`.
#' * `"hourly"`: `temperature` holds `24 * length(dates)` hourly values
#'   starting at hour 0 of `dates[1]`. Daily extremes are taken from the
#'   hourly data, and chilling and degree-hour indices use the observations
#'   directly.
#'
#' @param tmin,tmax Monthly (length 12) or daily minimum and maximum
#'   temperatures in degrees Celsius.
#' @param temperature Hourly temperatures (degrees Celsius) when
#'   `input = "hourly"`.
#' @param input `"monthly"`, `"daily"` or `"hourly"`.
#' @param dates Dates of the daily values (required for `"daily"` and
#'   `"hourly"`).
#' @param year Reference calendar year for monthly input. Default 2023.
#' @param latitude Latitude in decimal degrees, required for the Linvill
#'   hourly model.
#' @param temporal Densification engine for monthly input: `"auto"`,
#'   `"tempify"` or `"native"` (see [densify_monthly()]).
#' @param interpolation Densification method, default `"pchip_mp"`.
#' @param consistency `"check"` or `"mean_range"` (see [densify_monthly()]).
#' @param indices Any of `"gdd"`, `"ch"`, `"cu"`, `"cp"`.
#' @param gdd_methods GDD methods, see [degree_days()]; `"hourly"` uses
#'   [degree_hours()] on observed or reconstructed hourly temperatures.
#' @param base Lower GDD thresholds (degrees Celsius); one result per value.
#' @param upper,cutoff Upper GDD threshold and cutoff (see [degree_days()]).
#' @param ch_methods Chilling-hours methods: `"sine"`, `"triangle"` (from
#'   daily extremes) and/or `"hourly"` (counted on hourly temperatures).
#' @param ch_lower,ch_upper Chilling interval (degrees Celsius).
#' @param hourly_method Hourly reconstruction, `"linvill"` or `"sine"`.
#' @param chill_period,heat_period Accumulation windows as
#'   `c("MM-DD", "MM-DD")`. Defaults are southern-hemisphere conventions:
#'   chill from 1 May to 31 August, heat from 1 September to 30 April.
#'
#' @return An object of class `"thermify"`: a list with `daily` (data frame of
#'   daily temperatures and index values), `hourly` (data frame, when hourly
#'   temperatures were used or reconstructed), `summary` (long data frame of
#'   seasonal, annual and monthly totals with units), `config` and
#'   `provenance`.
#' @examples
#' tmin <- c(11.4, 11.1, 9.2, 6.8, 5.3, 3.9, 3.1, 3.6, 4.6, 6.3, 8.4, 10.3)
#' tmax <- c(29.6, 29.2, 26.5, 21.9, 17.2, 13.9, 13.6, 15.3, 17.9, 21.2,
#'           24.9, 28.2)
#' res <- thermify(tmin, tmax, input = "monthly", latitude = -35.97,
#'                 temporal = "native")
#' res
#' head(res$daily)
#' @export
thermify <- function(tmin = NULL, tmax = NULL, temperature = NULL,
                     input = c("monthly", "daily", "hourly"),
                     dates = NULL, year = 2023, latitude = NULL,
                     temporal = c("auto", "tempify", "native"),
                     interpolation = "pchip_mp",
                     consistency = c("check", "mean_range"),
                     indices = c("gdd", "ch", "cu", "cp"),
                     gdd_methods = c("average", "single_sine"),
                     base = c(5, 10), upper = NULL, cutoff = "horizontal",
                     ch_methods = "sine", ch_lower = 0, ch_upper = 7.2,
                     hourly_method = c("linvill", "sine"),
                     chill_period = c("05-01", "08-31"),
                     heat_period = c("09-01", "04-30")) {
  input <- match.arg(input)
  temporal <- match.arg(temporal)
  consistency <- match.arg(consistency)
  hourly_method <- match.arg(hourly_method)
  cfg <- thermal_config(indices, gdd_methods, base, upper, cutoff,
                        ch_methods, ch_lower, ch_upper, hourly_method,
                        chill_period, heat_period)
  provenance <- list(input = input, thermify = as.character(
    utils::packageVersion("thermify")), created = format(Sys.time(),
                                                         tz = "UTC"))
  hourly <- NULL

  if (input == "monthly") {
    if (length(tmin) != 12L || length(tmax) != 12L) {
      stop("Monthly input needs 12 values of `tmin` and `tmax`.",
           call. = FALSE)
    }
    dens <- densify_monthly(tmin, tmax, year = year, method = interpolation,
                            engine = temporal, consistency = consistency)
    dmin <- dens$tmin
    dmax <- dens$tmax
    dates <- dens$dates
    cyclic <- TRUE
    provenance$densification <- dens$provenance
  } else {
    if (!inherits(dates, "Date")) {
      stop("`dates` (class Date) is required for daily and hourly input.",
           call. = FALSE)
    }
    if (any(diff(dates) != 1)) {
      stop("`dates` must be consecutive days.", call. = FALSE)
    }
    cyclic <- FALSE
    if (input == "hourly") {
      check_numeric(temperature, "temperature")
      if (length(temperature) != 24L * length(dates)) {
        stop("`temperature` must contain 24 values per date.", call. = FALSE)
      }
      hourly <- matrix(temperature, nrow = 1L)
      daymat <- matrix(temperature, nrow = 24L)
      dmin <- matrix(apply(daymat, 2L, min), nrow = 1L)
      dmax <- matrix(apply(daymat, 2L, max), nrow = 1L)
    } else {
      check_tmin_tmax(tmin, tmax)
      if (length(tmin) != length(dates)) {
        stop("`tmin` and `dates` must have the same length.", call. = FALSE)
      }
      dmin <- matrix(tmin, nrow = 1L)
      dmax <- matrix(tmax, nrow = 1L)
    }
  }
  if (needs_hourly(cfg) && is.null(hourly) && cfg$hourly_method == "linvill"
      && is.null(latitude)) {
    stop("`latitude` is required to reconstruct hourly temperatures with ",
         "the Linvill model (or use hourly_method = \"sine\").", call. = FALSE)
  }

  daily <- compute_daily(dmin, dmax, dates, cyclic, cfg, hourly = hourly,
                         latitude = latitude)
  hourly <- attr(daily, "hourly")
  agg <- aggregate_daily(daily, dates, cyclic, cfg)

  daily_df <- data.frame(date = dates, doy = as.integer(format(dates, "%j")),
                         month = as.integer(format(dates, "%m")),
                         tmin = as.vector(dmin), tmax = as.vector(dmax))
  for (k in names(daily)) daily_df[[k]] <- as.vector(daily[[k]])

  summary_df <- do.call(rbind, lapply(names(agg), function(k) {
    v <- agg[[k]][1L, ]
    parts <- strsplit(k, "_")[[1]]
    data.frame(index = parts[1], key = k, aggregation = names(v),
               value = unname(v), units = index_units(k),
               stringsAsFactors = FALSE)
  }))
  rownames(summary_df) <- NULL

  hourly_df <- NULL
  if (!is.null(hourly)) {
    hourly_df <- data.frame(
      date = rep(dates, each = 24L), hour = rep(0:23, length(dates)),
      temperature = as.vector(hourly),
      reconstructed = input != "hourly")
  }
  provenance$hourly <- if (input == "hourly") "observed" else if
    (!is.null(hourly)) cfg$hourly_method else "not used"
  provenance$cyclic <- cyclic

  structure(list(daily = daily_df, hourly = hourly_df, summary = summary_df,
                 config = cfg, provenance = provenance),
            class = "thermify")
}

#' @export
print.thermify <- function(x, ...) {
  cat("<thermify> ", x$provenance$input, " input, ", nrow(x$daily),
      " days", if (isTRUE(x$provenance$cyclic)) " (climatological cycle)",
      "\n", sep = "")
  if (!is.null(x$provenance$densification)) {
    d <- x$provenance$densification
    cat("Densification: ", d$method, " via ", d$engine,
        sprintf(" (max |monthly mean error| = %.2g degC)",
                d$max_abs_mean_error), "\n", sep = "")
  }
  cat("Hourly temperatures: ", x$provenance$hourly, "\n", sep = "")
  s <- x$summary[grepl("^season", x$summary$aggregation) |
                   x$summary$aggregation == "annual", ]
  s$value <- round(s$value, 1)
  print(s[, c("key", "aggregation", "value", "units")], row.names = FALSE)
  invisible(x)
}
