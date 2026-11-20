#' Ensemble weights for growing degree-day methods
#'
#' `r lifecycle::badge("experimental")`
#'
#' Estimates the weights of a growing degree-day ensemble from validation
#' results, that is, from estimates of each method compared with values
#' computed from **observed** hourly temperature (see [validate_station()]).
#' The weights are then used by [degree_days()] with `method = "ensemble"`,
#' by [gdd_ensemble()] and by [thermify()] and [thermify_rast()] through
#' `gdd_weights`.
#'
#' thermify does not ship default weights: they depend on the climate, the
#' base temperature and the data available (daily extremes or monthly
#' climatologies), so they must be estimated from stations that represent the
#' area of use.
#'
#' The ensemble is experimental: its interface may change once it has been
#' assessed with observed station networks.
#'
#' @section Schemes:
#' * `"stacking"` (default) chooses non-negative weights that sum to one and
#'   minimise the squared error of the weighted estimate (Breiman 1996; Yao et
#'   al. 2018). The member methods have no fitted parameters, so their
#'   estimates are already out-of-sample predictions and can be stacked
#'   directly. Stacking is robust when no method is "true" and when members
#'   are nearly identical: their weight is shared but the prediction does not
#'   change.
#' * `"bma"` is Bayesian model averaging with Gaussian errors and a common
#'   standard deviation, fitted by expectation-maximisation (Raftery et al.
#'   2005). Each weight is the posterior probability that a method is the
#'   best description of the observations, so weights follow each method's
#'   likelihood. Without bias correction BMA tends to concentrate the weight
#'   on the least biased method, and nearly identical methods split it.
#' * `"akaike"` uses Akaike weights (Burnham & Anderson 2002):
#'   \eqn{w_k \propto \exp(-\Delta_k / 2)}, where \eqn{\Delta_k} is the
#'   difference between the AIC of method \eqn{k} and the smallest AIC. The
#'   AIC of each method uses Gaussian errors with its own maximum-likelihood
#'   variance, \eqn{AIC_k = n \log(2\pi\hat\sigma_k^2) + n + 2p}, with
#'   \eqn{p = 1} (the variance): the member methods have no fitted
#'   parameters, so the penalty is the same for all and the weights reduce to
#'   relative likelihoods, \eqn{w_k \propto \hat\sigma_k^{-n}}. With many
#'   cases they concentrate almost all the weight on the method with the
#'   smallest mean squared error, so they select rather than combine. The AIC
#'   table is returned in `aic`.
#'
#' @section Assessment:
#' When the cases come from more than one station (or, with a single station,
#' from more than one season), the ensemble is assessed by leave-one-group-out
#' cross-validation: the weights are re-estimated without each group and used
#' to predict it. Compare `cv` with the metrics of the best single method
#' before using the ensemble: when the members share the same systematic
#' error, weighting cannot remove it.
#'
#' @param x Validation results: an object from [validate_station()], a list
#'   of such objects (one per station; names are used as station labels), or
#'   a data frame with columns `method`, `estimate` and `observed`, and
#'   optionally `station`, `season`, `index` and `level`.
#' @param level Level of the estimates to combine: `"daily"`, `"monthly"` or
#'   `"gridded"` (see [validate_station()]). Weights for daily extremes are
#'   not valid for monthly climatologies and vice versa.
#' @param methods Member methods. `NULL` (default) uses every daily
#'   [degree_days()] method present at `level`; estimates from hourly
#'   reconstructions (`"hourly_linvill"`, `"hourly_sine"`) are not members
#'   because they cannot be computed by [degree_days()].
#' @param scheme `"stacking"`, `"bma"` or `"akaike"`.
#' @param cv Assess the ensemble by leave-one-group-out cross-validation?
#' @param tol,max_iter Convergence tolerance and maximum number of
#'   iterations of the solvers.
#' @return An object of class `"gdd_ensemble_weights"`: a list with
#'   `weights` (named, non-negative, summing to one), `scheme`, `level`,
#'   `base`, `upper` and `cutoff` (when known), `sigma` (BMA error standard
#'   deviation, degrees C day), `n_cases`, `n_groups`, `fit` (metrics of the
#'   ensemble and of each member on the estimation cases), `cv`
#'   (cross-validated metrics of the ensemble, or `NULL`) and, for
#'   `scheme = "akaike"`, `aic` (AIC, \eqn{\Delta} and weight per method).
#' @references
#' Burnham, K. P., & Anderson, D. R. (2002). *Model Selection and
#' Multimodel Inference: A Practical Information-Theoretic Approach* (2nd
#' ed.). Springer. \doi{10.1007/b97636}
#'
#' Breiman, L. (1996). Stacked regressions. *Machine Learning*, 24, 49-64.
#' \doi{10.1007/BF00117832}
#'
#' Raftery, A. E., Gneiting, T., Balabdaoui, F., & Polakowski, M. (2005).
#' Using Bayesian model averaging to calibrate forecast ensembles. *Monthly
#' Weather Review*, 133(5), 1155-1174. \doi{10.1175/MWR2906.1}
#'
#' Yao, Y., Vehtari, A., Simpson, D., & Gelman, A. (2018). Using stacking to
#' average Bayesian predictive distributions. *Bayesian Analysis*, 13(3),
#' 917-1007. \doi{10.1214/17-BA1091}
#' @seealso [gdd_ensemble()], [validate_station()]
#' @examples
#' # Illustration with made-up validation results (not real data): the
#' # observed totals lie between the averaging and the sine estimates.
#' val <- data.frame(
#'   station = rep(c("A", "B", "C"), each = 6),
#'   season = rep(rep(c(2020, 2021), each = 3), 3),
#'   method = rep(c("average", "single_sine", "single_triangle"), 6),
#'   estimate = c(950, 1010, 990, 1200, 1270, 1240, 870, 935, 910,
#'                1020, 1080, 1060, 1110, 1180, 1150, 990, 1050, 1030),
#'   observed = rep(c(985, 1245, 905, 1055, 1150, 1025), each = 3))
#' w <- gdd_ensemble_weights(val)
#' w
#' degree_days(c(5, 8), c(22, 25), method = "ensemble", weights = w,
#'             base = 10)
#' @export
gdd_ensemble_weights <- function(x, level = "daily", methods = NULL,
                                 scheme = c("stacking", "bma", "akaike"),
                                 cv = TRUE,
                                 tol = 1e-10, max_iter = 10000L) {
  scheme <- match.arg(scheme)
  data <- ensemble_cases(x, level)
  available <- unique(data$long$method)
  daily_methods <- c("average", "modified_average", "single_sine",
                     "single_triangle", "double_sine", "double_triangle")
  if (is.null(methods)) methods <- intersect(available, daily_methods)
  not_daily <- setdiff(methods, c(daily_methods, "ensemble"))
  if (length(not_daily)) {
    stop("Ensemble members must be daily degree_days() methods; not ",
         "allowed: ", paste(not_daily, collapse = ", "), ".", call. = FALSE)
  }
  unknown <- setdiff(methods, available)
  if (length(unknown)) {
    stop("Method(s) not found at level \"", level, "\": ",
         paste(unknown, collapse = ", "), ".", call. = FALSE)
  }
  if ("ensemble" %in% methods) {
    stop("An ensemble cannot be a member of itself.", call. = FALSE)
  }
  if (length(methods) < 2L) {
    stop("An ensemble needs at least two methods.", call. = FALSE)
  }
  wide <- ensemble_matrix(data$long, methods)
  if (nrow(wide$X) < 2L) {
    stop("At least two complete cases (station-seasons with every method) ",
         "are needed.", call. = FALSE)
  }
  fit_w <- function(X, y) {
    switch(scheme,
      stacking = stack_weights(X, y, tol, max_iter),
      bma = bma_weights(X, y, tol, max_iter),
      akaike = akaike_weights(X, y))
  }
  est <- fit_w(wide$X, wide$y)
  weights <- stats::setNames(est$weights, methods)

  members <- lapply(methods, function(m) {
    cbind(method = m, validation_metrics(wide$X[, m], wide$y))
  })
  ens_pred <- as.vector(wide$X %*% weights)
  fit <- rbind(cbind(method = "ensemble",
                     validation_metrics(ens_pred, wide$y)),
               do.call(rbind, members))

  groups <- wide$group
  cv_out <- NULL
  if (isTRUE(cv) && length(unique(groups)) >= 2L) {
    pred <- rep(NA_real_, length(wide$y))
    for (g in unique(groups)) {
      out <- groups == g
      if (sum(!out) < 2L) next
      w_g <- fit_w(wide$X[!out, , drop = FALSE], wide$y[!out])$weights
      pred[out] <- wide$X[out, , drop = FALSE] %*% w_g
    }
    cv_out <- cbind(method = "ensemble", validation_metrics(pred, wide$y))
  }

  structure(list(
    weights = weights, scheme = scheme, level = level,
    base = data$config$base, upper = data$config$upper,
    cutoff = data$config$cutoff, sigma = est$sigma,
    n_cases = nrow(wide$X), n_groups = length(unique(groups)),
    group_by = wide$group_by, fit = fit, cv = cv_out,
    aic = if (scheme == "akaike") cbind(method = methods, est$aic,
                                        row.names = NULL) else NULL),
    class = "gdd_ensemble_weights")
}

#' @export
print.gdd_ensemble_weights <- function(x, ...) {
  cat("GDD ensemble weights (", x$scheme, ", level \"", x$level, "\")\n",
      sep = "")
  if (!is.null(x$base)) {
    cat("Base", format(x$base), "degC",
        if (!is.null(x$upper)) paste0(", upper ", format(x$upper), " degC")
        else "", "\n")
  }
  cat(x$n_cases, "cases in", x$n_groups, x$group_by, "group(s)\n\n")
  w <- x$weights[order(-x$weights)]
  print(round(w, 3))
  f <- x$fit[, c("method", "n", "bias", "mae", "rmse")]
  cat("\nFit on the estimation cases:\n")
  print(f, row.names = FALSE, digits = 4)
  if (!is.null(x$aic)) {
    cat("\nAkaike weights:\n")
    print(x$aic, row.names = FALSE, digits = 4)
  }
  if (!is.null(x$cv)) {
    cat("\nCross-validated ensemble (leave one ", x$group_by, " out):\n",
        sep = "")
    print(x$cv[, c("method", "n", "bias", "mae", "rmse")], row.names = FALSE,
          digits = 4)
  }
  invisible(x)
}

#' Growing degree-days from an ensemble of methods
#'
#' `r lifecycle::badge("experimental")`
#'
#' Computes the daily degree-days of each member method and their weighted
#' mean, with the spread between members as a measure of method
#' uncertainty. [degree_days()] with `method = "ensemble"` returns only the
#' weighted mean.
#'
#' @inheritParams degree_days
#' @param weights Ensemble weights: an object from [gdd_ensemble_weights()]
#'   or a named numeric vector of non-negative weights (names are
#'   [degree_days()] methods). Weights are rescaled to sum to one.
#' @return A data frame with one row per day and columns `ensemble`
#'   (weighted mean), `sd` (weighted standard deviation between members),
#'   `min` and `max` (range of the members with non-zero weight) and one
#'   column per member method.
#' @seealso [gdd_ensemble_weights()]
#' @examples
#' w <- c(average = 0.3, single_triangle = 0.7)  # illustrative weights
#' gdd_ensemble(c(5, 8, 12), c(22, 25, 30), weights = w, base = 10)
#' @export
gdd_ensemble <- function(tmin, tmax, weights, base = 10, upper = NULL,
                         cutoff = c("horizontal", "vertical", "intermediate"),
                         tmin_next = NULL) {
  cutoff <- match.arg(cutoff)
  w <- check_ensemble_weights(weights, base, upper, cutoff)
  members <- vapply(names(w), function(m) {
    degree_days(tmin, tmax, method = m, base = base, upper = upper,
                cutoff = cutoff, tmin_next = tmin_next)
  }, numeric(length(tmin)))
  members <- matrix(members, nrow = length(tmin),
                    dimnames = list(NULL, names(w)))
  mean_w <- as.vector(members %*% w)
  sd_w <- sqrt(pmax(0, as.vector(((members - mean_w)^2) %*% w)))
  used <- members[, w > 0, drop = FALSE]
  data.frame(ensemble = mean_w, sd = sd_w,
             min = apply(used, 1, min), max = apply(used, 1, max),
             members, check.names = FALSE)
}

# Validate weights and return a named vector that sums to one. Weights
# estimated by gdd_ensemble_weights() must match the thresholds used.
check_ensemble_weights <- function(weights, base, upper, cutoff) {
  if (is.null(weights)) {
    stop("`method = \"ensemble\"` needs `weights`, estimated with ",
         "gdd_ensemble_weights() from observed data. thermify has no ",
         "default weights.", call. = FALSE)
  }
  if (inherits(weights, "gdd_ensemble_weights")) {
    same <- function(a, b) (is.null(a) && is.null(b)) ||
      (!is.null(a) && !is.null(b) && isTRUE(all.equal(a, b)))
    if (!is.null(weights$base) && !same(weights$base, base)) {
      stop("These weights were estimated for base ", format(weights$base),
           " degC; use base = ", format(weights$base), ".", call. = FALSE)
    }
    if (!is.null(weights$base) && !same(weights$upper, upper)) {
      stop("These weights were estimated with upper = ",
           if (is.null(weights$upper)) "NULL" else format(weights$upper),
           "; use the same upper threshold.", call. = FALSE)
    }
    if (!is.null(weights$cutoff) && !is.null(upper) &&
        weights$cutoff != cutoff) {
      stop("These weights were estimated with cutoff = \"", weights$cutoff,
           "\".", call. = FALSE)
    }
    weights <- weights$weights
  }
  if (!is.numeric(weights) || is.null(names(weights)) ||
      any(!nzchar(names(weights)))) {
    stop("`weights` must be a named numeric vector or an object from ",
         "gdd_ensemble_weights().", call. = FALSE)
  }
  if (anyNA(weights) || any(weights < 0) || sum(weights) <= 0) {
    stop("`weights` must be non-negative and not all zero.", call. = FALSE)
  }
  valid <- c("average", "modified_average", "single_sine", "single_triangle",
             "double_sine", "double_triangle")
  bad <- setdiff(names(weights), valid)
  if (length(bad)) {
    stop("Unknown ensemble member(s): ", paste(bad, collapse = ", "),
         ". Members must be daily degree_days() methods.", call. = FALSE)
  }
  if (anyDuplicated(names(weights))) {
    stop("Duplicated ensemble members.", call. = FALSE)
  }
  weights / sum(weights)
}

# Collect GDD validation cases as a long data frame with a grouping column.
ensemble_cases <- function(x, level) {
  config <- list(base = NULL, upper = NULL, cutoff = NULL)
  if (inherits(x, "thermify_validation")) x <- list(x)
  if (is.list(x) && !is.data.frame(x)) {
    if (!length(x) ||
        !all(vapply(x, inherits, TRUE, "thermify_validation"))) {
      stop("`x` must be validate_station() results or a data frame.",
           call. = FALSE)
    }
    bases <- unique(vapply(x, function(v) v$config$base, 0))
    if (length(bases) != 1L) {
      stop("All stations must be validated with the same base.",
           call. = FALSE)
    }
    config <- x[[1]]$config[c("base", "upper", "cutoff")]
    labels <- names(x)
    if (is.null(labels) || any(!nzchar(labels))) {
      labels <- paste0("station", seq_along(x))
    }
    long <- do.call(rbind, lapply(seq_along(x), function(i) {
      s <- x[[i]]$seasons
      if (!nrow(s)) return(NULL)
      s$station <- labels[i]
      s
    }))
    if (is.null(long)) stop("The validation results have no seasons.",
                            call. = FALSE)
  } else if (is.data.frame(x)) {
    long <- x
    need <- c("method", "estimate", "observed")
    miss <- setdiff(need, names(long))
    if (length(miss)) {
      stop("`x` lacks column(s): ", paste(miss, collapse = ", "), ".",
           call. = FALSE)
    }
  } else {
    stop("`x` must be validate_station() results or a data frame.",
         call. = FALSE)
  }
  if ("index" %in% names(long)) long <- long[long$index == "gdd", ]
  if ("level" %in% names(long)) long <- long[long$level == level, ]
  long <- long[!is.na(long$estimate) & !is.na(long$observed), ]
  if (!nrow(long)) {
    stop("No GDD cases at level \"", level, "\".", call. = FALSE)
  }
  list(long = long, config = config)
}

# Cases x methods matrix; a case is a station-season (or a row index when
# neither is given). Incomplete cases are dropped.
ensemble_matrix <- function(long, methods) {
  long <- long[long$method %in% methods, ]
  has_station <- "station" %in% names(long)
  has_season <- "season" %in% names(long)
  if (!has_station && !has_season) {
    long$case <- stats::ave(seq_len(nrow(long)), long$method,
                            FUN = seq_along)
  } else {
    long$case <- paste(if (has_station) long$station else "",
                       if (has_season) long$season else "", sep = "|")
  }
  if (anyDuplicated(long[c("case", "method")])) {
    stop("Several estimates per case and method: add a `season` (and ",
         "`station`) column identifying each case.", call. = FALSE)
  }
  cases <- unique(long$case)
  X <- matrix(NA_real_, length(cases), length(methods),
              dimnames = list(cases, methods))
  X[cbind(match(long$case, cases), match(long$method, methods))] <-
    long$estimate
  y <- tapply(long$observed, long$case, function(v) v[1])[cases]
  ok <- stats::complete.cases(X)
  first <- function(col) tapply(long[[col]], long$case, function(v) v[1])
  group_by <- if (has_station && length(unique(long$station)) > 1L) {
    "station"
  } else if (has_season) "season" else "case"
  group <- switch(group_by,
    station = first("station")[cases],
    season = first("season")[cases],
    case = cases)
  list(X = X[ok, , drop = FALSE], y = as.vector(y[ok]),
       group = as.vector(group[ok]), group_by = group_by)
}

# Euclidean projection onto the probability simplex (Duchi et al. 2008).
project_simplex <- function(v) {
  u <- sort(v, decreasing = TRUE)
  css <- cumsum(u)
  k <- max(which(u - (css - 1) / seq_along(u) > 0))
  pmax(v - (css[k] - 1) / k, 0)
}

# Least squares on the probability simplex. With few members (the usual
# case) the problem is solved exactly by checking every support set: for a
# support S the equality-constrained solution follows from the KKT system,
# and the best feasible (non-negative) one is kept. Larger problems fall
# back to accelerated projected gradient (FISTA).
stack_weights <- function(X, y, tol, max_iter) {
  scale <- max(abs(y), 1)
  X <- X / scale; y <- y / scale
  k <- ncol(X)
  if (k <= 10L) {
    best <- NULL; best_rss <- Inf
    for (size in seq_len(k)) {
      for (S in utils::combn(k, size, simplify = FALSE)) {
        w_s <- simplex_ls(X[, S, drop = FALSE], y)
        if (is.null(w_s) || any(w_s < -1e-10)) next
        w <- numeric(k); w[S] <- pmax(w_s, 0); w <- w / sum(w)
        rss <- sum((y - X %*% w)^2)
        if (rss < best_rss * (1 - 1e-12)) {
          best <- w; best_rss <- rss
        }
      }
    }
    return(list(weights = best, sigma = NA_real_))
  }
  A <- crossprod(X); b <- crossprod(X, y)
  L <- max(eigen(A, symmetric = TRUE, only.values = TRUE)$values)
  w <- rep(1 / k, k); z <- w; t <- 1
  if (L <= 0) return(list(weights = w, sigma = NA_real_))
  for (i in seq_len(max_iter)) {
    w_new <- project_simplex(as.vector(z - (A %*% z - b) / L))
    t_new <- (1 + sqrt(1 + 4 * t^2)) / 2
    z <- w_new + ((t - 1) / t_new) * (w_new - w)
    if (max(abs(w_new - w)) < tol) { w <- w_new; break }
    w <- w_new; t <- t_new
  }
  w[w < 1e-12] <- 0
  list(weights = w / sum(w), sigma = NA_real_)
}

# Minimise ||y - X w||^2 subject to sum(w) = 1 (no sign constraint).
# Returns NULL when the system is singular.
simplex_ls <- function(X, y) {
  k <- ncol(X)
  if (k == 1L) return(1)
  K <- rbind(cbind(2 * crossprod(X), 1), c(rep(1, k), 0))
  rhs <- c(2 * crossprod(X, y), 1)
  sol <- tryCatch(solve(K, rhs), error = function(e) NULL)
  if (is.null(sol) || anyNA(sol)) return(NULL)
  sol[seq_len(k)]
}

# Bayesian model averaging with Gaussian kernels and a common sd, by EM.
bma_weights <- function(X, y, tol, max_iter) {
  k <- ncol(X)
  w <- rep(1 / k, k)
  sigma <- max(stats::sd(as.vector(X - y)), 1e-6)
  loglik_old <- -Inf
  for (i in seq_len(max_iter)) {
    dens <- vapply(seq_len(k), function(j) {
      stats::dnorm(y, X[, j], sigma, log = TRUE)
    }, numeric(length(y)))
    dens <- matrix(dens, nrow = length(y))
    lw <- sweep(dens, 2, log(pmax(w, 1e-300)), "+")
    m <- apply(lw, 1, max)
    lse <- m + log(rowSums(exp(lw - m)))
    z <- exp(lw - lse)
    loglik <- sum(lse)
    w <- colMeans(z)
    sigma <- sqrt(max(sum(z * (X - y)^2) / length(y), 1e-12))
    if (abs(loglik - loglik_old) < tol * (1 + abs(loglik))) break
    loglik_old <- loglik
  }
  w[w < 1e-12] <- 0
  list(weights = w / sum(w), sigma = sigma)
}

# Akaike weights from Gaussian likelihoods with a per-method ML variance.
akaike_weights <- function(X, y) {
  n <- length(y)
  mse <- colMeans((X - y)^2)
  mse <- pmax(mse, 1e-12 * max(1, mean(y^2)))
  aic <- n * log(2 * pi * mse) + n + 2
  delta <- aic - min(aic)
  w <- exp(-delta / 2)
  w <- w / sum(w)
  list(weights = w, sigma = NA_real_,
       aic = data.frame(aic = aic, delta = delta, weight = w))
}
