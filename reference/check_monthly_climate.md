# Validate a pair of monthly temperature rasters

Runs the checks recommended before computing thermal indices from
monthly climatologies: number and order of layers, CRS, resolution and
extent agreement, plausible value range (a range beyond +/-100 suggests
scaled integers, as in WorldClim 1.4, which stored degrees C times 10),
missing values, identical NA masks and \\T\_{min} \le T\_{max}\\.

## Usage

``` r
check_monthly_climate(tmin, tmax)
```

## Arguments

- tmin, tmax:

  12-layer `SpatRaster` objects.

## Value

A data frame with columns `check`, `value` and `ok`.
