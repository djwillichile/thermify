# Agreement metrics between estimated and observed values

Agreement metrics between estimated and observed values

## Usage

``` r
validation_metrics(estimate, observed)
```

## Arguments

- estimate, observed:

  Numeric vectors of equal length.

## Value

A one-row data frame with `n`, `bias` (mean of estimate minus observed),
`mae`, `rmse`, `rel_bias` (bias as a percentage of the mean observed
value; `NA` when that mean is close to zero, for example for Utah units)
and `r` (Pearson correlation; `NA` with fewer than three pairs or no
variance).

## Examples

``` r
validation_metrics(c(10, 12, 9), c(11, 11, 10))
#>   n       bias mae rmse rel_bias         r
#> 1 3 -0.3333333   1    1   -3.125 0.7559289
```
