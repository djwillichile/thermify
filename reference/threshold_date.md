# Date on which an accumulated index reaches a threshold

Accumulates daily (or hourly) index values in time order and returns the
first date on which the running total reaches `threshold`. Typical uses
are the date when a crop or pest reaches a degree-day requirement, or
when a cultivar completes its chill requirement.

## Usage

``` r
threshold_date(values, dates, threshold, na_action = c("propagate", "skip"))
```

## Arguments

- values:

  Numeric vector of index values per time step (not cumulative), for
  example the output of
  [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md).

- dates:

  Vector of `Date` (or `POSIXct`) of the same length, in increasing
  order.

- threshold:

  Single number: requirement in the units of `values`.

- na_action:

  `"propagate"` (default): if a missing value occurs before the
  threshold is reached, the result is `NA`, because the true date cannot
  be known. `"skip"`: missing steps contribute zero (the date may then
  be late).

## Value

A single date of the class of `dates` (`NA` if the threshold is not
reached), with attribute `"index"` (position in `dates`).

## Examples

``` r
dates <- seq(as.Date("2023-09-01"), by = "day", length.out = 10)
gdd <- c(2, 3, 5, 4, 6, 7, 3, 2, 8, 9)
threshold_date(gdd, dates, threshold = 20)
#> [1] "2023-09-05"
```
