# Projected change of agroclimatic thermal indices under CMIP6 (WorldClim 2.1)
#
# Province of Cauquenes (Maule): maps of the change of each index
#         between the WorldClim 1970-2000 baseline and 2041-2060, for 14
#         global climate models (GCMs) and two scenarios (SSP2-4.5,
#         SSP5-8.5). Changes are reported, not future absolute values,
#         because WorldClim baseline errors partly cancel in the difference.
# Part B (CEAZA-Met stations) is in 02-ceaza-stations.R.
#
# Indices: degree-days base 10 degC (average method), chilling hours
# 0-7.2 degC, Utah units and chill portions, all with the Linvill hourly
# reconstruction (ch_methods = "hourly"), as recommended by the CEAZA-Met
# validation. Seasons: heat 1 Sep - 30 Apr, chill 1 May - 31 Aug.
#
#   Rscript data-raw/climate-change/01-cauquenes.R
#
# Data: WorldClim 2.1 (Fick & Hijmans 2017) and its CMIP6 downscaled
# projections.

library(thermify)
wc_dir <- Sys.getenv("THERMIFY_DATA", file.path(tempdir(), "worldclim"))
out_dir <- "vignettes/articles/data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

gcms <- c("ACCESS-CM2", "BCC-CSM2-MR", "CanESM5", "CMCC-ESM2",
          "CNRM-CM6-1-HR", "EC-Earth3-Veg", "GISS-E2-1-G", "HadGEM3-GC31-LL",
          "INM-CM5-0", "IPSL-CM6A-LR", "MIROC6", "MPI-ESM1-2-HR",
          "MRI-ESM2-0", "UKESM1-0-LL")
ssps <- c("245", "585")
period <- "2041-2060"
indices <- c("gdd", "ch", "cu", "cp")
keys <- c(gdd = "gdd_average_b10", ch = "ch_hourly", cu = "cu_utah",
          cp = "cp_dynamic")

season_maps <- function(tmin, tmax) {
  res <- thermify_rast(tmin, tmax, output_dir = tempfile("cc"),
                       temporal = "native", indices = indices,
                       gdd_methods = "average", base = 10,
                       ch_methods = "hourly", hourly_method = "linvill",
                       temporal_aggregation = "season", progress = FALSE)
  terra::rast(lapply(keys, function(k) res[[k]]$season))
}

# Part A: province of Cauquenes ----------------------------------------------
prov <- cauquenes_boundary("provincia", crs = "EPSG:4326")
message("Part A: baseline")
base_tmin <- worldclim_region("tmin", prov, path = wc_dir, mask = TRUE)
base_tmax <- worldclim_region("tmax", prov, path = wc_dir, mask = TRUE)
baseline <- season_maps(base_tmin, base_tmax)
names(baseline) <- names(keys)

province_rows <- list(data.frame(ssp = "baseline", gcm = "WorldClim 1970-2000",
  index = names(keys),
  value = unlist(terra::global(baseline, "mean", na.rm = TRUE))))
deltas <- list()
for (s in ssps) for (g in gcms) {
  message("Part A: SSP", s, " ", g)
  ft <- worldclim_future_region("tmin", prov, gcm = g, ssp = s,
                                period = period, path = wc_dir, mask = TRUE)
  fx <- worldclim_future_region("tmax", prov, gcm = g, ssp = s,
                                period = period, path = wc_dir, mask = TRUE)
  fut <- season_maps(ft, fx)
  names(fut) <- names(keys)
  deltas[[paste(s, g)]] <- fut - baseline
  province_rows[[length(province_rows) + 1L]] <- data.frame(
    ssp = s, gcm = g, index = names(keys),
    value = unlist(terra::global(fut, "mean", na.rm = TRUE)))
}
province <- do.call(rbind, province_rows)
rownames(province) <- NULL

# Median change across GCMs and model agreement (share of GCMs whose change
# has the sign of the median), per index and scenario.
for (s in ssps) for (ix in names(keys)) {
  stack <- terra::rast(lapply(gcms, function(g) deltas[[paste(s, g)]][[ix]]))
  med <- terra::app(stack, stats::median)
  agree <- terra::app(stack, function(v) {
    m <- stats::median(v)
    if (is.na(m)) NA_real_ else mean(sign(v) == sign(m))
  })
  out <- c(med, agree)
  names(out) <- c("median_change", "agreement")
  terra::writeRaster(out, file.path(out_dir,
    sprintf("cc-cauquenes-%s-ssp%s.tif", ix, s)), overwrite = TRUE,
    gdal = c("COMPRESS=DEFLATE"), datatype = "FLT4S")
}
province$value <- round(province$value, 2)
utils::write.csv(province, file.path(out_dir, "cc-cauquenes-province.csv"),
                 row.names = FALSE)

writeLines(c(paste("thermify", as.character(utils::packageVersion("thermify"))),
             paste("GCMs:", paste(gcms, collapse = ", ")),
             paste("scenarios: SSP", paste(ssps, collapse = ", SSP"),
                   "; period:", period),
             paste("created:", format(Sys.time(), tz = "UTC"))),
           file.path(out_dir, "cc-provenance.txt"))
message("Done")
