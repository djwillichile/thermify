# Cross-check thermify against independent reference implementations.
#
# Reference code (chillR, degday) is GPL-licensed and is NOT bundled with
# thermify. This script loads it from installed packages when available, or
# from source checkouts given by the environment variables CHILLR_SRC and
# DEGDAY_SRC (paths to the package source trees, e.g. git clones of
# https://github.com/cran/chillR and https://github.com/cran/degday).
#
# Usage: Rscript inst/verification/verify_references.R [output.csv]

suppressPackageStartupMessages({
  if (requireNamespace("thermify", quietly = TRUE)) library(thermify) else
    devtools::load_all(quiet = TRUE)
})
args <- commandArgs(trailingOnly = TRUE)
out_csv <- if (length(args)) args[1] else NA_character_

ref <- new.env()
load_ref <- function(pkg, src_var, files) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    for (f in c(files$functions)) assign(f, getExportedValue(pkg, f), ref)
    return(paste(pkg, utils::packageVersion(pkg)))
  }
  src <- Sys.getenv(src_var)
  if (!nzchar(src)) return(NA_character_)
  for (f in files$sources) sys.source(file.path(src, "R", f), envir = ref)
  desc <- read.dcf(file.path(src, "DESCRIPTION"))
  paste(pkg, desc[1, "Version"], "(source)")
}
v_chillr <- load_ref("chillR", "CHILLR_SRC", list(
  functions = c("Dynamic_Model", "Utah_Model", "Chilling_Hours",
                "make_hourly_temps", "daylength"),
  sources = c("temp_models.R", "make_hourly_temps.R", "daylength.R")))
v_degday <- tryCatch(load_ref("degday", "DEGDAY_SRC", list(
  functions = "dd_calc", sources = "dd_calc.R")), error = function(e) NA)
if (exists("dd_calc", envir = ref, inherits = FALSE)) {
  # degday helpers live in the same file; crayon colours are cosmetic.
  for (fn in c("yellow", "red")) assign(fn, function(x) x, ref)
  environment(ref$dd_calc) <- ref
}

set.seed(20231)
n <- 365
doy <- 1:n
tmin <- 6 + 5 * cos(2 * pi * (doy - 15) / 365) + rnorm(n, 0, 2)
tmax <- tmin + pmax(2, 13 + 4 * cos(2 * pi * (doy - 15) / 365) + rnorm(n, 0, 2))
hourly <- hourly_temperatures(tmin, tmax, "linvill", latitude = -35.97,
                              doy = doy)

results <- list()
add <- function(check, reference, value) {
  results[[length(results) + 1]] <<- data.frame(check = check,
    reference = reference, max_abs_diff = value)
}

if (!is.na(v_chillr)) {
  cp_ref <- ref$Dynamic_Model(hourly)
  cp_thm <- as.vector(chill_portions(hourly))
  # chillR reports the portion of hour h at position h + 1.
  add("Dynamic model, cumulative (lag-aligned)", v_chillr,
      max(abs(cp_ref[-1] - cp_thm[-length(cp_thm)])))
  add("Utah model, cumulative", v_chillr,
      max(abs(ref$Utah_Model(hourly) - as.vector(chill_units(hourly)))))
  add("Chilling hours 0-7.2, cumulative", v_chillr,
      max(abs(ref$Chilling_Hours(hourly) -
                as.vector(chill_hours_hourly(hourly)))))
  dl_ref <- ref$daylength(-35.97, doy)
  dl_thm <- daylength(-35.97, doy)
  add("Day length (h)", v_chillr, max(abs(dl_ref$Daylength - dl_thm$daylength)))
  dates <- as.Date("2023-01-01") + doy - 1
  yf <- data.frame(Year = 2023, Month = as.integer(format(dates, "%m")),
                   Day = as.integer(format(dates, "%d")), Tmin = tmin,
                   Tmax = tmax)
  hr <- ref$make_hourly_temps(-35.97, yf)
  hr_ref <- as.vector(t(as.matrix(hr[, paste0("Hour_", 0:23)])))
  inner <- 25:(24 * (n - 1))   # first/last days use different boundary fills
  hour <- (seq_along(hr_ref) - 1) %% 24
  sr <- rep(dl_thm$sunrise, each = 24)
  pre_dawn <- hour <= sr
  add("Linvill hourly temperatures, daytime and evening", v_chillr,
      max(abs(hr_ref - hourly)[intersect(inner, which(!pre_dawn))]))
  add("Linvill hourly temperatures, pre-dawn, night = 'continuous'",
      v_chillr, max(abs(hr_ref - hourly)[intersect(inner, which(pre_dawn))]))
  compat <- hourly_temperatures(tmin, tmax, "linvill", latitude = -35.97,
                                doy = doy, night = "chillr")
  add("Linvill hourly temperatures, all hours, night = 'chillr'", v_chillr,
      max(abs(hr_ref - compat)[inner]))
}

if (exists("dd_calc", envir = ref, inherits = FALSE)) {
  nxt <- c(tmin[-1], NA)
  for (m in c("sng_sine", "sng_tri", "dbl_sine", "dbl_tri", "simp_avg")) {
    thm <- c(sng_sine = "single_sine", sng_tri = "single_triangle",
             dbl_sine = "double_sine", dbl_tri = "double_triangle",
             simp_avg = "average")[[m]]
    up <- if (m == "simp_avg") NULL else 22
    r <- ref$dd_calc(tmin, tmax, nextday_min = nxt, thresh_low = 10,
                     thresh_up = up, method = m, digits = 12, quiet = TRUE)
    t2 <- degree_days(tmin, tmax, method = thm, base = 10, upper = up,
                      tmin_next = nxt)
    add(sprintf("GDD %s, base 10, upper %s, horizontal", thm,
                if (is.null(up)) "none" else up), v_degday,
        max(abs(r - t2), na.rm = TRUE))
  }
}

res <- do.call(rbind, results)
print(res, row.names = FALSE, digits = 3)
if (!is.na(out_csv)) utils::write.csv(res, out_csv, row.names = FALSE)
