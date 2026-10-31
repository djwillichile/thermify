#' Date on which an accumulated index reaches a threshold
#'
#' Accumulates daily (or hourly) index values in time order and returns the
#' first date on which the running total reaches `threshold`. Typical uses are
#' the date when a crop or pest reaches a degree-day requirement, or when a
#' cultivar completes its chill requirement.
#'
#' @param values Numeric vector of index values per time step (not
#'   cumulative), for example the output of [degree_days()].
#' @param dates Vector of `Date` (or `POSIXct`) of the same length, in
#'   increasing order.
#' @param threshold Single number: requirement in the units of `values`.
#' @param na_action `"propagate"` (default): if a missing value occurs before
#'   the threshold is reached, the result is `NA`, because the true date
#'   cannot be known. `"skip"`: missing steps contribute zero (the date may
#'   then be late).
#' @return A single date of the class of `dates` (`NA` if the threshold is not
#'   reached), with attribute `"index"` (position in `dates`).
#' @examples
#' dates <- seq(as.Date("2023-09-01"), by = "day", length.out = 10)
#' gdd <- c(2, 3, 5, 4, 6, 7, 3, 2, 8, 9)
#' threshold_date(gdd, dates, threshold = 20)
#' @export
threshold_date <- function(values, dates, threshold,
                           na_action = c("propagate", "skip")) {
  na_action <- match.arg(na_action)
  check_numeric(values, "values")
  check_scalar(threshold, "threshold")
  if (length(values) != length(dates)) {
    stop("`values` and `dates` must have the same length.", call. = FALSE)
  }
  if (is.unsorted(dates, strictly = TRUE)) {
    stop("`dates` must be strictly increasing.", call. = FALSE)
  }
  if (na_action == "skip") values[is.na(values)] <- 0
  total <- cumsum(values)
  hit <- which(total >= threshold)[1L]
  first_na <- which(is.na(values))[1L]
  idx <- if (is.na(hit) || (!is.na(first_na) && first_na <= hit)) NA_integer_
         else hit
  out <- dates[idx]
  attr(out, "index") <- idx
  out
}
