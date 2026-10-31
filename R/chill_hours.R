#' Chilling hours estimated from daily minimum and maximum temperatures
#'
#' Estimates the number of hours per day with temperatures inside the
#' chilling interval `[lower, upper]` from daily extremes, by assuming an
#' idealised diurnal profile. The default interval (0 to 7.2 degrees Celsius)
#' corresponds to the "0-7.2 degrees C" chilling-hours model derived from the
#' 45 degrees F threshold of Weinberger (1950).
#'
#' @section Methods:
#' * `"sine"` (default): closed-form duration for a sine wave between `tmin`
#'   and `tmax`. With mean \eqn{M} and amplitude \eqn{A}, the fraction of the
#'   day above \eqn{x} is \eqn{1/2 - \arcsin((x - M)/A)/\pi}.
#' * `"triangle"`: closed-form duration for a symmetric triangular profile
#'   (temperatures uniformly distributed between `tmin` and `tmax`).
#' * `"numerical"`: numerical reference for the sine profile, evaluated on
#'   `n_steps` equally spaced instants per day. It converges to `"sine"` and
#'   is intended for verification only.
#'
#' The duration depends only on the distribution of temperatures within the
#' day, not on the timing of the extremes. Results are model-based
#' **estimates**, not observed chilling hours; real diurnal cycles depart from
#' a sine wave (cloudiness, advection, cold-air pooling). Use
#' [chill_hours_hourly()] when hourly observations are available.
#'
#' When `tmin == tmax` the day is either entirely inside (24 h) or outside
#' (0 h) the interval; both bounds are inclusive in that case.
#'
#' @param tmin,tmax Numeric vectors of daily minimum and maximum temperatures
#'   (degrees Celsius).
#' @param method `"sine"`, `"triangle"` or `"numerical"`.
#' @param lower,upper Bounds of the chilling interval (degrees Celsius).
#' @param n_steps Number of evaluation instants per day for
#'   `method = "numerical"`.
#'
#' @return Numeric vector of estimated hours per day, between 0 and 24.
#' @references
#' Weinberger, J. H. (1950). Chilling requirements of peach varieties.
#' *Proceedings of the American Society for Horticultural Science*, 56,
#' 122-128.
#'
#' Luedeling, E. (2012). Climate change impacts on winter chill for temperate
#' fruit and nut production: a review. *Scientia Horticulturae*, 144, 218-229.
#' @seealso [chill_hours_hourly()], [chill_units()], [chill_portions()].
#' @examples
#' chill_hours(c(-2, 4, 10), c(10, 12, 20))
#' chill_hours(c(-2, 4, 10), c(10, 12, 20), method = "triangle")
#' chill_hours(c(-2, 4, 10), c(10, 12, 20), lower = -Inf, upper = 7.2)
#' @export
chill_hours <- function(tmin, tmax, method = c("sine", "triangle", "numerical"),
                        lower = 0, upper = 7.2, n_steps = 1440L) {
  method <- match.arg(method)
  check_tmin_tmax(tmin, tmax)
  check_chill_bounds(lower, upper)

  if (method == "numerical") {
    temps <- profile_values(tmin, tmax, n = n_steps, shape = "sine")
    inside <- temps >= lower & temps <= upper
    return(24 * rowMeans(inside))
  }
  above_lower <- profile_above(tmin, tmax, lower, method)
  above_upper <- profile_above(tmin, tmax, upper, method)
  out <- 24 * (above_lower - above_upper)
  flat <- !is.na(tmin) & !is.na(tmax) & tmin == tmax
  out[flat] <- 24 * (tmin[flat] >= lower & tmin[flat] <= upper)
  pmax(0, pmin(24, out))
}

#' Chilling hours counted from hourly temperatures
#'
#' Counts hours with temperatures inside the closed interval `[lower, upper]`.
#' This is the observational definition of chilling hours and should be
#' preferred over [chill_hours()] whenever hourly records exist.
#'
#' @param temperature Numeric vector (or matrix, one row per series) of hourly
#'   temperatures in degrees Celsius, at regular one-hour steps.
#' @inheritParams chill_hours
#' @param output `"cumulative"` (default), `"hourly"` (0/1 per hour) or
#'   `"total"`.
#' @param na_action `"propagate"` (default) turns the cumulative sum into `NA`
#'   from the first missing hour; `"skip"` counts missing hours as outside the
#'   interval and records the number skipped in the `"n_missing"` attribute.
#'
#' @return Chilling hours with the shape implied by `output`.
#' @examples
#' temp <- c(-1, 0, 3, 7.2, 7.3, 10)
#' chill_hours_hourly(temp, output = "hourly")
#' chill_hours_hourly(temp, output = "total")
#' @export
chill_hours_hourly <- function(temperature, lower = 0, upper = 7.2,
                               output = c("cumulative", "hourly", "total"),
                               na_action = c("propagate", "skip")) {
  output <- match.arg(output)
  na_action <- match.arg(na_action)
  check_chill_bounds(lower, upper)
  s <- as_series_matrix(temperature)
  w <- (s$m >= lower & s$m <= upper) * 1
  sequential_output(w, s$was_vector, output, na_action)
}

check_chill_bounds <- function(lower, upper) {
  if (!is.numeric(lower) || length(lower) != 1L || is.na(lower) ||
      !is.numeric(upper) || length(upper) != 1L || is.na(upper) ||
      lower >= upper) {
    stop("`lower` and `upper` must be single numbers with lower < upper.",
         call. = FALSE)
  }
  invisible(TRUE)
}

# Shared output handling for hourly weights (one row per series).
sequential_output <- function(w, was_vector, output, na_action) {
  n_missing <- rowSums(is.na(w))
  if (na_action == "skip") w[is.na(w)] <- 0
  out <- switch(output,
    hourly = w,
    cumulative = row_cumsum(w),
    total = rowSums(w)
  )
  if (was_vector && is.matrix(out)) out <- as.vector(out)
  if (na_action == "skip") attr(out, "n_missing") <- n_missing
  out
}

row_cumsum <- function(m) {
  if (nrow(m) == 1L) return(matrix(cumsum(m[1L, ]), nrow = 1L))
  t(apply(m, 1L, cumsum))
}
