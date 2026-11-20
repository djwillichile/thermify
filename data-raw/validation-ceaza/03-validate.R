# Step 3: validate thermify against observed hourly temperature at the
# selected CEAZA-Met stations (protocol of vignette("validation")).
#
# Reference: indices computed directly from the observed hourly series.
# Estimates: (daily) the station's daily extremes with each daily method and
# the hourly reconstructions; (monthly) the station's monthly climatology
# densified with pchip_mp; (gridded) the WorldClim 2.1 30" cell containing
# the station.
#
#   Rscript data-raw/validation-ceaza/03-validate.R
#
# Reads the cache written by 02-download.R and writes derived results only
# (seasonal totals and metrics) to data-raw/validation-ceaza/results/.
# Data: Centro de Estudios Avanzados en Zonas Aridas (CEAZA), www.ceazamet.cl;
# WorldClim 2.1 (Fick & Hijmans 2017).

library(thermify)
cache <- Sys.getenv("THERMIFY_CEAZA_CACHE",
                    file.path(tools::R_user_dir("thermify", "cache"), "ceaza"))
wc_dir <- Sys.getenv("THERMIFY_DATA", file.path(tempdir(), "worldclim"))
out_dir <- "data-raw/validation-ceaza/results"

stations <- utils::read.csv(file.path(out_dir, "ceaza-stations.csv"),
                            encoding = "UTF-8")
stations <- stations[stations$selected, ]
stations <- stations[file.exists(file.path(cache,
                                           paste0(stations$station, ".rds"))), ]
message(nrow(stations), " stations with cached data")

# WorldClim 2.1 30" monthly normals at the stations.
pts <- terra::vect(stations, geom = c("lon", "lat"), crs = "EPSG:4326")
region <- terra::buffer(pts, 2000)
wc_tmin <- worldclim_region("tmin", region, path = wc_dir, mask = FALSE)
wc_tmax <- worldclim_region("tmax", region, path = wc_dir, mask = FALSE)
cell_tmin <- terra::extract(wc_tmin, pts, ID = FALSE)
cell_tmax <- terra::extract(wc_tmax, pts, ID = FALSE)

gdd_methods <- c("average", "modified_average", "single_sine",
                 "single_triangle", "double_sine", "double_triangle")
results <- list()
for (i in seq_len(nrow(stations))) {
  st <- stations[i, ]
  h <- readRDS(file.path(cache, paste0(st$station, ".rds")))
  sh <- prepare_station_hourly(h$time, h$prom, max_gap = 2)
  gridded <- list(tmin = unlist(cell_tmin[i, ]), tmax = unlist(cell_tmax[i, ]))
  if (anyNA(gridded$tmin) || anyNA(gridded$tmax)) gridded <- NULL
  v <- validate_station(sh, latitude = st$lat, base = 10,
                        gdd_methods = gdd_methods, gridded = gridded,
                        temporal = "native")
  message(sprintf("[%d/%d] %s: %d season rows, %d excluded", i,
                  nrow(stations), st$name, nrow(v$seasons), nrow(v$excluded)))
  results[[st$station]] <- v
}

seasons <- do.call(rbind, lapply(names(results), function(k) {
  s <- results[[k]]$seasons
  if (!nrow(s)) return(NULL)
  cbind(station = k, s)
}))
excluded <- do.call(rbind, lapply(names(results), function(k) {
  e <- results[[k]]$excluded
  if (!nrow(e)) return(NULL)
  cbind(station = k, e)
}))

# Pooled metrics across stations, per index, level and method.
groups <- unique(seasons[, c("index", "level", "method")])
pooled <- do.call(rbind, lapply(seq_len(nrow(groups)), function(j) {
  g <- groups[j, ]
  d <- seasons[seasons$index == g$index & seasons$level == g$level &
                 seasons$method == g$method, ]
  cbind(g, stations = length(unique(d$station)),
        validation_metrics(d$estimate, d$observed), row.names = NULL)
}))

# Ensemble weights for daily GDD from these stations (leave one station out).
ens <- lapply(c("stacking", "bma", "akaike"), function(sc) {
  w <- gdd_ensemble_weights(results, level = "daily", scheme = sc,
                            methods = c("average", "single_sine",
                                        "single_triangle", "double_sine",
                                        "double_triangle"))
  data.frame(scheme = sc, method = names(w$weights),
             weight = unname(w$weights),
             cv_rmse = w$cv$rmse, cv_bias = w$cv$bias)
})
ens <- do.call(rbind, ens)

num <- function(d) { k <- vapply(d, is.numeric, TRUE); d[k] <- lapply(d[k], round, 3); d }
utils::write.csv(num(seasons), file.path(out_dir, "ceaza-seasons.csv"),
                 row.names = FALSE)
utils::write.csv(num(pooled), file.path(out_dir, "ceaza-metrics.csv"),
                 row.names = FALSE)
utils::write.csv(excluded, file.path(out_dir, "ceaza-excluded.csv"),
                 row.names = FALSE)
utils::write.csv(num(ens), file.path(out_dir, "ceaza-ensemble-weights.csv"),
                 row.names = FALSE)
writeLines(c(paste("thermify", as.character(utils::packageVersion("thermify"))),
             paste("stations:", length(results)),
             paste("created:", format(Sys.time(), tz = "UTC"))),
           file.path(out_dir, "ceaza-provenance.txt"))
message("Done")
