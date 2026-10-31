# Getting started with thermify

``` r

library(thermify)
```

## Architecture

`thermify` separates the stages of a thermal-index workflow so that each
can be tested and replaced independently:

    monthly normals --densify_monthly()--> daily Tmin/Tmax --hourly_temperatures()--> hourly T
                                                |                                        |
                           degree_days(), chill_hours()        degree_hours(), chill_hours_hourly(),
                                                |              chill_units(), chill_portions()
                                                +------------------+---------------------+
                                                                   |
                                        season_days() / aggregation (thermify(), thermify_rast())
                                                                   |
                                                   data frames, GeoTIFF, NetCDF, provenance

Scientific functions never read or write files;
[`thermify()`](https://djwillichile.github.io/thermify/reference/thermify.md)
and
[`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)
orchestrate them.

## Inputs are explicit

Frequencies are never inferred from the number of values. Daily
functions take `tmin` and `tmax`; hourly functions take `temperature`;
monthly workflows are selected with `input = "monthly"`.

``` r

tmin <- c(2, 5, 9, 12)
tmax <- c(14, 19, 25, 31)
degree_days(tmin, tmax, method = "average", base = 10)
#> [1]  0.0  2.0  7.0 11.5
degree_days(tmin, tmax, method = "single_sine", base = 10)
#> [1]  1.016980  3.319749  7.106780 11.500000
chill_hours(tmin, tmax)
#> [1] 10.978366  6.227759  0.000000  0.000000
```

## Monthly climatology for one site

``` r

tmin_m <- c(11.4, 11.1, 9.2, 6.8, 5.3, 3.9, 3.1, 3.6, 4.6, 6.3, 8.4, 10.3)
tmax_m <- c(29.6, 29.2, 26.5, 21.9, 17.2, 13.9, 13.6, 15.3, 17.9, 21.2,
            24.9, 28.2)
res <- thermify(tmin_m, tmax_m, input = "monthly", latitude = -35.97,
                temporal = "native", gdd_methods = c("average", "single_sine"),
                base = c(5, 10))
res
#> <thermify> monthly input, 365 days (climatological cycle)
#> Densification: pchip_mp via native (max |monthly mean error| = 4.4e-16 degC)
#> Hourly temperatures: linvill
#>                  key aggregation  value       units
#>       gdd_average_b5      season 2833.6    degC day
#>       gdd_average_b5      annual 3386.1    degC day
#>      gdd_average_b10      season 1623.6    degC day
#>      gdd_average_b10      annual 1663.1    degC day
#>   gdd_single_sine_b5      season 2834.8    degC day
#>   gdd_single_sine_b5      annual 3409.8    degC day
#>  gdd_single_sine_b10      season 1724.6    degC day
#>  gdd_single_sine_b10      annual 1915.4    degC day
#>              ch_sine      season 1073.9           h
#>              ch_sine      annual 1462.3           h
#>              cu_utah      season 1867.0 chill units
#>           cp_dynamic      season   81.8    portions
```

The `daily`, `hourly` and `summary` elements are ordinary data frames:

``` r

with(res$daily, plot(date, cumsum(gdd_single_sine_b10), type = "l",
                     ylab = "Cumulative GDD base 10 (degC day)", xlab = ""))
```

![](thermify_files/figure-html/unnamed-chunk-4-1.png)

These values are **climatological estimates** for a reference 365-day
year, not observations of 2023.

## When is a requirement met?

[`threshold_date()`](https://djwillichile.github.io/thermify/reference/threshold_date.md)
accumulates daily (or hourly) values and returns the first date on which
a requirement is reached, for example a degree-day target or a
cultivar’s chill requirement. With observed daily data for a season:

``` r

dates <- seq(as.Date("2022-09-01"), as.Date("2023-04-30"), by = "day")
doy <- as.integer(format(dates, "%j"))
tmax <- 22 + 8 * cos(2 * pi * (doy - 15) / 365)
tmin <- tmax - 14
gdd <- degree_days(tmin, tmax, method = "single_sine", base = 10)
threshold_date(gdd, dates, threshold = 500)
#> [1] "2022-11-28"
```

Missing days before the threshold make the date `NA` unless
`na_action = "skip"` is chosen explicitly.

## Rasters

[`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)
takes two 12-layer `SpatRaster` objects and writes one multi-layer file
per index (season, annual and monthly totals), reporting progress by
blocks with elapsed and estimated remaining time (`progress = TRUE`, or
`options(thermify.progress = TRUE)`). For WorldClim 2.1 at 30
arc-seconds,
[`worldclim_region()`](https://djwillichile.github.io/thermify/reference/worldclim_region.md)
reads only the region of interest. See
[`vignette("cauquenes")`](https://djwillichile.github.io/thermify/articles/cauquenes.md).
