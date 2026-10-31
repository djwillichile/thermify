# Degree-hours from hourly temperatures

Computes the thermal contribution of each hourly observation above a
base temperature, optionally bounded by an upper threshold with the same
cutoff conventions as
[`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md).

## Usage

``` r
degree_hours(
  temperature,
  base = 10,
  upper = NULL,
  cutoff = c("horizontal", "vertical", "intermediate"),
  by_day = FALSE
)
```

## Arguments

- temperature:

  Numeric vector (or matrix, one row per series) of hourly temperatures
  in degrees Celsius.

- base:

  Lower developmental threshold (degrees Celsius).

- upper:

  Optional upper developmental threshold (degrees Celsius).

- cutoff:

  Upper threshold treatment: `"horizontal"` (default), `"vertical"` or
  `"intermediate"`. Ignored when `upper` is `NULL`.

- by_day:

  If `TRUE`, the hourly series is summed in consecutive blocks of 24
  values and divided by 24, returning degree-days per day. The series
  length must then be a multiple of 24.

## Value

Degree-hours (degree Celsius hour) with the shape of `temperature`, or
degree-days per day (degree Celsius day) when `by_day = TRUE`.

## Details

The result is in degree Celsius hour. Divide daily sums by 24 to express
them as degree-days: \\GDD_d = \sum\_{h=1}^{24} DH_h / 24\\. The
function assumes regular one-hour time steps; it does not check
timestamps.

## Examples

``` r
temp <- 12 + 8 * sin(2 * pi * (0:23 - 9) / 24)
degree_hours(temp, base = 10)
#>  [1]  0.000000  0.000000  0.000000  0.000000  0.000000  0.000000  0.000000
#>  [8]  0.000000  0.000000  2.000000  4.070552  6.000000  7.656854  8.928203
#> [15]  9.727407 10.000000  9.727407  8.928203  7.656854  6.000000  4.070552
#> [22]  2.000000  0.000000  0.000000
degree_hours(temp, base = 10, by_day = TRUE)
#> [1] 3.615251
```
