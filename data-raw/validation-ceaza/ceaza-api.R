# Minimal client for the public CEAZA-Met web service
# (https://www.ceazamet.cl/ws/pop_ws.php). Data are provided by CEAZA through
# the CEAZA-Met system; see www.ceazamet.cl for the conditions of use and
# cite CEAZA as the source. Raw data are cached locally and are not
# redistributed with thermify.

ceaza_ws <- "https://www.ceazamet.cl/ws/pop_ws.php"

ceaza_get <- function(..., pause = 1) {
  args <- list(...)
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
# Times are local standard time (GMT-4, no daylight saving).
ceaza_series <- function(sensor, from, to, interval = "hora") {
  ceaza_get(fn = "GetSerieSensor", interv = interval, valor_nan = "nan",
            s_cod = sensor, fecha_inicio = format(as.Date(from)),
            fecha_fin = format(as.Date(to)))
}
