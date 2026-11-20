# Growing degree-days from an ensemble of methods

Computes the daily degree-days of each member method and their weighted
mean, with the spread between members as a measure of method
uncertainty.
[`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)
with `method = "ensemble"` returns only the weighted mean.

## Usage

``` r
gdd_ensemble(
  tmin,
  tmax,
  weights,
  base = 10,
  upper = NULL,
  cutoff = c("horizontal", "vertical", "intermediate"),
  tmin_next = NULL
)
```

## Arguments

- tmin, tmax:

  Numeric vectors of daily minimum and maximum temperatures (degrees
  Celsius), of equal length, ordered in time for double methods.

- weights:

  Ensemble weights: an object from
  [`gdd_ensemble_weights()`](https://djwillichile.github.io/thermify/reference/gdd_ensemble_weights.md)
  or a named numeric vector of non-negative weights (names are
  [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)
  methods). Weights are rescaled to sum to one.

- base:

  Lower developmental threshold (degrees Celsius).

- upper:

  Optional upper developmental threshold (degrees Celsius).

- cutoff:

  Upper threshold treatment: `"horizontal"` (default), `"vertical"` or
  `"intermediate"`. Ignored when `upper` is `NULL`.

- tmin_next:

  Optional numeric vector with the minimum temperature of the following
  day, used only by double methods.

## Value

A data frame with one row per day and columns `ensemble` (weighted
mean), `sd` (weighted standard deviation between members), `min` and
`max` (range of the members with non-zero weight) and one column per
member method.

## See also

[`gdd_ensemble_weights()`](https://djwillichile.github.io/thermify/reference/gdd_ensemble_weights.md)

## Examples

``` r
w <- c(average = 0.3, single_triangle = 0.7)  # illustrative weights
gdd_ensemble(c(5, 8, 12), c(22, 25, 30), weights = w, base = 10)
#>    ensemble         sd  min       max average single_triangle
#> 1  4.014706 0.33695410  3.5  4.235294     3.5        4.235294
#> 2  6.582353 0.05391266  6.5  6.617647     6.5        6.617647
#> 3 11.000000 0.00000000 11.0 11.000000    11.0       11.000000
```
