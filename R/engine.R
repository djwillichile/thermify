# Internal computation engine shared by thermify() and thermify_rast().
#
# All inputs are matrices with one row per location (cell) and one column per
# day (daily extremes) or per hour (hourly temperatures). The engine never
# reads or writes files.

thermal_config <- function(indices = c("gdd", "ch", "cu", "cp"),
                           gdd_methods = c("average", "single_sine"),
                           base = c(5, 10), upper = NULL,
                           cutoff = "horizontal",
                           ch_methods = "sine", ch_lower = 0, ch_upper = 7.2,
                           hourly_method = "linvill",
                           chill_period = c("05-01", "08-31"),
                           heat_period = c("09-01", "04-30")) {
  indices <- unique(match.arg(indices, c("gdd", "ch", "cu", "cp"),
                              several.ok = TRUE))
  gdd_methods <- unique(match.arg(gdd_methods,
    c("average", "single_sine", "single_triangle", "double_sine",
      "double_triangle", "hourly"), several.ok = TRUE))
  ch_methods <- unique(match.arg(ch_methods, c("sine", "triangle", "hourly"),
                                 several.ok = TRUE))
  cutoff <- match.arg(cutoff, c("horizontal", "vertical", "intermediate"))
  hourly_method <- match.arg(hourly_method, c("linvill", "sine"))
  check_numeric(base, "base", allow_na = FALSE)
  if (anyDuplicated(base)) stop("`base` values must be unique.", call. = FALSE)
  for (b in base) check_thresholds(b, upper)
  check_chill_bounds(ch_lower, ch_upper)
  for (p in list(chill_period, heat_period)) {
    if (length(p) != 2L) stop("Periods must be c(\"MM-DD\", \"MM-DD\").",
                              call. = FALSE)
    parse_mmdd(p[1], "period start")
    parse_mmdd(p[2], "period end")
  }
  list(indices = indices, gdd_methods = gdd_methods, base = base,
       upper = upper, cutoff = cutoff, ch_methods = ch_methods,
       ch_lower = ch_lower, ch_upper = ch_upper,
       hourly_method = hourly_method, chill_period = chill_period,
       heat_period = heat_period)
}

needs_hourly <- function(cfg) {
  any(c("cu", "cp") %in% cfg$indices) ||
    ("gdd" %in% cfg$indices && "hourly" %in% cfg$gdd_methods) ||
    ("ch" %in% cfg$indices && "hourly" %in% cfg$ch_methods)
}

# Lead by one column (next day), wrapping when cyclic.
lead_cols <- function(m, cyclic) {
  n <- ncol(m)
  nxt <- if (n > 1L) m[, c(2:n, if (cyclic) 1L else NA), drop = FALSE] else
    m[, if (cyclic) 1L else NA, drop = FALSE]
  nxt
}

matrix_like <- function(v, ref) {
  dim(v) <- dim(ref)
  v
}

day_columns <- function(n_days, days) {
  as.vector(outer(1:24, (days - 1L) * 24L, `+`))
}

# Compute daily index values. Returns a named list of (cell x day) matrices.
compute_daily <- function(dmin, dmax, dates, cyclic, cfg, hourly = NULL,
                          latitude = NULL) {
  out <- list()
  n_days <- ncol(dmin)
  if (needs_hourly(cfg) && is.null(hourly)) {
    hourly <- hourly_temperatures(dmin, dmax, method = cfg$hourly_method,
                                  latitude = latitude,
                                  doy = as.integer(format(dates, "%j")),
                                  cyclic = cyclic)
  }

  if ("gdd" %in% cfg$indices) {
    nxt <- lead_cols(dmin, cyclic)
    for (m in cfg$gdd_methods) for (b in cfg$base) {
      key <- sprintf("gdd_%s_b%s", m, format(b))
      out[[key]] <- if (m == "hourly") {
        degree_hours(hourly, base = b, upper = cfg$upper,
                     cutoff = cfg$cutoff, by_day = TRUE)
      } else {
        matrix_like(degree_days(as.vector(dmin), as.vector(dmax), method = m,
                                base = b, upper = cfg$upper,
                                cutoff = cfg$cutoff,
                                tmin_next = as.vector(nxt)), dmin)
      }
    }
  }

  if ("ch" %in% cfg$indices) {
    for (m in cfg$ch_methods) {
      out[[paste0("ch_", m)]] <- if (m == "hourly") {
        hours_to_days(chill_hours_hourly(hourly, cfg$ch_lower, cfg$ch_upper,
                                         output = "hourly"), "sum")
      } else {
        matrix_like(chill_hours(as.vector(dmin), as.vector(dmax), method = m,
                                lower = cfg$ch_lower, upper = cfg$ch_upper),
                    dmin)
      }
    }
  }

  if (any(c("cu", "cp") %in% cfg$indices)) {
    idx <- season_days(dates, cfg$chill_period[1], cfg$chill_period[2],
                       cyclic = cyclic)
    season <- attr(idx, "season")
    if ("cu" %in% cfg$indices) {
      cu <- matrix(NA_real_, nrow(dmin), n_days)
      cu[, idx] <- hours_to_days(chill_units(
        hourly[, day_columns(n_days, idx), drop = FALSE], output = "hourly"),
        "sum")
      out$cu_utah <- cu
    }
    if ("cp" %in% cfg$indices) {
      cp <- matrix(NA_real_, nrow(dmin), n_days)
      # The Dynamic model state runs continuously through each season and is
      # restarted only at the start of a new season.
      for (s in unique(season)) {
        days <- idx[season == s]
        cp[, days] <- hours_to_days(chill_portions(
          hourly[, day_columns(n_days, days), drop = FALSE],
          output = "hourly"), "sum")
      }
      out$cp_dynamic <- cp
    }
  }
  attr(out, "hourly") <- hourly
  out
}

# Aggregate daily index matrices to annual, seasonal and monthly totals.
# Returns a named list of (cell x layer) matrices.
aggregate_daily <- function(daily, dates, cyclic, cfg,
                            temporal = c("season", "annual", "monthly")) {
  month <- as.integer(format(dates, "%m"))
  res <- list()
  for (key in names(daily)) {
    v <- daily[[key]]
    is_chill <- !startsWith(key, "gdd_")
    period <- if (is_chill) cfg$chill_period else cfg$heat_period
    idx <- season_days(dates, period[1], period[2], cyclic = cyclic)
    season <- attr(idx, "season")
    layers <- list()
    if ("season" %in% temporal) {
      seasons <- unique(season)
      for (s in seasons) {
        nm <- if (cyclic || length(seasons) == 1L) "season" else
          paste0("season_", s)
        layers[[nm]] <- rowSums(v[, idx[season == s], drop = FALSE])
      }
    }
    if ("annual" %in% temporal && !key %in% c("cu_utah", "cp_dynamic")) {
      layers$annual <- rowSums(v)
    }
    if ("monthly" %in% temporal) {
      for (m in 1:12) {
        cols <- which(month == m)
        if (is_chill && key %in% c("cu_utah", "cp_dynamic")) {
          cols <- intersect(cols, idx)
        }
        layers[[sprintf("m%02d", m)]] <- if (length(cols)) {
          rowSums(v[, cols, drop = FALSE])
        } else {
          rep(NA_real_, nrow(v))
        }
      }
    }
    res[[key]] <- do.call(cbind, layers)
  }
  res
}

index_units <- function(key) {
  if (startsWith(key, "gdd_")) return("degC day")
  switch(sub("_.*", "", key), ch = "h", cu = "chill units", cp = "portions")
}
