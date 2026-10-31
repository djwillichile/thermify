#' Dynamic model chill portions
#'
#' Accumulates chill portions (CP) with the Dynamic model of Fishman, Erez and
#' Couvillon (1987a, b) as parameterised by Erez et al. (1990).
#'
#' @section Model:
#' Chill accumulates in two steps. A thermally labile intermediate \eqn{x}
#' forms in cool conditions and is destroyed by warm conditions. Once
#' \eqn{x \ge 1}, a temperature-dependent fraction \eqn{\xi} of it is fixed
#' irreversibly as a chill portion. For each hour with temperature
#' \eqn{T_K = T + 273} (K):
#'
#' \deqn{x_s = \frac{A_0}{A_1} e^{(E_1 - E_0)/T_K}, \qquad
#'       k_1 = A_1 e^{-E_1 / T_K}}
#' \deqn{\xi = \frac{s}{1 + s}, \qquad
#'       s = \exp\left(\frac{\mathrm{slope}\, T_f (T_K - T_f)}{T_K}\right)}
#' \deqn{x_h = x_s - (x_s - S_h) e^{-k_1}}
#'
#' where \eqn{S_h} is the intermediate at the start of the hour. If
#' \eqn{x_h \ge 1}, \eqn{\Delta CP_h = \xi_h x_h} and the next hour starts from
#' \eqn{S_{h+1} = x_h (1 - \xi_h)}; otherwise \eqn{\Delta CP_h = 0} and
#' \eqn{S_{h+1} = x_h}. The defaults are the published constants
#' (E0 = 4153.5 K, E1 = 12888.8 K, A0 = 139500, A1 = 2.567e18, slope = 1.6,
#' Tf = 277 K), identical to those of `chillR::Dynamic_Model()`.
#'
#' @section State and blocks:
#' The intermediate is carried from hour to hour and day to day; the model is
#' never reset implicitly (for example at month boundaries). The state after
#' the last hour is returned in the `"state"` attribute. Passing it as `state`
#' to a subsequent call continues the accumulation, so processing a season in
#' blocks gives the same result as processing it at once. Define the
#' accumulation period by subsetting `temperature` (see [season_days()]).
#'
#' @section Indexing relative to chillR:
#' thermify assigns the portion produced during hour \eqn{h} to hour \eqn{h}.
#' `chillR::Dynamic_Model()` reports the same quantity one position later
#' (its first element is always zero and the contribution of the final hour
#' is not included), so `chillR` cumulative output at position \eqn{h + 1}
#' equals thermify cumulative output at position \eqn{h}.
#'
#' @section Missing values:
#' With `na_action = "propagate"` (default) the state becomes `NA` from the
#' first missing hour onwards, because the intermediate cannot be updated
#' without temperature. `na_action = "hold"` keeps the intermediate unchanged
#' and adds no portion during missing hours; this is a pragmatic gap-bridging
#' assumption that should be reported, and the number of held hours is
#' returned in the `"n_missing"` attribute. Gaps longer than a few hours
#' should be filled with a defensible method before using the model.
#'
#' @param temperature Numeric vector, or matrix with one row per series and one
#'   column per hour, of hourly temperatures (degrees Celsius) ordered in time.
#' @param method Currently only `"dynamic"`.
#' @param output `"cumulative"` (default), `"hourly"` increments or
#'   `"total"`.
#' @param state Optional state returned by a previous call (attribute
#'   `"state"`), to continue the accumulation. `NULL` starts from zero.
#' @param na_action `"propagate"` or `"hold"` (see Missing values).
#' @param e0,e1,a0,a1,slope,tf Model constants.
#'
#' @return Chill portions with the shape implied by `output`, with attribute
#'   `"state"`: a list with elements `inter` (intermediate at the start of the
#'   next hour) and `portions` (accumulated portions), one value per series.
#' @references
#' Fishman, S., Erez, A., & Couvillon, G. A. (1987a). The temperature
#' dependence of dormancy breaking in plants: computer simulation of
#' processes studied under controlled temperatures. *Journal of Theoretical
#' Biology*, 126(3), 309-321.
#'
#' Fishman, S., Erez, A., & Couvillon, G. A. (1987b). The temperature
#' dependence of dormancy breaking in plants: mathematical analysis of a
#' two-step model involving a cooperative transition. *Journal of
#' Theoretical Biology*, 124(4), 473-483.
#'
#' Erez, A., Fishman, S., Linsley-Noakes, G. C., & Allan, P. (1990). The
#' dynamic model for rest completion in peach buds. *Acta Horticulturae*,
#' 276, 165-174.
#'
#' Luedeling, E., Zhang, M., & Girvetz, E. H. (2009). Climatic changes lead to
#' declining winter chill for fruit and nut trees in California during
#' 1950-2099. *PLoS ONE*, 4(7), e6166.
#' @seealso [chill_units()], [hourly_temperatures()].
#' @examples
#' temp <- rep(c(2, 4, 6, 8, 10, 12, 10, 8, 6, 4), length.out = 24 * 30)
#' cp <- chill_portions(temp)
#' tail(cp, 1)
#'
#' # Block processing gives the same answer
#' a <- chill_portions(temp[1:300])
#' b <- chill_portions(temp[301:720], state = attr(a, "state"))
#' all.equal(tail(as.vector(b), 1), tail(as.vector(cp), 1))
#' @export
chill_portions <- function(temperature, method = "dynamic",
                           output = c("cumulative", "hourly", "total"),
                           state = NULL,
                           na_action = c("propagate", "hold"),
                           e0 = 4153.5, e1 = 12888.8, a0 = 139500,
                           a1 = 2.567e18, slope = 1.6, tf = 277) {
  method <- match.arg(method, "dynamic")
  output <- match.arg(output)
  na_action <- match.arg(na_action)
  s <- as_series_matrix(temperature)
  m <- s$m
  n_series <- nrow(m)

  inter <- rep(0, n_series)
  portions <- rep(0, n_series)
  if (!is.null(state)) {
    if (!is.list(state) || !all(c("inter", "portions") %in% names(state)) ||
        length(state$inter) != n_series) {
      stop("`state` must be the \"state\" attribute of a previous call ",
           "with the same number of series.", call. = FALSE)
    }
    inter <- state$inter
    portions <- state$portions
  }

  tk <- m + 273
  xi <- 1 / (1 + exp(-slope * tf * (tk - tf) / tk))
  xs <- (a0 / a1) * exp((e1 - e0) / tk)
  decay <- exp(-a1 * exp(-e1 / tk))

  keep_hourly <- output != "total"
  delta <- if (keep_hourly) matrix(0, n_series, ncol(m)) else NULL
  n_missing <- rowSums(is.na(m))

  for (h in seq_len(ncol(m))) {
    x <- xs[, h] - (xs[, h] - inter) * decay[, h]
    gain <- ifelse(x >= 1, x * xi[, h], 0)
    next_inter <- ifelse(x >= 1, x * (1 - xi[, h]), x)
    if (na_action == "hold") {
      miss <- is.na(m[, h])
      gain[miss] <- 0
      next_inter[miss] <- inter[miss]
    }
    inter <- next_inter
    portions <- portions + gain
    if (keep_hourly) delta[, h] <- gain
  }

  out <- switch(output,
    hourly = delta,
    cumulative = row_cumsum(delta) +
      (if (is.null(state)) 0 else state$portions),
    total = portions
  )
  if (s$was_vector && is.matrix(out)) out <- as.vector(out)
  attr(out, "state") <- list(inter = inter, portions = portions)
  if (na_action == "hold") attr(out, "n_missing") <- n_missing
  out
}
