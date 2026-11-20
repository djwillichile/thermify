# Ensemble weights for growing degree-day methods

**\[experimental\]**

## Usage

``` r
gdd_ensemble_weights(
  x,
  level = "daily",
  methods = NULL,
  scheme = c("stacking", "bma", "akaike"),
  cv = TRUE,
  tol = 1e-10,
  max_iter = 10000L
)
```

## Arguments

- x:

  Validation results: an object from
  [`validate_station()`](https://djwillichile.github.io/thermify/reference/validate_station.md),
  a list of such objects (one per station; names are used as station
  labels), or a data frame with columns `method`, `estimate` and
  `observed`, and optionally `station`, `season`, `index` and `level`.

- level:

  Level of the estimates to combine: `"daily"`, `"monthly"` or
  `"gridded"` (see
  [`validate_station()`](https://djwillichile.github.io/thermify/reference/validate_station.md)).
  Weights for daily extremes are not valid for monthly climatologies and
  vice versa.

- methods:

  Member methods. `NULL` (default) uses every daily
  [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)
  method present at `level`; estimates from hourly reconstructions
  (`"hourly_linvill"`, `"hourly_sine"`) are not members because they
  cannot be computed by
  [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md).

- scheme:

  `"stacking"`, `"bma"` or `"akaike"`.

- cv:

  Assess the ensemble by leave-one-group-out cross-validation?

- tol, max_iter:

  Convergence tolerance and maximum number of iterations of the solvers.

## Value

An object of class `"gdd_ensemble_weights"`: a list with `weights`
(named, non-negative, summing to one), `scheme`, `level`, `base`,
`upper` and `cutoff` (when known), `sigma` (BMA error standard
deviation, degrees C day), `n_cases`, `n_groups`, `fit` (metrics of the
ensemble and of each member on the estimation cases), `cv`
(cross-validated metrics of the ensemble, or `NULL`) and, for
`scheme = "akaike"`, `aic` (AIC, \\\Delta\\ and weight per method).

## Details

Estimates the weights of a growing degree-day ensemble from validation
results, that is, from estimates of each method compared with values
computed from **observed** hourly temperature (see
[`validate_station()`](https://djwillichile.github.io/thermify/reference/validate_station.md)).
The weights are then used by
[`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)
with `method = "ensemble"`, by
[`gdd_ensemble()`](https://djwillichile.github.io/thermify/reference/gdd_ensemble.md)
and by
[`thermify()`](https://djwillichile.github.io/thermify/reference/thermify.md)
and
[`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)
through `gdd_weights`.

thermify does not ship default weights: they depend on the climate, the
base temperature and the data available (daily extremes or monthly
climatologies), so they must be estimated from stations that represent
the area of use.

The ensemble is experimental: its interface may change once it has been
assessed with observed station networks.

## Schemes

- `"stacking"` (default) chooses non-negative weights that sum to one
  and minimise the squared error of the weighted estimate (Breiman 1996;
  Yao et al. 2018). The member methods have no fitted parameters, so
  their estimates are already out-of-sample predictions and can be
  stacked directly. Stacking is robust when no method is "true" and when
  members are nearly identical: their weight is shared but the
  prediction does not change.

- `"bma"` is Bayesian model averaging with Gaussian errors and a common
  standard deviation, fitted by expectation-maximisation (Raftery et al.
  2005). Each weight is the posterior probability that a method is the
  best description of the observations, so weights follow each method's
  likelihood. Without bias correction BMA tends to concentrate the
  weight on the least biased method, and nearly identical methods split
  it.

- `"akaike"` uses Akaike weights (Burnham & Anderson 2002): \\w_k
  \propto \exp(-\Delta_k / 2)\\, where \\\Delta_k\\ is the difference
  between the AIC of method \\k\\ and the smallest AIC. The AIC of each
  method uses Gaussian errors with its own maximum-likelihood variance,
  \\AIC_k = n \log(2\pi\hat\sigma_k^2) + n + 2p\\, with \\p = 1\\ (the
  variance): the member methods have no fitted parameters, so the
  penalty is the same for all and the weights reduce to relative
  likelihoods, \\w_k \propto \hat\sigma_k^{-n}\\. With many cases they
  concentrate almost all the weight on the method with the smallest mean
  squared error, so they select rather than combine. The AIC table is
  returned in `aic`.

## Assessment

When the cases come from more than one station (or, with a single
station, from more than one season), the ensemble is assessed by
leave-one-group-out cross-validation: the weights are re-estimated
without each group and used to predict it. Compare `cv` with the metrics
of the best single method before using the ensemble: when the members
share the same systematic error, weighting cannot remove it.

## References

Burnham, K. P., & Anderson, D. R. (2002). *Model Selection and
Multimodel Inference: A Practical Information-Theoretic Approach* (2nd
ed.). Springer. [doi:10.1007/b97636](https://doi.org/10.1007/b97636)

Breiman, L. (1996). Stacked regressions. *Machine Learning*, 24, 49-64.
[doi:10.1007/BF00117832](https://doi.org/10.1007/BF00117832)

Raftery, A. E., Gneiting, T., Balabdaoui, F., & Polakowski, M. (2005).
Using Bayesian model averaging to calibrate forecast ensembles. *Monthly
Weather Review*, 133(5), 1155-1174.
[doi:10.1175/MWR2906.1](https://doi.org/10.1175/MWR2906.1)

Yao, Y., Vehtari, A., Simpson, D., & Gelman, A. (2018). Using stacking
to average Bayesian predictive distributions. *Bayesian Analysis*,
13(3), 917-1007.
[doi:10.1214/17-BA1091](https://doi.org/10.1214/17-BA1091)

## See also

[`gdd_ensemble()`](https://djwillichile.github.io/thermify/reference/gdd_ensemble.md),
[`validate_station()`](https://djwillichile.github.io/thermify/reference/validate_station.md)

## Examples

``` r
# Illustration with made-up validation results (not real data): the
# observed totals lie between the averaging and the sine estimates.
val <- data.frame(
  station = rep(c("A", "B", "C"), each = 6),
  season = rep(rep(c(2020, 2021), each = 3), 3),
  method = rep(c("average", "single_sine", "single_triangle"), 6),
  estimate = c(950, 1010, 990, 1200, 1270, 1240, 870, 935, 910,
               1020, 1080, 1060, 1110, 1180, 1150, 990, 1050, 1030),
  observed = rep(c(985, 1245, 905, 1055, 1150, 1025), each = 3))
w <- gdd_ensemble_weights(val)
w
#> GDD ensemble weights (stacking, level "daily")
#> 6 cases in 3 station group(s)
#> 
#>     single_sine         average single_triangle 
#>           0.585           0.415           0.000 
#> 
#> Fit on the estimation cases:
#>           method n      bias    mae   rmse
#>         ensemble 6   0.04364  1.391  2.101
#>          average 6 -37.50000 37.500 37.694
#>      single_sine 6  26.66667 26.667 26.771
#>  single_triangle 6   2.50000  4.167  4.564
#> 
#> Cross-validated ensemble (leave one station out):
#>    method n     bias   mae  rmse
#>  ensemble 6 -0.01417 2.107 2.946
degree_days(c(5, 8), c(22, 25), method = "ensemble", weights = w,
            base = 10)
#> [1] 4.195342 6.672432
```
