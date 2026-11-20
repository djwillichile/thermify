# Step 2: download the hourly air temperature of the selected stations into a
# local cache (never into the repository). One request per station-year,
# spaced to avoid loading the CEAZA-Met server.
#
#   CEAZA_USER=name@institution Rscript data-raw/validation-ceaza/02-download.R
#
# The cache directory defaults to tools::R_user_dir("thermify", "cache");
# set THERMIFY_CEAZA_CACHE to change it. Stations already cached are skipped.
#
# Data: Centro de Estudios Avanzados en Zonas Aridas (CEAZA), www.ceazamet.cl

source("data-raw/validation-ceaza/ceaza-api.R")
if (!nzchar(Sys.getenv("CEAZA_USER"))) {
  stop("Set CEAZA_USER (the CEAZA web-service user) before running.")
}
cache <- Sys.getenv("THERMIFY_CEAZA_CACHE",
                    file.path(tools::R_user_dir("thermify", "cache"), "ceaza"))
dir.create(cache, recursive = TRUE, showWarnings = FALSE)

stations <- utils::read.csv("data-raw/validation-ceaza/results/ceaza-stations.csv",
                            encoding = "UTF-8")
stations <- stations[stations$selected, ]

for (i in seq_len(nrow(stations))) {
  st <- stations[i, ]
  file <- file.path(cache, paste0(st$station, ".rds"))
  if (file.exists(file)) next
  message(sprintf("[%d/%d] %s (%s) %d-%d", i, nrow(stations), st$name,
                  st$sensor, st$first_year, st$last_year + 1))
  h <- ceaza_hourly(st$sensor, st$first_year, st$last_year + 1, pause = 1)
  h <- h[, c("time", "min", "prom", "max", "data_pc")]
  saveRDS(h, file)
}
message("Cache: ", cache)
