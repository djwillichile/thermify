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
# The CMIP6 changes are relative to 1970-2000, while the records cover about
# 2004-2025 and already contain part of that warming. Each model's change is
# therefore taken from the record period to 2041-2060: its change at the
# record's midpoint is interpolated between 1985 and its 2021-2040 change and
# subtracted (change_from_record() in helpers.R), so that the warming already
# in the record is not counted twice.
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
cores <- as.integer(Sys.getenv("THERMIFY_CORES", "4"))

gcms <- c("ACCESS-CM2", "BCC-CSM2-MR", "CanESM5", "CMCC-ESM2",
          "CNRM-CM6-1-HR", "EC-Earth3-Veg", "GISS-E2-1-G", "HadGEM3-GC31-LL",
          "INM-CM5-0", "IPSL-CM6A-LR", "MIROC6", "MPI-ESM1-2-HR",
          "MRI-ESM2-0", "UKESM1-0-LL")
ssps <- c("245", "585")
period <- "2041-2060"

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

source("data-raw/climate-change/helpers.R")

# Fill the raster cache serially: the parallel workers below then only read
# it, and never write the same cache file at the same time.
for (s in ssps) for (g in gcms) for (p in unique(c(period, "2021-2040"))) {
  for (v in c("tmin", "tmax")) {
    worldclim_future_region(v, region, gcm = g, ssp = s, period = p,
                            path = wc_dir, mask = FALSE)
  }
}

run_station <- function(i) {
  code <- stations$station[i]
  rows <- list()
  if (anyNA(c(wc_now$tmin[i, ], wc_now$tmax[i, ]))) {
    # Shoreline stations can fall on a sea cell of WorldClim (no data).
    message(stations$name[i], ": no WorldClim data at the station's cell")
    return(NULL)
  }
  h <- readRDS(file.path(cache, paste0(code, ".rds")))
  base <- season_indices(h$time, h$prom)
  if (is.null(base)) return(NULL)
  base_mean <- tapply(base$value, base$index, mean)
  n_seasons <- tapply(base$value, base$index, length)
  record_mid <- mean(as.integer(format(h$time, "%Y")))
  for (s in ssps) for (g in gcms) {
    fut_tmin <- cell(worldclim_future_region("tmin", region, gcm = g,
                                             ssp = s, period = period,
                                             path = wc_dir, mask = FALSE))
    fut_tmax <- cell(worldclim_future_region("tmax", region, gcm = g,
                                             ssp = s, period = period,
                                             path = wc_dir, mask = FALSE))
    t30 <- cell(worldclim_future_region("tmin", region, gcm = g, ssp = s,
                                        period = "2021-2040", path = wc_dir,
                                        mask = FALSE))
    x30 <- cell(worldclim_future_region("tmax", region, gcm = g, ssp = s,
                                        period = "2021-2040", path = wc_dir,
                                        mask = FALSE))
    d_min <- change_from_record(fut_tmin[i, ] - wc_now$tmin[i, ],
                                t30[i, ] - wc_now$tmin[i, ], record_mid)
    d_max <- change_from_record(fut_tmax[i, ] - wc_now$tmax[i, ],
                                x30[i, ] - wc_now$tmax[i, ], record_mid)
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
      delta_tmin = mean(d_min), delta_tmax = mean(d_max),
      record_mid = round(record_mid, 1))
  }
  message(stations$name[i], ": done")
  do.call(rbind, rows)
}
res <- do.call(rbind, parallel::mclapply(seq_len(nrow(stations)), run_station,
                                         mc.cores = cores))
num <- vapply(res, is.numeric, TRUE)
res[num] <- lapply(res[num], round, 3)
utils::write.csv(res, file.path(out_dir, "cc-ceaza-stations.csv"),
                 row.names = FALSE)
message("Done")
