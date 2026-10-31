#' Densify monthly climatologies to daily values
#'
#' Converts 12 monthly values (one climatological year) to daily values for a
#' reference calendar year. The default `"pchip_mp"` method fits a cyclic
#' piecewise cubic Hermite interpolant (PCHIP, Fritsch-Butland derivatives as
#' in `scipy.interpolate.PchipInterpolator`) through the monthly values placed
#' at mid-month and then corrects each month so that the mean of its daily
#' values equals the input monthly value (mean-preserving step).
#'
#' @section Engines:
#' * `engine = "tempify"` calls the Python package
#'   [tempify](https://github.com/djwillichile/tempify) through `reticulate`.
#'   It is the reference implementation and supports all tempify methods.
#' * `engine = "native"` is a pure R implementation of `"pchip"` and
#'   `"pchip_mp"` that follows the tempify algorithm (cyclic padding with two
#'   nodes on each side, mid-month anchors, uniform monthly correction). It
#'   needs no Python and is tested against tempify to within 1e-9 degrees C.
#' * `engine = "auto"` uses tempify when it is importable and native
#'   otherwise.
#'
#' @section Mean preservation and its side effects:
#' The tempify mean-preserving step adds the residual of each month uniformly
#' to its days. Monthly means are therefore reproduced exactly (up to the
#' convergence tolerance), but the daily curve is piecewise shifted and can
#' show small steps at month boundaries. [densify_diagnostics()] reports the
#' magnitude of those steps.
#'
#' @section Physical consistency:
#' Independent interpolation of `tmin` and `tmax` can, in principle, produce
#' days with \eqn{T_{min} > T_{max}}. With `consistency = "check"` such days
#' raise an error. With `consistency = "mean_range"` the daily mean
#' \eqn{(T_{min}+T_{max})/2} and the diurnal range \eqn{T_{max}-T_{min}} are
#' densified instead and transformed back. Because the transformation is
#' linear, monthly means of `tmin` and `tmax` are still preserved exactly;
#' an error is raised if the densified range becomes negative. Extremes are
#' never swapped or clipped silently.
#'
#' @param tmin,tmax Numeric vectors of length 12, or matrices with one row per
#'   location and 12 columns (January to December), in degrees Celsius.
#' @param year Reference calendar year. Default 2023 (365 days); leap years
#'   give 366 days.
#' @param method Interpolation method. `"pchip_mp"` (default) or `"pchip"`
#'   for both engines; tempify also offers `"linear"`, `"akima"`, `"cubic"`
#'   and `"fourier"`.
#' @param engine `"auto"`, `"tempify"` or `"native"`.
#' @param consistency `"check"` or `"mean_range"`.
#'
#' @return A list with matrices `tmin` and `tmax` (one row per location, one
#'   column per day), the vector of `dates`, and `provenance` (engine,
#'   method, versions and diagnostics). Rows with any missing month are `NA`.
#' @references
#' Rymes, M. D., & Myers, D. R. (2001). Mean preserving algorithm for smoothly
#' interpolating averaged data. *Solar Energy*, 71(4), 225-231.
#'
#' Fritsch, F. N., & Butland, J. (1984). A method for constructing local
#' monotone piecewise cubic interpolants. *SIAM Journal on Scientific and
#' Statistical Computing*, 5(2), 300-304.
#' @seealso [tempify_available()], [densify_diagnostics()].
#' @examples
#' tmin <- c(11, 11, 9, 7, 5, 4, 3, 4, 5, 7, 9, 10)
#' tmax <- c(29, 29, 26, 22, 17, 14, 13, 15, 18, 21, 25, 28)
#' d <- densify_monthly(tmin, tmax, engine = "native")
#' dim(d$tmin)
#' # Monthly means are preserved
#' tapply(d$tmin[1, ], format(d$dates, "%m"), mean)
#' @export
densify_monthly <- function(tmin, tmax, year = 2023, method = "pchip_mp",
                            engine = c("auto", "tempify", "native"),
                            consistency = c("check", "mean_range")) {
  engine <- match.arg(engine)
  consistency <- match.arg(consistency)
  check_scalar(year, "year")
  tmin <- as_monthly_matrix(tmin, "tmin")
  tmax <- as_monthly_matrix(tmax, "tmax")
  if (!identical(dim(tmin), dim(tmax))) {
    stop("`tmin` and `tmax` must have the same dimensions.", call. = FALSE)
  }
  bad <- which(tmin > tmax)
  if (length(bad) > 0L) {
    stop(sprintf("Monthly `tmin` exceeds `tmax` in %d value(s).",
                 length(bad)), call. = FALSE)
  }
  if (engine == "auto") engine <- if (tempify_available()) "tempify" else
    "native"
  if (engine == "native" && !method %in% c("pchip", "pchip_mp")) {
    stop("The native engine implements \"pchip\" and \"pchip_mp\" only; ",
         "use engine = \"tempify\" for other methods.", call. = FALSE)
  }
  dates <- seq(as.Date(sprintf("%d-01-01", year)),
               as.Date(sprintf("%d-12-31", year)), by = "day")
  run <- function(x) {
    if (engine == "tempify") densify_tempify(x, year, method) else
      densify_native(x, year, method)
  }

  if (consistency == "check") {
    dmin <- run(tmin)
    dmax <- run(tmax)
    crossings <- sum(dmin > dmax, na.rm = TRUE)
    if (crossings > 0L) {
      stop(sprintf(paste(
        "Independent densification produced %d day(s) with tmin > tmax.",
        "Use consistency = \"mean_range\" for a joint, mean-preserving",
        "reconstruction.")), crossings, call. = FALSE)
    }
  } else {
    dmean <- run((tmin + tmax) / 2)
    drange <- run(tmax - tmin)
    if (any(drange < 0, na.rm = TRUE)) {
      stop("The densified diurnal range is negative on ",
           sum(drange < 0, na.rm = TRUE), " day(s).", call. = FALSE)
    }
    dmin <- dmean - drange / 2
    dmax <- dmean + drange / 2
  }

  provenance <- list(
    engine = engine, method = method, year = year,
    consistency = consistency, n_days = length(dates),
    tempify = if (engine == "tempify") tempify_version() else NULL,
    max_abs_mean_error = max(
      monthly_mean_error(dmin, tmin, dates),
      monthly_mean_error(dmax, tmax, dates), na.rm = TRUE)
  )
  list(tmin = dmin, tmax = dmax, dates = dates, provenance = provenance)
}

as_monthly_matrix <- function(x, name) {
  check_numeric(x, name)
  if (!is.matrix(x)) x <- matrix(x, nrow = 1L)
  if (ncol(x) != 12L) {
    stop(sprintf("`%s` must have 12 monthly values per location.", name),
         call. = FALSE)
  }
  x
}

monthly_mean_error <- function(daily, monthly, dates) {
  month <- as.integer(format(dates, "%m"))
  recon <- vapply(1:12, function(m) rowMeans(daily[, month == m,
                                                    drop = FALSE]),
                  numeric(nrow(daily)))
  recon <- matrix(recon, nrow = nrow(daily))
  err <- abs(recon - monthly)
  if (all(is.na(err))) return(NA_real_)
  max(err, na.rm = TRUE)
}

#' Diagnostics of a monthly-to-daily densification
#'
#' Summarises how well a densified series reproduces the monthly input and how
#' smooth it is at month boundaries.
#'
#' @param daily Matrix of daily values (one row per location).
#' @param monthly Matrix of the 12 monthly input values (one row per
#'   location).
#' @param dates Dates of the daily columns.
#' @return A data frame with one row per location: `max_abs_mean_error`
#'   (degrees C), `max_boundary_step` (largest absolute day-to-day change
#'   across a month boundary, degrees C) and `max_interior_step` (largest
#'   absolute day-to-day change within months, degrees C).
#' @export
densify_diagnostics <- function(daily, monthly, dates) {
  daily <- as_series_matrix(daily, "daily")$m
  monthly <- as_monthly_matrix(monthly, "monthly")
  month <- as.integer(format(dates, "%m"))
  steps <- abs(daily[, -1L, drop = FALSE] - daily[, -ncol(daily),
                                                  drop = FALSE])
  boundary <- month[-1L] != month[-length(month)]
  row_max <- function(m) apply(m, 1L, function(v) {
    if (all(is.na(v))) NA_real_ else max(v, na.rm = TRUE)
  })
  data.frame(
    max_abs_mean_error = vapply(seq_len(nrow(daily)), function(i)
      monthly_mean_error(daily[i, , drop = FALSE], monthly[i, , drop = FALSE],
                         dates), numeric(1)),
    max_boundary_step = row_max(steps[, boundary, drop = FALSE]),
    max_interior_step = row_max(steps[, !boundary, drop = FALSE])
  )
}

# ---------------------------------------------------------------------------
# Native engine

# Mid-month anchors: day (days_in_month + 1) %/% 2 of each month, as day of
# the year. Matches tempify's monthly_midpoint() convention (CF 7.4).
month_anchor_doy <- function(year) {
  starts <- as.Date(sprintf("%d-%02d-01", year, 1:12))
  ends <- c(starts[-1L], as.Date(sprintf("%d-01-01", year + 1))) - 1
  dim <- as.integer(format(ends, "%d"))
  as.integer(format(starts, "%j")) + (dim + 1L) %/% 2L - 1L
}

# Interior PCHIP derivatives (Fritsch-Butland weighted harmonic mean), for
# a matrix of values (rows = series) on common knots x.
pchip_slopes <- function(x, y) {
  h <- diff(x)
  delta <- (y[, -1L, drop = FALSE] - y[, -ncol(y), drop = FALSE]) /
    rep(h, each = nrow(y))
  k <- ncol(y)
  d <- matrix(0, nrow(y), k)
  for (j in 2:(k - 1L)) {
    d1 <- delta[, j - 1L]
    d2 <- delta[, j]
    w1 <- 2 * h[j] + h[j - 1L]
    w2 <- h[j] + 2 * h[j - 1L]
    same <- d1 * d2 > 0
    d[same, j] <- (w1 + w2) / (w1 / d1[same] + w2 / d2[same])
  }
  # End-point derivatives are not needed: with two padding nodes on each side
  # every target day lies in an interior interval.
  d
}

densify_native <- function(m, year, method) {
  n_days <- ncol_days(year)
  period <- n_days
  x_in <- month_anchor_doy(year)
  x_ext <- c(x_in[11:12] - period, x_in, x_in[1:2] + period)
  out <- matrix(NA_real_, nrow(m), n_days)
  ok <- stats::complete.cases(m)
  if (!any(ok)) return(out)
  y <- m[ok, , drop = FALSE]
  y_ext <- cbind(y[, 11:12, drop = FALSE], y, y[, 1:2, drop = FALSE])
  d <- pchip_slopes(x_ext, y_ext)

  x_out <- seq_len(n_days)
  seg <- findInterval(x_out, x_ext)
  h <- x_ext[seg + 1L] - x_ext[seg]
  t <- (x_out - x_ext[seg]) / h
  h00 <- 2 * t^3 - 3 * t^2 + 1
  h10 <- t^3 - 2 * t^2 + t
  h01 <- -2 * t^3 + 3 * t^2
  h11 <- t^3 - t^2
  daily <- sweep(y_ext[, seg, drop = FALSE], 2L, h00, `*`) +
    sweep(d[, seg, drop = FALSE], 2L, h10 * h, `*`) +
    sweep(y_ext[, seg + 1L, drop = FALSE], 2L, h01, `*`) +
    sweep(d[, seg + 1L, drop = FALSE], 2L, h11 * h, `*`)

  if (method == "pchip_mp") {
    dates <- as.Date(sprintf("%d-01-01", year)) + x_out - 1L
    month <- as.integer(format(dates, "%m"))
    for (iter in seq_len(50L)) {
      recon <- vapply(1:12, function(k) rowMeans(daily[, month == k,
                                                       drop = FALSE]),
                      numeric(nrow(daily)))
      recon <- matrix(recon, nrow = nrow(daily))
      err <- y - recon
      if (max(abs(err)) < 1e-6) break
      daily <- daily + err[, month, drop = FALSE]
    }
  }
  out[ok, ] <- daily
  out
}

# ---------------------------------------------------------------------------
# tempify engine

#' Is the tempify Python package available?
#'
#' Checks that `reticulate` is installed and that the active Python
#' environment can import `tempify`. Use `reticulate::use_virtualenv()` or the
#' `RETICULATE_PYTHON` environment variable to select the environment.
#'
#' @return `TRUE` or `FALSE`.
#' @export
tempify_available <- function() {
  requireNamespace("reticulate", quietly = TRUE) &&
    isTRUE(tryCatch(reticulate::py_module_available("tempify"),
                    error = function(e) FALSE))
}

#' Version information of the tempify backend
#'
#' Returns the tempify version, the git commit of its source tree when it is
#' installed from a git checkout, and the Python, NumPy and xarray versions.
#' Recorded in the provenance of every densification for reproducibility.
#'
#' @return A named list, or `NULL` when tempify is not available.
#' @export
tempify_version <- function() {
  if (!tempify_available()) return(NULL)
  tf <- reticulate::import("tempify", convert = FALSE)
  np <- reticulate::import("numpy", convert = FALSE)
  xr <- reticulate::import("xarray", convert = FALSE)
  src <- dirname(dirname(dirname(reticulate::py_to_r(tf$`__file__`))))
  commit <- NA_character_
  if (nzchar(Sys.which("git")) && dir.exists(file.path(src, ".git"))) {
    commit <- tryCatch(
      system2("git", c("-C", shQuote(src), "rev-parse", "HEAD"),
              stdout = TRUE, stderr = FALSE),
      error = function(e) NA_character_, warning = function(w) NA_character_)
  }
  list(
    tempify = reticulate::py_to_r(tf$`__version__`),
    commit = commit[1L],
    python = reticulate::py_config()$version_string,
    numpy = reticulate::py_to_r(np$`__version__`),
    xarray = reticulate::py_to_r(xr$`__version__`)
  )
}

densify_tempify <- function(m, year, method) {
  if (!tempify_available()) {
    stop("The tempify engine needs the Python package tempify ",
         "(https://github.com/djwillichile/tempify) reachable through ",
         "reticulate. Use engine = \"native\" to run without Python.",
         call. = FALSE)
  }
  interp <- reticulate::import("tempify.interpolation", convert = FALSE)
  xr <- reticulate::import("xarray", convert = FALSE)
  np <- reticulate::import("numpy", convert = FALSE)
  classes <- c(linear = "LinearInterpolator", pchip = "PchipInterpolator",
               pchip_mp = "PchipMeanPreservingInterpolator",
               akima = "AkimaInterpolator", cubic = "CubicSplineInterpolator",
               fourier = "FourierInterpolator")
  if (!method %in% names(classes)) {
    stop("Unknown tempify method: ", method, call. = FALSE)
  }
  # Values cross the R/Python boundary as raw little-endian float64 buffers.
  # This avoids any dependence on reticulate's NumPy ABI support and copies
  # the data only once in each direction.
  buf <- reticulate::r_to_py(writeBin(as.vector(t(m)), raw(), size = 8L,
                                      endian = "little"))
  arr <- np$frombuffer(buf, dtype = "<f8")$reshape(
    reticulate::tuple(as.integer(nrow(m)), 12L))
  da <- xr$DataArray(arr, dims = reticulate::tuple("cell", "month"),
                     coords = reticulate::dict(month = 1:12))
  axis <- interp$TemporalAxis$from_months(as.integer(year))
  res <- interp[[classes[[method]]]]()$interpolate(
    da, axis, nan_policy = "propagate_all")
  bytes <- res$transpose("cell", "time")$values$astype("<f8")$tobytes()
  bytes <- reticulate::import_builtins(convert = FALSE)$bytearray(bytes)
  vals <- readBin(reticulate::py_to_r(bytes), "double",
                  n = nrow(m) * ncol_days(year), size = 8L,
                  endian = "little")
  matrix(vals, nrow = nrow(m), byrow = TRUE)
}

ncol_days <- function(year) {
  if ((year %% 4 == 0 && year %% 100 != 0) || year %% 400 == 0) 366L else 365L
}
