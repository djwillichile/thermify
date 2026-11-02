# Prepare an hourly station record for validation

Puts hourly temperature observations on a regular hourly grid of
complete days, fills short gaps by linear interpolation and flags days
that remain incomplete. The result is the input of
[`validate_station()`](https://djwillichile.github.io/thermify/reference/validate_station.md).

## Usage

``` r
prepare_station_hourly(time, temperature, max_gap = 2, range = c(-40, 55))
```

## Arguments

- time:

  Observation times (`POSIXct`), in local standard time. Each value
  marks the start of its hour.

- temperature:

  Hourly air temperature in degrees C.

- max_gap:

  Longest run of missing hours filled by interpolation.

- range:

  Plausible temperature range; values outside are set to `NA`.

## Value

An object of class `"station_hourly"`: a list with `dates`, `hourly`
(matrix, one row per day and 24 columns for hours 0-23), `valid`
(logical per day), and `quality` (counts of hours observed, filled and
missing, and of valid days).

## Quality control

- Timestamps are rounded down to the hour; several values within the
  same hour are averaged.

- Internal gaps of at most `max_gap` consecutive hours are filled by
  linear interpolation between the neighbouring observations. Longer
  gaps are left missing.

- A day is valid when all its 24 hours are available after filling.

- Values outside `range` (degrees C) are treated as missing before
  filling.

## See also

[`validate_station()`](https://djwillichile.github.io/thermify/reference/validate_station.md)
