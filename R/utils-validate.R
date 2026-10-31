# Internal validation helpers. All user-facing functions route their input
# checks through these so that error messages are consistent.

check_numeric <- function(x, name, allow_na = TRUE) {
  if (!is.numeric(x)) {
    stop(sprintf("`%s` must be numeric.", name), call. = FALSE)
  }
  if (!allow_na && anyNA(x)) {
    stop(sprintf("`%s` must not contain missing values.", name), call. = FALSE)
  }
  invisible(x)
}

check_scalar <- function(x, name, null_ok = FALSE) {
  if (is.null(x) && null_ok) return(invisible(x))
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    stop(sprintf("`%s` must be a single finite number.", name), call. = FALSE)
  }
  invisible(x)
}

check_tmin_tmax <- function(tmin, tmax) {
  check_numeric(tmin, "tmin")
  check_numeric(tmax, "tmax")
  if (length(tmin) != length(tmax)) {
    stop("`tmin` and `tmax` must have the same length.", call. = FALSE)
  }
  bad <- which(tmin > tmax)
  if (length(bad) > 0L) {
    stop(sprintf(
      "`tmin` exceeds `tmax` in %d element(s) (first at position %d). %s",
      length(bad), bad[1L],
      "thermify never swaps or corrects inconsistent extremes silently."
    ), call. = FALSE)
  }
  invisible(TRUE)
}

check_thresholds <- function(lower, upper, lower_name = "base",
                             upper_name = "upper") {
  check_scalar(lower, lower_name)
  check_scalar(upper, upper_name, null_ok = TRUE)
  if (!is.null(upper) && upper <= lower) {
    stop(sprintf("`%s` must be greater than `%s`.", upper_name, lower_name),
         call. = FALSE)
  }
  invisible(TRUE)
}

# Coerce hourly input to a matrix with one row per series and one column per
# hour. Vectors become a one-row matrix; `was_vector` lets callers restore the
# input shape on output.
as_series_matrix <- function(x, name = "temperature") {
  check_numeric(x, name)
  if (is.matrix(x)) {
    return(list(m = x, was_vector = FALSE))
  }
  list(m = matrix(x, nrow = 1L), was_vector = TRUE)
}

match_output <- function(output) {
  match.arg(output, c("cumulative", "hourly", "total"))
}
