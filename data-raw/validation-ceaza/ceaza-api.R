# Minimal client for the public CEAZA-Met web service
# (https://www.ceazamet.cl/ws/pop_ws.php). Data are provided by CEAZA through
# the CEAZA-Met system. Cite as: "Centro de Estudios Avanzados en Zonas
# Aridas (CEAZA), www.ceazamet.cl, [year]". Raw data are cached locally and
# are not redistributed with thermify.
#
# Anonymous requests return at most 24 rows. CEAZA grants research users a
# web-service user with larger limits; set it in the environment, never in
# the code:  Sys.setenv(CEAZA_USER = "name@institution")
#
# Times are local standard time (GMT-4, no daylight saving) and mark the
# start of each interval (confirmed by CEAZA, 2026-11-20).

ceaza_ws <- "https://www.ceazamet.cl/ws/pop_ws.php"

ceaza_get <- function(..., pause = 1) {
  args <- list(...)
  user <- Sys.getenv("CEAZA_USER")
  if (nzchar(user)) args$user <- user
  query <- paste(names(args), vapply(args, as.character, ""), sep = "=",
                 collapse = "&")
  url <- paste0(ceaza_ws, "?", query)
  lines <- NULL
  for (attempt in 1:4) {
    lines <- tryCatch(readLines(url, warn = FALSE, encoding = "UTF-8"),
                      error = function(e) NULL)
    if (!is.null(lines)) break
    Sys.sleep(5 * attempt)
  }
  Sys.sleep(pause)
  if (is.null(lines)) stop("CEAZA-Met did not answer: ", url, call. = FALSE)
  header <- grep("^#", lines, value = TRUE)
  cols <- strsplit(sub(",$", "", sub("^#", "", header[length(header)])),
                   ",")[[1]]
  body <- lines[!grepl("^#", lines) & nzchar(lines)]
  if (!length(body)) {
    return(as.data.frame(setNames(replicate(length(cols), character(),
                                            simplify = FALSE), cols)))
  }
  out <- utils::read.csv(text = body, header = FALSE, na.strings = "nan",
                         stringsAsFactors = FALSE, encoding = "UTF-8")
  out <- out[, seq_along(cols), drop = FALSE]
  names(out) <- cols
  out
}

ceaza_stations <- function() {
  ceaza_get(fn = "GetListaEstaciones", p_cod = "ceazamet")
}

ceaza_sensors <- function(station) {
  ceaza_get(fn = "GetListaSensores", p_cod = "ceazamet", e_cod = station)
}

# interval: "hora" (hourly min/mean/max and completeness), "dia" or "mes".
ceaza_series <- function(sensor, from, to, interval = "hora") {
  ceaza_get(fn = "GetSerieSensor", interv = interval, valor_nan = "nan",
            s_cod = sensor, fecha_inicio = format(as.Date(from)),
            fecha_fin = format(as.Date(to)))
}

# Hourly series of one sensor, one request per calendar year.
ceaza_hourly <- function(sensor, from_year, to_year, pause = 1) {
  out <- lapply(from_year:to_year, function(y) {
    ceaza_series(sensor, sprintf("%d-01-01", y), sprintf("%d-12-31", y),
                 interval = "hora")
  })
  out <- do.call(rbind, out)
  out$time <- as.POSIXct(out$ultima_lectura, tz = "Etc/GMT+4")
  out
}
