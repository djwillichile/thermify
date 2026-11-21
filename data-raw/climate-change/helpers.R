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

# WorldClim 2.1 historical monthly weather (CRU-TS 4.09, 2.5 arc-minutes),
# read remotely for the cells of `pts` (a SpatVector of points). Returns a
# data frame with point, var, year, month and value; cached in `file`.
hist_url <- function(var, year, month) {
  dec <- if (year >= 2020) "2020-2024" else
    sprintf("%d-%d", year %/% 10 * 10, year %/% 10 * 10 + 9)
  sprintf(paste0("/vsizip//vsicurl/https://geodata.ucdavis.edu/climate/",
                 "worldclim/2_1/hist/cts4.09/wc2.1_cruts4.09_2.5m_%s_%s.zip/",
                 "wc2.1_cruts4.09_2.5m_%s_%d-%02d.tif"),
          var, dec, var, year, month)
}
hist_points_monthly <- function(pts, years, file, cores = 4) {
  if (file.exists(file)) return(utils::read.csv(file))
  box <- terra::ext(terra::buffer(pts, 10000))
  grid <- expand.grid(month = 1:12, year = years, var = c("tmin", "tmax"),
                      stringsAsFactors = FALSE)
  vals <- parallel::mclapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, ]
    for (attempt in 1:3) {
      v <- tryCatch({
        r <- terra::crop(terra::rast(hist_url(g$var, g$year, g$month)), box)
        as.vector(as.matrix(terra::extract(r, pts, ID = FALSE)))
      }, error = function(e) NULL)
      if (!is.null(v)) return(v)
      Sys.sleep(5 * attempt)
    }
    stop("Could not read ", hist_url(g$var, g$year, g$month))
  }, mc.cores = cores)
  out <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    data.frame(point = seq_along(vals[[i]]), var = grid$var[i],
               year = grid$year[i], month = grid$month[i], value = vals[[i]])
  }))
  utils::write.csv(out, file, row.names = FALSE)
  out
}

# Monthly warming already present in a station record: mean of the record
# years minus the 1970-2000 mean, from the historical series of one point.
# The CMIP6 changes of WorldClim are relative to 1970-2000, so this part is
# subtracted before they are applied to a recent record.
recent_warming <- function(hist, var, record_years) {
  h <- hist[hist$var == var, ]
  rec <- tapply(h$value[h$year %in% record_years],
                h$month[h$year %in% record_years], mean)
  ref <- tapply(h$value[h$year %in% 1970:2000],
                h$month[h$year %in% 1970:2000], mean)
  as.vector(rec - ref)
}
