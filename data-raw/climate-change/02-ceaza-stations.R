# Projected change of agroclimatic thermal indices at the CEAZA-Met stations:
# delta method on the observed hourly series.
#
# For each global climate model (GCM) and scenario, the monthly change of
# minimum and maximum temperature at the station's WorldClim cell (CMIP6
# 2041-2060 minus 1970-2000) is applied to every hour of the station's
# observed record. Within each day the shift is interpolated between the
# change of the minimum (at the daily minimum) and the change of the maximum
# (at the daily maximum):
#
#   T' = T + dTmin(m) + f * (dTmax(m) - dTmin(m)),
#   f  = (T - Tmin_day) / (Tmax_day - Tmin_day), in [0, 1].
#
# The indices are then computed directly from the modified hourly series,
# season by season, exactly as the reference of the validation. This keeps
# the observed day-to-day and year-to-year variability, which monthly
# climatologies lose (they underestimate chill strongly at these sites), and
# the present-day baseline equals the observed indices.
#
#   Rscript data-raw/climate-change/02-ceaza-stations.R
#
# Needs the hourly cache of data-raw/validation-ceaza/02-download.R.
# Data: Centro de Estudios Avanzados en Zonas Aridas (CEAZA),
# www.ceazamet.cl; WorldClim 2.1 and its CMIP6 projections.

library(thermify)
wc_dir <- Sys.getenv("THERMIFY_DATA", file.path(tempdir(), "worldclim"))
cache <- Sys.getenv("THERMIFY_CEAZA_CACHE",
                    file.path(tools::R_user_dir("thermify", "cache"), "ceaza"))
out_dir <- "vignettes/articles/data"

gcms <- c("ACCESS-CM2", "BCC-CSM2-MR", "CanESM5", "CMCC-ESM2",
          "CNRM-CM6-1-HR", "EC-Earth3-Veg", "GISS-E2-1-G", "HadGEM3-GC31-LL",
          "INM-CM5-0", "IPSL-CM6A-LR", "MIROC6", "MPI-ESM1-2-HR",
          "MRI-ESM2-0", "UKESM1-0-LL")
ssps <- c("245", "585")
period <- "2041-2060"
heat <- c("09-01", "04-30")
chill <- c("05-01", "08-31")

stations <- utils::read.csv("data-raw/validation-ceaza/results/ceaza-stations.csv",
                            encoding = "UTF-8")
stations <- stations[stations$selected, ]
stations <- stations[file.exists(file.path(cache,
                                           paste0(stations$station, ".rds"))), ]
pts <- terra::vect(stations, geom = c("lon", "lat"), crs = "EPSG:4326")
region <- terra::ext(terra::buffer(pts, 2000))
cell <- function(r) as.matrix(terra::extract(r, pts, ID = FALSE))
wc_now <- list(tmin = cell(worldclim_region("tmin", region, wc_dir,
                                            mask = FALSE)),
               tmax = cell(worldclim_region("tmax", region, wc_dir,
                                            mask = FALSE)))

# Season totals of the four indices from an hourly record, for complete
# seasons only (every day valid after filling gaps of up to 2 hours).
season_indices <- function(time, temperature) {
  st <- prepare_station_hourly(time, temperature, max_gap = 2)
  flat <- function(days) as.vector(t(st$hourly[days, , drop = FALSE]))
  out <- list()
  for (w in list(heat = heat, chill = chill)) {
    sel <- season_days(st$dates, w[1], w[2])
    lab <- attr(sel, "season")
    for (s in unique(lab)) {
      days <- sel[lab == s]
      if (length(days) != thermify:::window_length(s, w) ||
          !all(st$valid[days])) next
      h <- flat(days)
      vals <- if (identical(w, heat)) {
        c(gdd = sum(degree_hours(h, base = 10)) / 24)
      } else {
        c(ch = sum(chill_hours_hourly(h, 0, 7.2, output = "hourly")),
          cu = as.vector(chill_units(h, output = "total")),
          cp = as.vector(chill_portions(h, output = "total")))
      }
      out[[length(out) + 1L]] <- data.frame(season = s, index = names(vals),
                                            value = unname(vals))
    }
  }
  do.call(rbind, out)
}

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

rows <- list()
for (i in seq_len(nrow(stations))) {
  code <- stations$station[i]
  message(sprintf("[%d/%d] %s", i, nrow(stations), stations$name[i]))
  if (anyNA(c(wc_now$tmin[i, ], wc_now$tmax[i, ]))) {
    # Shoreline stations can fall on a sea cell of WorldClim (no data).
    message("  skipped: no WorldClim data at the station's cell")
    next
  }
  h <- readRDS(file.path(cache, paste0(code, ".rds")))
  base <- season_indices(h$time, h$prom)
  if (is.null(base)) next
  base_mean <- tapply(base$value, base$index, mean)
  n_seasons <- tapply(base$value, base$index, length)
  for (s in ssps) for (g in gcms) {
    fut_tmin <- cell(worldclim_future_region("tmin", region, gcm = g,
                                             ssp = s, period = period,
                                             path = wc_dir, mask = FALSE))
    fut_tmax <- cell(worldclim_future_region("tmax", region, gcm = g,
                                             ssp = s, period = period,
                                             path = wc_dir, mask = FALSE))
    d_min <- fut_tmin[i, ] - wc_now$tmin[i, ]
    d_max <- fut_tmax[i, ] - wc_now$tmax[i, ]
    if (anyNA(c(d_min, d_max))) next
    fut <- season_indices(h$time, shift_hourly(h, d_min, d_max))
    fut_mean <- tapply(fut$value, fut$index, mean)
    ix <- names(base_mean)
    rows[[length(rows) + 1L]] <- data.frame(
      station = code, ssp = s, gcm = g, index = ix,
      seasons = as.vector(n_seasons[ix]),
      baseline = as.vector(base_mean[ix]),
      future = as.vector(fut_mean[ix]),
      change = as.vector(fut_mean[ix] - base_mean[ix]),
      delta_tmin = mean(d_min), delta_tmax = mean(d_max))
  }
}
res <- do.call(rbind, rows)
num <- vapply(res, is.numeric, TRUE)
res[num] <- lapply(res[num], round, 3)
utils::write.csv(res, file.path(out_dir, "cc-ceaza-stations.csv"),
                 row.names = FALSE)
message("Done")
