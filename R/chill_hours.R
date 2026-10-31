#' Estimate chill hours using a sinusoidal intraday temperature profile
#'
#' Computes the fraction of a 24-hour sinusoidal day falling between lower and
#' upper thresholds. Assumes daily minimum and maximum temperatures; actual
#' temperature profiles can deviate substantially from a sinusoid.
#'
#' @param tmin Daily minimum temperature in degrees Celsius.
#' @param tmax Daily maximum temperature in degrees Celsius.
#' @param lower Lower chilling threshold in degrees Celsius (inclusive).
#' @param upper Upper chilling threshold in degrees Celsius (inclusive).
#' @return Estimated hours per day within [lower, upper].
#' @export
chill_hours <- function(tmin, tmax, lower = 0, upper = 7.2) {
  if (!is.numeric(tmin) || !is.numeric(tmax) || length(tmin) != length(tmax) ||
      !is.numeric(lower) || length(lower) != 1L || !is.finite(lower) ||
      !is.numeric(upper) || length(upper) != 1L || !is.finite(upper) || lower >= upper) {
    stop("Invalid input temperatures or thresholds")
  }
  if (any(tmin > tmax, na.rm = TRUE)) stop("tmin cannot exceed tmax")
  mid <- (tmin + tmax) / 2
  amp <- (tmax - tmin) / 2
  cdf <- function(threshold) {
    x <- (threshold - mid) / amp
    0.5 + asin(pmax(-1, pmin(1, x))) / pi
  }
  out <- 24 * (cdf(upper) - cdf(lower))
  flat <- !is.na(amp) & amp == 0
  out[flat] <- 24 * (mid[flat] >= lower & mid[flat] <= upper)
  pmax(0, pmin(24, out))
}
