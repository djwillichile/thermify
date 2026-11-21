# Degree-days and chill portions through time: observed or historical series
# and CMIP6 projections for four scenarios and four 20-year periods.
#
# Panel data for the article "Projected change of thermal indices":
#
#  * Province of Cauquenes. Historical series 1951-2023 from the WorldClim
#    2.1 historical monthly weather data (CRU-TS 4.09 downscaled with
#    WorldClim 2.1, 2.5 arc-minutes), and the CMIP6 projections of WorldClim
#    2.1 (30 arc-seconds) for SSP1-2.6, SSP2-4.5, SSP3-7.0 and SSP5-8.5 and
#    the periods 2021-2040, 2041-2060, 2061-2080 and 2081-2100. All values
#    are computed with the same method, from the province-mean monthly
#    temperatures (densified to daily values and reconstructed hourly with
#    the Linvill model), so the historical and projected values are
#    comparable with each other; as monthly-based estimates, their absolute
#    values carry the biases measured in the CEAZA-Met validation.
#
#  * Vicuna (CEAZA-Met station 6, Elqui valley, 634 m). Observed seasons
#    from the station's hourly record, the historical series 1951-2023 at
#    the station's WorldClim cell (same monthly method as for the province),
#    and projections with the delta
#    method on that record (see 02-ceaza-stations.R) for the same scenarios
#    and periods. Each model's change is taken from the record period
#    (about 2015) to the target period, not from 1970-2000, so that the
#    warming already contained in the record is not counted twice.
#
# Each season is labelled by the year in which it starts (heat season
# 1 Sep - 30 Apr, chill season 1 May - 31 Aug).
#
#   Rscript data-raw/climate-change/03-timeseries.R
#
# Needs the hourly cache of data-raw/validation-ceaza/02-download.R.
# Data: WorldClim 2.1 (Fick & Hijmans 2017), its historical monthly weather
# data (Harris et al. 2020, CRU-TS) and its CMIP6 projections; Centro de
# Estudios Avanzados en Zonas Aridas (CEAZA), www.ceazamet.cl.

library(thermify)
source("data-raw/climate-change/helpers.R")
wc_dir <- Sys.getenv("THERMIFY_DATA", file.path(tempdir(), "worldclim"))
cache <- Sys.getenv("THERMIFY_CEAZA_CACHE",
                    file.path(tools::R_user_dir("thermify", "cache"), "ceaza"))
work <- Sys.getenv("THERMIFY_WORK", file.path(tempdir(), "cc-timeseries"))
dir.create(work, recursive = TRUE, showWarnings = FALSE)
out_dir <- "vignettes/articles/data"
cores <- as.integer(Sys.getenv("THERMIFY_CORES", "4"))

gcms <- c("ACCESS-CM2", "BCC-CSM2-MR", "CanESM5", "CMCC-ESM2",
          "CNRM-CM6-1-HR", "EC-Earth3-Veg", "GISS-E2-1-G", "HadGEM3-GC31-LL",
          "INM-CM5-0", "IPSL-CM6A-LR", "MIROC6", "MPI-ESM1-2-HR",
          "MRI-ESM2-0", "UKESM1-0-LL")
ssps <- c("126", "245", "370", "585")
periods <- c("2021-2040", "2041-2060", "2061-2080", "2081-2100")
hist_years <- 1951:2023

# Season indices from 12 monthly values (January to December).
monthly_indices <- function(tmin, tmax, latitude) {
  r <- thermify(tmin, tmax, input = "monthly", latitude = latitude,
                temporal = "native", indices = c("gdd", "cp"),
                gdd_methods = "average", base = 10, ch_methods = "hourly",
                hourly_method = "linvill")
  s <- r$summary[r$summary$aggregation == "season", ]
  stats::setNames(s$value, s$index)[c("gdd", "cp")]
}

# Province of Cauquenes ------------------------------------------------------
prov <- cauquenes_boundary("provincia", crs = "EPSG:4326")
lat_prov <- terra::geom(terra::centroids(prov))[1, "y"]
layer_means <- function(r) {
  as.vector(unlist(terra::global(r, "mean", na.rm = TRUE)))
}

# Historical monthly weather (hist_url() in helpers.R), read for the
# province only.
hist_csv <- file.path(work, "hist-province-monthly.csv")
if (!file.exists(hist_csv)) {
  grid <- expand.grid(month = 1:12, year = (min(hist_years)):(max(hist_years) + 1),
                      var = c("tmin", "tmax"), stringsAsFactors = FALSE)
  message("Historical: ", nrow(grid), " monthly files")
  vals <- parallel::mclapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, ]
    for (attempt in 1:3) {
      v <- tryCatch({
        r <- terra::crop(terra::rast(hist_url(g$var, g$year, g$month)), prov,
                         mask = TRUE, touches = TRUE)
        layer_means(r)
      }, error = function(e) NA_real_)
      if (!is.na(v)) return(v)
      Sys.sleep(5 * attempt)
    }
    NA_real_
  }, mc.cores = cores)
  grid$value <- unlist(vals)
  if (anyNA(grid$value)) stop("Some historical files could not be read.")
  utils::write.csv(grid, hist_csv, row.names = FALSE)
}
hist <- utils::read.csv(hist_csv)
monthly_of <- function(var, y, h = hist) {
  # Season year y: May-December of y and January-April of y + 1.
  v <- h[h$var == var, ]
  c(v$value[v$year == y + 1 & v$month %in% 1:4],
    v$value[v$year == y & v$month %in% 5:12])
}
rows <- list()
for (y in hist_years) {
  ix <- monthly_indices(monthly_of("tmin", y), monthly_of("tmax", y), lat_prov)
  rows[[length(rows) + 1L]] <- data.frame(
    source = "historical", ssp = NA, gcm = NA, period = NA, year = y,
    index = names(ix), value = unname(ix))
}
message("Province baseline and projections")
base_tmin <- layer_means(worldclim_region("tmin", prov, path = wc_dir))
base_tmax <- layer_means(worldclim_region("tmax", prov, path = wc_dir))
ix <- monthly_indices(base_tmin, base_tmax, lat_prov)
rows[[length(rows) + 1L]] <- data.frame(
  source = "baseline", ssp = NA, gcm = NA, period = "1970-2000", year = NA,
  index = names(ix), value = unname(ix))
combos <- expand.grid(gcm = gcms, ssp = ssps, period = periods,
                      stringsAsFactors = FALSE)
# NULL when WorldClim has no projection for the combination; other errors
# (network) are retried.
read_future <- function(var, region, g, s, p, mask = TRUE) {
  for (attempt in 1:4) {
    r <- tryCatch(worldclim_future_region(var, region, gcm = g, ssp = s,
                                          period = p, path = wc_dir,
                                          mask = mask),
                  error = function(e) e)
    if (!inherits(r, "error")) return(r)
    if (grepl("has no", conditionMessage(r))) return(NULL)
    Sys.sleep(5 * attempt)
  }
  stop("Could not read ", var, " ", g, " SSP", s, " ", p, ": ",
       conditionMessage(r))
}
for (k in seq_len(nrow(combos))) {
  g <- combos$gcm[k]; s <- combos$ssp[k]; p <- combos$period[k]
  ft <- read_future("tmin", prov, g, s, p)
  fx <- read_future("tmax", prov, g, s, p)
  if (is.null(ft) || is.null(fx)) {
    message("  not available: ", g, " SSP", s, " ", p)
    next
  }
  ix <- monthly_indices(layer_means(ft), layer_means(fx), lat_prov)
  rows[[length(rows) + 1L]] <- data.frame(
    source = "projection", ssp = s, gcm = g, period = p, year = NA,
    index = names(ix), value = unname(ix))
}
province <- do.call(rbind, rows)
province$value <- round(province$value, 2)
utils::write.csv(province, file.path(out_dir, "cc-timeseries-cauquenes.csv"),
                 row.names = FALSE)

# Vicuna (CEAZA-Met) ---------------------------------------------------------
stations <- utils::read.csv("data-raw/validation-ceaza/results/ceaza-stations.csv",
                            encoding = "UTF-8")
st <- stations[stations$station == "6", ]
pt <- terra::vect(st, geom = c("lon", "lat"), crs = "EPSG:4326")
region <- terra::ext(terra::buffer(pt, 2000))
cell <- function(r) as.vector(as.matrix(terra::extract(r, pt, ID = FALSE)))
now_tmin <- cell(worldclim_region("tmin", region, wc_dir, mask = FALSE))
now_tmax <- cell(worldclim_region("tmax", region, wc_dir, mask = FALSE))
h <- readRDS(file.path(cache, "6.rds"))
obs <- season_indices(h$time, h$prom, which = c("gdd", "cp"))
# Changes are applied relative to the record period (change_from_record()).
record_mid <- mean(as.integer(format(h$time, "%Y")))
rows <- list(data.frame(source = "observed", ssp = NA, gcm = NA, period = NA,
                        year = as.integer(obs$season), index = obs$index,
                        value = obs$value))
# Historical monthly weather at the station's cell, same monthly method as
# for the province.
hist_st <- hist_points_monthly(pt, (min(hist_years)):(max(hist_years) + 1),
                               file.path(work, "hist-vicuna-1951-2024.csv"),
                               cores = cores)
for (y in hist_years) {
  ix <- monthly_indices(monthly_of("tmin", y, hist_st),
                        monthly_of("tmax", y, hist_st), st$lat)
  rows[[length(rows) + 1L]] <- data.frame(
    source = "historical", ssp = NA, gcm = NA, period = NA, year = y,
    index = names(ix), value = unname(ix))
}
# Fill the raster cache serially, so that the parallel workers below only
# read it and never write the same cache file at the same time.
for (k in seq_len(nrow(combos))) {
  for (p in unique(c(combos$period[k], "2021-2040"))) {
    for (v in c("tmin", "tmax")) {
      read_future(v, region, combos$gcm[k], combos$ssp[k], p, mask = FALSE)
    }
  }
}
message("Vicuna: ", nrow(combos), " projections")
proj <- parallel::mclapply(seq_len(nrow(combos)), function(k) {
  g <- combos$gcm[k]; s <- combos$ssp[k]; p <- combos$period[k]
  ft <- read_future("tmin", region, g, s, p, mask = FALSE)
  fx <- read_future("tmax", region, g, s, p, mask = FALSE)
  t30 <- read_future("tmin", region, g, s, "2021-2040", mask = FALSE)
  x30 <- read_future("tmax", region, g, s, "2021-2040", mask = FALSE)
  if (is.null(ft) || is.null(fx) || is.null(t30) || is.null(x30)) return(NULL)
  d_min <- change_from_record(cell(ft) - now_tmin, cell(t30) - now_tmin,
                              record_mid)
  d_max <- change_from_record(cell(fx) - now_tmax, cell(x30) - now_tmax,
                              record_mid)
  fut <- season_indices(h$time, shift_hourly(h, d_min, d_max),
                        which = c("gdd", "cp"))
  m <- tapply(fut$value, fut$index, mean)
  data.frame(source = "projection", ssp = s, gcm = g, period = p, year = NA,
             index = names(m), value = as.vector(m))
}, mc.cores = cores)
vicuna <- do.call(rbind, c(rows, proj))
vicuna$value <- round(vicuna$value, 2)
utils::write.csv(vicuna, file.path(out_dir, "cc-timeseries-vicuna.csv"),
                 row.names = FALSE)
message("Done")
