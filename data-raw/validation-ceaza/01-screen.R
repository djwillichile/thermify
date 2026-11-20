# Step 1: find the air temperature sensor of every CEAZA-Met station and
# count the seasons with an almost complete record, from monthly
# completeness. Only station metadata and counts are written to the
# repository; no temperature values.
#
# Run from the package root with the CEAZA web-service user set:
#   CEAZA_USER=name@institution Rscript data-raw/validation-ceaza/01-screen.R
#
# Data: Centro de Estudios Avanzados en Zonas Aridas (CEAZA), www.ceazamet.cl

source("data-raw/validation-ceaza/ceaza-api.R")
out_dir <- "data-raw/validation-ceaza/results"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!nzchar(Sys.getenv("CEAZA_USER"))) {
  stop("Set CEAZA_USER (the CEAZA web-service user) before running.")
}

first_year <- 2000
last_year <- 2025
min_completeness <- 98   # percent of hours in a month
min_seasons <- 5

stations <- ceaza_stations()
message(nrow(stations), " stations")

# Air temperature sensor closest to 2 m above ground.
sensor_of <- function(code) {
  s <- ceaza_sensors(code)
  s <- s[s$tf_nombre == "Temperatura del Aire", ]
  if (!nrow(s)) return(NA_character_)
  s <- s[order(abs(as.numeric(s$s_altura) - 2)), ]
  as.character(s$s_cod[1])
}
stations$sensor <- vapply(stations$e_cod, sensor_of, "")
stations <- stations[!is.na(stations$sensor), ]
message(nrow(stations), " stations with an air temperature sensor")

# A season counts when every month of the window reaches min_completeness.
# Heat season: September of year y to April of y + 1. Chill season: May to
# August of year y.
count_seasons <- function(m) {
  ok <- m$data_pc >= min_completeness
  key <- function(y, mo) paste(y, mo)
  good <- setNames(ok, key(m$year, m$month))
  has <- function(y, mo) isTRUE(good[key(y, mo)])
  years <- first_year:(last_year - 1)
  heat <- vapply(years, function(y) {
    all(c(vapply(9:12, function(mo) has(y, mo), TRUE),
          vapply(1:4, function(mo) has(y + 1, mo), TRUE)))
  }, TRUE)
  chill <- vapply(years, function(y) {
    all(vapply(5:8, function(mo) has(y, mo), TRUE))
  }, TRUE)
  c(heat = sum(heat), chill = sum(chill),
    first = if (any(heat | chill)) min(years[heat | chill]) else NA,
    last = if (any(heat | chill)) max(years[heat | chill]) else NA)
}

screen <- lapply(seq_len(nrow(stations)), function(i) {
  m <- ceaza_series(stations$sensor[i], sprintf("%d-01-01", first_year),
                    sprintf("%d-12-31", last_year), interval = "mes")
  m$year <- as.integer(substr(m$ultima_lectura, 1, 4))
  m$month <- as.integer(substr(m$ultima_lectura, 6, 7))
  m$data_pc[is.na(m$data_pc)] <- 0
  count_seasons(m)
})
screen <- do.call(rbind, screen)

result <- data.frame(
  station = stations$e_cod, name = stations$e_nombre,
  lat = stations$e_lat, lon = stations$e_lon, elevation = stations$e_altitud,
  sensor = stations$sensor, heat_seasons = screen[, "heat"],
  chill_seasons = screen[, "chill"], first_year = screen[, "first"],
  last_year = screen[, "last"])
result$selected <- result$heat_seasons >= min_seasons &
  result$chill_seasons >= min_seasons
result <- result[order(-result$selected, -result$heat_seasons), ]
utils::write.csv(result, file.path(out_dir, "ceaza-stations.csv"),
                 row.names = FALSE, fileEncoding = "UTF-8")
message(sum(result$selected), " stations with at least ", min_seasons,
        " complete heat and chill seasons")
