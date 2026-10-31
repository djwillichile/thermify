#' Astronomical day length, sunrise and sunset
#'
#' Computes solar declination with the Fourier series of Spencer (1971) and
#' sunrise and sunset (local solar time, hours) for a solar altitude of
#' -0.8333 degrees (upper limb of the disc with standard refraction).
#'
#' @param latitude Latitude in decimal degrees (south negative). Scalar or a
#'   vector recycled against `doy`.
#' @param doy Day of the year (1-366).
#' @return A data frame with columns `doy`, `sunrise`, `sunset` and
#'   `daylength` (hours). Polar day gives `daylength = 24` and polar night
#'   `daylength = 0`; `sunrise` and `sunset` are then set to 0/24 and 12/12.
#' @references
#' Spencer, J. W. (1971). Fourier series representation of the position of the
#' sun. *Search*, 2(5), 172.
#' @examples
#' daylength(-35.97, c(172, 355))
#' @export
daylength <- function(latitude, doy) {
  check_numeric(latitude, "latitude", allow_na = FALSE)
  check_numeric(doy, "doy", allow_na = FALSE)
  if (any(abs(latitude) > 90)) stop("`latitude` must be within [-90, 90].",
                                    call. = FALSE)
  gamma <- 2 * pi * (doy - 1) / 365
  decl <- 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) -
    0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) -
    0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
  phi <- latitude * pi / 180
  cos_h0 <- (sin(-0.8333 * pi / 180) - sin(phi) * sin(decl)) /
    (cos(phi) * cos(decl))
  half <- acos(pmin(1, pmax(-1, cos_h0))) * 12 / pi
  data.frame(doy = doy, sunrise = 12 - half, sunset = 12 + half,
             daylength = 2 * half)
}

#' Reconstruct hourly temperatures from daily extremes
#'
#' Builds an ordered, continuous hourly series (hours 0 to 23 of each day) from
#' daily minimum and maximum temperatures. This is a modelling step with its
#' own uncertainty: reconstructed hours are not observations.
#'
#' @section Methods:
#' * `"linvill"` (default): sine curve during daylight and logarithmic decay at
#'   night (Linvill 1990), with sunrise and sunset from [daylength()]. The
#'   minimum occurs at sunrise and daytime temperatures follow
#'   \eqn{T_{min} + (T_{max} - T_{min}) \sin(\pi (h - h_{sr}) / (D + 4))}.
#'   Night temperatures decay from the sunset temperature to the minimum of the
#'   next day as \eqn{\ln(h - h_{ss} + 1) / \ln(N + 1)}, where \eqn{N} is the
#'   night length. This is the formulation used by
#'   `chillR::make_hourly_temps()`; thermify uses the same \eqn{+1} offset
#'   before and after midnight, so the curve reaches exactly \eqn{T_{min}} at
#'   sunrise (chillR omits the offset in the pre-dawn denominator, giving
#'   values slightly below \eqn{T_{min}} just before sunrise and a small
#'   discontinuity at midnight). Set `night = "chillr"` to reproduce chillR
#'   exactly, for example when comparing with published chillR results.
#' * `"sine"`: continuous half-cosine segments joining
#'   \eqn{T_{max,d-1} \to T_{min,d}} (minimum at `hour_tmin`),
#'   \eqn{T_{min,d} \to T_{max,d}} (maximum at `hour_tmax`) and
#'   \eqn{T_{max,d} \to T_{min,d+1}}. With `hour_tmax - hour_tmin = 12` it is
#'   the symmetric sine; other timings give an asymmetric cycle. It does not
#'   need latitude and is consistent with the double sine degree-day method.
#'
#' The extremes are reached exactly only at the modelled times; integer hours
#' may therefore not include the exact daily minimum or maximum.
#'
#' @section Boundaries:
#' The first night needs the previous day's maximum and the last evening the
#' next day's minimum. With `cyclic = TRUE` the series is treated as a closed
#' climatological year (day 1 follows the last day). Otherwise the first day
#' uses its own maximum and the last day its own minimum.
#'
#' @param tmin,tmax Numeric vectors (or matrices with one row per series and
#'   one column per day) of daily extremes in degrees Celsius.
#' @param method `"linvill"` or `"sine"`.
#' @param latitude Latitude in decimal degrees, required by `"linvill"`.
#'   Scalar, or one value per row when `tmin` is a matrix.
#' @param doy Day of the year of each day (required by `"linvill"`).
#' @param hour_tmin,hour_tmax Local times (hours) of the minimum and maximum
#'   for `method = "sine"`.
#' @param cyclic Treat the series as a closed annual cycle.
#' @param night Pre-dawn formulation for `"linvill"`: `"continuous"`
#'   (default) or `"chillr"` (see Methods).
#'
#' @return For vector input, a numeric vector of length `24 * length(tmin)`
#'   ordered by day and hour. For matrix input, a matrix with one row per
#'   series and `24 * ncol(tmin)` columns.
#' @references
#' Linvill, D. E. (1990). Calculating chilling hours and chill units from daily
#' maximum and minimum temperature observations. *HortScience*, 25(1), 14-16.
#'
#' Luedeling, E. (2012). Climate change impacts on winter chill for temperate
#' fruit and nut production: a review. *Scientia Horticulturae*, 144, 218-229.
#' @examples
#' h <- hourly_temperatures(c(2, 4), c(14, 16), latitude = -35.97,
#'                          doy = c(180, 181))
#' round(h, 1)
#' hourly_temperatures(c(2, 4), c(14, 16), method = "sine")
#' @export
hourly_temperatures <- function(tmin, tmax, method = c("linvill", "sine"),
                                latitude = NULL, doy = NULL,
                                hour_tmin = 6, hour_tmax = 15,
                                cyclic = FALSE,
                                night = c("continuous", "chillr")) {
  method <- match.arg(method)
  night <- match.arg(night)
  was_vector <- !is.matrix(tmin)
  if (was_vector) {
    check_tmin_tmax(tmin, tmax)
    tmin <- matrix(tmin, nrow = 1L)
    tmax <- matrix(tmax, nrow = 1L)
  } else {
    if (!is.matrix(tmax) || !identical(dim(tmin), dim(tmax))) {
      stop("`tmin` and `tmax` must be matrices of the same dimensions.",
           call. = FALSE)
    }
    check_tmin_tmax(as.vector(tmin), as.vector(tmax))
  }
  n_days <- ncol(tmin)
  prev_idx <- c(if (cyclic) n_days else 1L, seq_len(n_days - 1L))
  next_idx <- c(seq_len(n_days)[-1L], if (cyclic) 1L else n_days)
  tmax_prev <- tmax[, prev_idx, drop = FALSE]
  tmin_next <- tmin[, next_idx, drop = FALSE]

  out <- if (method == "sine") {
    hourly_sine(tmin, tmax, tmax_prev, tmin_next, hour_tmin, hour_tmax)
  } else {
    if (is.null(latitude) || is.null(doy)) {
      stop("`method = \"linvill\"` requires `latitude` and `doy`.",
           call. = FALSE)
    }
    if (length(doy) != n_days) {
      stop("`doy` must have one value per day.", call. = FALSE)
    }
    if (!length(latitude) %in% c(1L, nrow(tmin))) {
      stop("`latitude` must be a scalar or have one value per series.",
           call. = FALSE)
    }
    hourly_linvill(tmin, tmax, tmax_prev, tmin_next, latitude, doy,
                   prev_idx, next_idx, night)
  }
  if (was_vector) as.vector(out) else out
}

# Interleave a list of (series x day) matrices, one per hour, into a
# (series x 24*day) matrix ordered by day then hour.
interleave_hours <- function(hours) {
  n_series <- nrow(hours[[1L]])
  n_days <- ncol(hours[[1L]])
  arr <- array(unlist(hours, use.names = FALSE),
               dim = c(n_series, n_days, 24L))
  matrix(aperm(arr, c(1L, 3L, 2L)), nrow = n_series)
}

hourly_sine <- function(tmin, tmax, tmax_prev, tmin_next, hour_tmin,
                        hour_tmax) {
  check_scalar(hour_tmin, "hour_tmin")
  check_scalar(hour_tmax, "hour_tmax")
  if (!(hour_tmin >= 0 && hour_tmin < hour_tmax && hour_tmax < 24)) {
    stop("Require 0 <= hour_tmin < hour_tmax < 24.", call. = FALSE)
  }
  # Half-cosine from value a (at time t0) to value b (at time t1).
  segment <- function(a, b, h, t0, t1) {
    p <- (h - t0) / (t1 - t0)
    a + (b - a) * (1 - cos(pi * p)) / 2
  }
  hours <- lapply(0:23, function(h) {
    if (h < hour_tmin) {
      segment(tmax_prev, tmin, h, hour_tmax - 24, hour_tmin)
    } else if (h <= hour_tmax) {
      segment(tmin, tmax, h, hour_tmin, hour_tmax)
    } else {
      segment(tmax, tmin_next, h, hour_tmax, hour_tmin + 24)
    }
  })
  interleave_hours(hours)
}

hourly_linvill <- function(tmin, tmax, tmax_prev, tmin_next, latitude, doy,
                           prev_idx, next_idx, night) {
  n_series <- nrow(tmin)
  lat <- rep_len(latitude, n_series)
  # Sun times depend on latitude (rows) and day (columns).
  sun <- lapply(unique(lat), function(l) daylength(l, doy))
  pick <- function(field) {
    vals <- vapply(sun, function(s) s[[field]], numeric(length(doy)))
    vals <- matrix(vals, ncol = length(sun))
    t(vals[, match(lat, unique(lat)), drop = FALSE])
  }
  sr <- pick("sunrise")
  ss <- pick("sunset")
  dl <- pick("daylength")
  sr_next <- sr[, next_idx, drop = FALSE]
  ss_prev <- ss[, prev_idx, drop = FALSE]
  dl_prev <- dl[, prev_idx, drop = FALSE]
  tmin_prev <- tmin[, prev_idx, drop = FALSE]

  t_sunset <- tmin + (tmax - tmin) * sin(pi * dl / (dl + 4))
  # chillR evaluates the previous sunset temperature with the current day's
  # day length; reproduced only in compatibility mode.
  dl_ss <- if (night == "continuous") dl_prev else dl
  t_sunset_prev <- tmin_prev + (tmax_prev - tmin_prev) *
    sin(pi * dl_ss / (dl_ss + 4))
  pre_dawn_den <- if (night == "continuous") {
    log(24 - ss_prev + sr + 1)
  } else {
    log(pmax(1, 24 - ss_prev + sr))
  }
  polar <- dl <= 0 | dl >= 24
  tmean <- (tmin + tmax) / 2

  hours <- lapply(0:23, function(h) {
    # Evaluate each branch only where it applies.
    val <- tmin + (tmax - tmin) * sin(pi * (h - sr) / (dl + 4))
    am <- h <= sr
    val[am] <- (t_sunset_prev - (t_sunset_prev - tmin) *
      log(h + 24 - ss_prev + 1) / pre_dawn_den)[am]
    pm <- h > ss
    val[pm] <- (t_sunset - (t_sunset - tmin_next) *
      log(pmax(h - ss + 1, 1)) / log(24 - ss + sr_next + 1))[pm]
    val[polar] <- tmean[polar]
    val
  })
  interleave_hours(hours)
}
