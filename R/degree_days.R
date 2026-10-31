#' Growing degree days using daily minima and maxima
#'
#' @param tmin Daily minimum temperature in degrees Celsius.
#' @param tmax Daily maximum temperature in degrees Celsius.
#' @param base Lower developmental threshold in degrees Celsius.
#' @return Numeric vector of degree-days per day.
#' @export
degree_days <- function(tmin, tmax, base = 10) {
  if (!is.numeric(tmin) || !is.numeric(tmax) || !is.numeric(base) || length(base) != 1L || is.na(base)) {
    stop("tmin, tmax and base must be numeric; base must be one non-missing number")
  }
  if (length(tmin) != length(tmax)) stop("tmin and tmax must have equal lengths")
  if (any(tmin > tmax, na.rm = TRUE)) stop("tmin cannot exceed tmax")
  pmax((tmin + tmax) / 2 - base, 0)
}
