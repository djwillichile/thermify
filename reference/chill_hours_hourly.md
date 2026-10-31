# Chilling hours counted from hourly temperatures

Counts hours with temperatures inside the closed interval
`[lower, upper]`. This is the observational definition of chilling hours
and should be preferred over
[`chill_hours()`](https://djwillichile.github.io/thermify/reference/chill_hours.md)
whenever hourly records exist.

## Usage

``` r
chill_hours_hourly(
  temperature,
  lower = 0,
  upper = 7.2,
  output = c("cumulative", "hourly", "total"),
  na_action = c("propagate", "skip")
)
```

## Arguments

- temperature:

  Numeric vector (or matrix, one row per series) of hourly temperatures
  in degrees Celsius, at regular one-hour steps.

- lower, upper:

  Bounds of the chilling interval (degrees Celsius).

- output:

  `"cumulative"` (default), `"hourly"` (0/1 per hour) or `"total"`.

- na_action:

  `"propagate"` (default) turns the cumulative sum into `NA` from the
  first missing hour; `"skip"` counts missing hours as outside the
  interval and records the number skipped in the `"n_missing"`
  attribute.

## Value

Chilling hours with the shape implied by `output`.

## Examples

``` r
temp <- c(-1, 0, 3, 7.2, 7.3, 10)
chill_hours_hourly(temp, output = "hourly")
#> [1] 0 1 1 1 0 0
chill_hours_hourly(temp, output = "total")
#> [1] 3
```
