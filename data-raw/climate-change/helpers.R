# Helpers shared by the climate-change scripts (02 and 03).

heat_window <- c("09-01", "04-30")
chill_window <- c("05-01", "08-31")

# Season totals of the indices from an hourly record, for complete seasons
# only (every day valid after filling gaps of up to 2 hours), computed
# exactly as the reference of the CEAZA-Met validation.
season_indices <- function(time, temperature, which = c("gdd", "ch", "cu", "cp")) {
  st <- thermify::prepare_station_hourly(time, temperature, max_gap = 2)
  flat <- function(days) as.vector(t(st$hourly[days, , drop = FALSE]))
  out <- list()
  for (w in list(heat_window, chill_window)) {
    heat <- identical(w, heat_window)
    if (heat && !"gdd" %in% which) next
    if (!heat && !any(c("ch", "cu", "cp") %in% which)) next
    sel <- thermify::season_days(st$dates, w[1], w[2])
    lab <- attr(sel, "season")
    for (s in unique(lab)) {
      days <- sel[lab == s]
      if (length(days) != thermify:::window_length(s, w) ||
          !all(st$valid[days])) next
      h <- flat(days)
      vals <- if (heat) {
        c(gdd = sum(thermify::degree_hours(h, base = 10)) / 24)
      } else {
        c(ch = sum(thermify::chill_hours_hourly(h, 0, 7.2, output = "hourly")),
          cu = as.vector(thermify::chill_units(h, output = "total")),
          cp = as.vector(thermify::chill_portions(h, output = "total")))
      }
      vals <- vals[names(vals) %in% which]
      out[[length(out) + 1L]] <- data.frame(season = s, index = names(vals),
                                            value = unname(vals))
    }
  }
  do.call(rbind, out)
}

# Delta method on an hourly record: within each day the shift goes from the
# monthly change of the minimum (at the daily minimum) to the change of the
# maximum (at the daily maximum).
shift_hourly <- function(h, d_min, d_max) {
  day <- format(h$time, "%Y-%m-%d")
  t <- h$prom
  lo <- stats::ave(t, day, FUN = function(v) suppressWarnings(min(v, na.rm = TRUE)))
  hi <- stats::ave(t, day, FUN = function(v) suppressWarnings(max(v, na.rm = TRUE)))
  f <- ifelse(is.finite(hi - lo) & hi > lo, (t - lo) / (hi - lo), 0.5)
  f <- pmin(pmax(f, 0), 1)
  m <- as.integer(format(h$time, "%m"))
  t + d_min[m] + f * (d_max[m] - d_min[m])
}
