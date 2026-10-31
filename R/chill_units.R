#' Utah model chill units
#'
#' Accumulates chill units (CU) with the Utah model of Richardson, Seeley &
#' Walker (1974). Each hourly temperature receives a weight that can be
#' positive, zero or negative; the accumulation is the running sum of weights.
#'
#' @section Weights and boundary convention:
#' The original model is stated in tenths of a degree Celsius. For continuous
#' temperatures thermify uses left-open, right-closed intervals
#' \eqn{(a, b]}, the same convention as `chillR::Utah_Model()`:
#'
#' | Temperature (degrees C) | Weight |
#' |---|---|
#' | \eqn{T \le 1.4}         |  0   |
#' | \eqn{1.4 < T \le 2.4}   |  0.5 |
#' | \eqn{2.4 < T \le 9.1}   |  1   |
#' | \eqn{9.1 < T \le 12.4}  |  0.5 |
#' | \eqn{12.4 < T \le 15.9} |  0   |
#' | \eqn{15.9 < T \le 18.0} | -0.5 |
#' | \eqn{T > 18.0}          | -1   |
#'
#' Negative weights are kept and the running sum is **not** truncated at zero.
#' Variants that reset or floor the sum (for example the "positive Utah"
#' model) are different models and are not applied implicitly.
#'
#' @section Input:
#' `temperature` must be an hourly series, observed or reconstructed with
#' [hourly_temperatures()], ordered in time with one value per hour. Applying
#' the weights to monthly or daily means is not meaningful because the weight
#' function is non-linear and non-monotonic.
#'
#' @param temperature Numeric vector, or matrix with one row per series and one
#'   column per hour, of hourly temperatures in degrees Celsius.
#' @param method Currently only `"utah"`.
#' @param output `"cumulative"` (default) running sum, `"hourly"` weights or
#'   `"total"` sum.
#' @param na_action `"propagate"` (default): the running sum becomes `NA`
#'   from the first missing hour; `"skip"`: missing hours contribute zero and
#'   their count is returned in the `"n_missing"` attribute.
#'
#' @return Chill units (dimensionless) with the shape implied by `output`.
#' @references
#' Richardson, E. A., Seeley, S. D., & Walker, D. R. (1974). A model for
#' estimating the completion of rest for 'Redhaven' and 'Elberta' peach trees.
#' *HortScience*, 9(4), 331-332.
#' @seealso [utah_weights()], [chill_portions()].
#' @examples
#' temp <- c(0, 2, 5, 10, 14, 17, 20)
#' utah_weights(temp)
#' chill_units(temp)
#' chill_units(temp, output = "total")
#' @export
chill_units <- function(temperature, method = "utah",
                        output = c("cumulative", "hourly", "total"),
                        na_action = c("propagate", "skip")) {
  method <- match.arg(method, "utah")
  output <- match.arg(output)
  na_action <- match.arg(na_action)
  s <- as_series_matrix(temperature)
  w <- utah_weights(s$m)
  sequential_output(w, s$was_vector, output, na_action)
}

#' Utah model hourly weights
#'
#' Vectorised weight function of the Utah model (see [chill_units()] for the
#' interval convention).
#'
#' @param temperature Numeric vector or matrix of hourly temperatures
#'   (degrees Celsius).
#' @return Weights with the same shape as `temperature`; `NA` where the input
#'   is missing.
#' @export
utah_weights <- function(temperature) {
  check_numeric(temperature, "temperature")
  breaks <- c(-Inf, 1.4, 2.4, 9.1, 12.4, 15.9, 18, Inf)
  weights <- c(0, 0.5, 1, 0.5, 0, -0.5, -1)
  idx <- findInterval(temperature, breaks, left.open = TRUE)
  out <- weights[idx]
  dim(out) <- dim(temperature)
  out
}
