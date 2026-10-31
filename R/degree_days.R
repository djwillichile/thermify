#' Growing degree-days from daily minimum and maximum temperatures
#'
#' Computes daily growing degree-days (GDD, in degree Celsius day) with the
#' averaging, single sine, single triangle, double sine or double triangle
#' methods, optionally bounded by an upper developmental threshold.
#'
#' @section Methods:
#' All sine and triangle methods are evaluated with closed-form expressions;
#' no hourly temperatures are generated.
#'
#' * `"average"`: \eqn{\max(0, (T_{max} + T_{min}) / 2 - T_b)} (McMaster &
#'   Wilhelm 1997, method 1). With an upper threshold the cutoff is applied to
#'   the daily mean.
#' * `"single_sine"`: a sine wave between `tmin` and `tmax` over 24 h
#'   (Baskerville & Emin 1969).
#' * `"single_triangle"`: a symmetric triangle between `tmin` and `tmax`
#'   (Lindsey & Newman 1956; Sevacherian et al. 1977).
#' * `"double_sine"`, `"double_triangle"`: the day is split into two
#'   half-day segments: `tmin` to `tmax` of the same day, then `tmax` to the
#'   minimum of the following day (`tmin_next`). Each half contributes half a
#'   day (Allen 1976; Zalom et al. 1983).
#'
#' @section Upper threshold cutoffs:
#' With an upper threshold \eqn{T_u}:
#' * `"horizontal"`: development continues at the constant rate reached at
#'   \eqn{T_u}; the area above \eqn{T_u} is removed.
#' * `"vertical"`: no development while temperature exceeds \eqn{T_u}; the
#'   whole area under the curve during those hours is removed.
#' * `"intermediate"`: development decreases linearly above \eqn{T_u} with
#'   slope -1 (the area above \eqn{T_u} is subtracted a second time), with the
#'   rate floored at zero. The floor only matters when temperatures exceed
#'   \eqn{2T_u - T_b}.
#'
#' The three cutoffs coincide when temperatures stay below `upper` and give
#' different results otherwise; they are not interchangeable.
#'
#' @section Missing values and boundaries:
#' Missing `tmin` or `tmax` give `NA` for that day. Double methods need the
#' minimum of the next day; when `tmin_next` is `NULL` it is taken from the
#' following element of `tmin`, and the last day is `NA`. Supply `tmin_next`
#' explicitly to close the series (for a cyclic climatological year pass
#' `c(tmin[-1], tmin[1])`). If the following minimum is above the current
#' maximum, the second half-day segment is evaluated between the two values in
#' increasing order.
#'
#' @param tmin,tmax Numeric vectors of daily minimum and maximum temperatures
#'   (degrees Celsius), of equal length, ordered in time for double methods.
#' @param method One of `"single_sine"` (default), `"average"`,
#'   `"single_triangle"`, `"double_sine"` or `"double_triangle"`.
#' @param base Lower developmental threshold (degrees Celsius).
#' @param upper Optional upper developmental threshold (degrees Celsius).
#' @param cutoff Upper threshold treatment: `"horizontal"` (default),
#'   `"vertical"` or `"intermediate"`. Ignored when `upper` is `NULL`.
#' @param tmin_next Optional numeric vector with the minimum temperature of the
#'   following day, used only by double methods.
#'
#' @return Numeric vector of daily degree-days (degree Celsius day), same length
#'   as `tmin`.
#'
#' @references
#' Allen, J. C. (1976). A modified sine wave method for calculating degree
#' days. *Environmental Entomology*, 5(3), 388-396.
#'
#' Baskerville, G. L., & Emin, P. (1969). Rapid estimation of heat
#' accumulation from maximum and minimum temperatures. *Ecology*, 50(3),
#' 514-517.
#'
#' Lindsey, A. A., & Newman, J. E. (1956). Use of official weather data in
#' spring time temperature analysis of an Indiana phenological record.
#' *Ecology*, 37(4), 812-823.
#'
#' McMaster, G. S., & Wilhelm, W. W. (1997). Growing degree-days: one equation,
#' two interpretations. *Agricultural and Forest Meteorology*, 87(4), 291-300.
#'
#' Sevacherian, V., Stern, V. M., & Mueller, A. J. (1977). Heat accumulation
#' for timing Lygus control measures in a safflower-cotton complex.
#' *Journal of Economic Entomology*, 70(4), 399-402.
#'
#' Zalom, F. G., Goodell, P. B., Wilson, L. T., Barnett, W. W., & Bentley,
#' W. J. (1983). *Degree-days: the calculation and use of heat units in pest
#' management*. University of California DANR Leaflet 21373.
#'
#' @seealso [degree_hours()] for hourly temperatures.
#' @examples
#' tmin <- c(4, 8, 12, 15)
#' tmax <- c(16, 22, 28, 34)
#' degree_days(tmin, tmax, method = "average", base = 10)
#' degree_days(tmin, tmax, method = "single_sine", base = 10)
#' degree_days(tmin, tmax, method = "single_sine", base = 10, upper = 30,
#'             cutoff = "vertical")
#' degree_days(tmin, tmax, method = "double_sine", base = 10,
#'             tmin_next = c(tmin[-1], 10))
#' @export
degree_days <- function(tmin, tmax,
                        method = c("single_sine", "average", "single_triangle",
                                   "double_sine", "double_triangle"),
                        base = 10, upper = NULL,
                        cutoff = c("horizontal", "vertical", "intermediate"),
                        tmin_next = NULL) {
  method <- match.arg(method)
  cutoff <- match.arg(cutoff)
  check_tmin_tmax(tmin, tmax)
  check_thresholds(base, upper)

  if (method == "average") {
    return(average_degree_days(tmin, tmax, base, upper, cutoff))
  }
  shape <- if (grepl("sine", method)) "sine" else "triangle"
  if (startsWith(method, "single")) {
    return(profile_degree_days(tmin, tmax, base, upper, cutoff, shape))
  }

  if (is.null(tmin_next)) {
    tmin_next <- c(tmin[-1L], NA_real_)
  } else {
    check_numeric(tmin_next, "tmin_next")
    if (length(tmin_next) != length(tmin)) {
      stop("`tmin_next` must have the same length as `tmin`.", call. = FALSE)
    }
  }
  first_half <- profile_degree_days(tmin, tmax, base, upper, cutoff, shape)
  second_half <- profile_degree_days(pmin(tmin_next, tmax),
                                     pmax(tmin_next, tmax),
                                     base, upper, cutoff, shape)
  (first_half + second_half) / 2
}

average_degree_days <- function(tmin, tmax, base, upper, cutoff) {
  tavg <- (tmin + tmax) / 2
  if (is.null(upper)) return(pmax(0, tavg - base))
  switch(cutoff,
    horizontal = pmax(0, pmin(tavg, upper) - base),
    vertical = ifelse(tavg > upper, 0, pmax(0, tavg - base)),
    intermediate = ifelse(tavg > upper,
                          pmax(0, (upper - base) - (tavg - upper)),
                          pmax(0, tavg - base))
  )
}

#' Degree-hours from hourly temperatures
#'
#' Computes the thermal contribution of each hourly observation above a base
#' temperature, optionally bounded by an upper threshold with the same cutoff
#' conventions as [degree_days()].
#'
#' The result is in degree Celsius hour. Divide daily sums by 24 to express
#' them as degree-days: \eqn{GDD_d = \sum_{h=1}^{24} DH_h / 24}. The function
#' assumes regular one-hour time steps; it does not check timestamps.
#'
#' @param temperature Numeric vector (or matrix, one row per series) of hourly
#'   temperatures in degrees Celsius.
#' @inheritParams degree_days
#' @param by_day If `TRUE`, the hourly series is summed in consecutive blocks
#'   of 24 values and divided by 24, returning degree-days per day. The series
#'   length must then be a multiple of 24.
#'
#' @return Degree-hours (degree Celsius hour) with the shape of `temperature`,
#'   or degree-days per day (degree Celsius day) when `by_day = TRUE`.
#' @examples
#' temp <- 12 + 8 * sin(2 * pi * (0:23 - 9) / 24)
#' degree_hours(temp, base = 10)
#' degree_hours(temp, base = 10, by_day = TRUE)
#' @export
degree_hours <- function(temperature, base = 10, upper = NULL,
                         cutoff = c("horizontal", "vertical", "intermediate"),
                         by_day = FALSE) {
  cutoff <- match.arg(cutoff)
  check_numeric(temperature, "temperature")
  check_thresholds(base, upper)
  dh <- if (is.null(upper)) {
    pmax(0, temperature - base)
  } else {
    switch(cutoff,
      horizontal = pmax(0, pmin(temperature, upper) - base),
      vertical = ifelse(temperature > upper, 0, pmax(0, temperature - base)),
      intermediate = ifelse(temperature > upper,
                            pmax(0, (upper - base) - (temperature - upper)),
                            pmax(0, temperature - base))
    )
  }
  dim(dh) <- dim(temperature)
  if (!by_day) return(dh)
  hours_to_days(dh, fun = "sum") / 24
}

# Sum or average consecutive blocks of 24 hourly values. Works on vectors and
# on matrices (one row per series, one column per hour).
hours_to_days <- function(x, fun = c("sum", "mean")) {
  fun <- match.arg(fun)
  s <- as_series_matrix(x)
  m <- s$m
  if (ncol(m) %% 24L != 0L) {
    stop("Hourly series length must be a multiple of 24.", call. = FALSE)
  }
  n_days <- ncol(m) %/% 24L
  # Column-major storage makes (series, hour, day) a free reshape; summing the
  # 24 hour slices avoids transposing the full hourly matrix.
  arr <- array(m, dim = c(nrow(m), 24L, n_days))
  out <- arr[, 1L, ]
  for (h in 2:24) out <- out + arr[, h, ]
  dim(out) <- c(nrow(m), n_days)
  if (fun == "mean") out <- out / 24
  if (s$was_vector) as.vector(out) else out
}
