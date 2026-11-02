# Validate thermal-index estimates against an hourly station record

Computes "observed" indices directly from hourly observations and
compares them with the estimates thermify produces from progressively
less information:

## Usage

``` r
validate_station(
  station,
  latitude,
  indices = c("gdd", "ch", "cu", "cp"),
  base = 10,
  upper = NULL,
  cutoff = "horizontal",
  gdd_methods = c("average", "single_sine", "single_triangle", "double_sine",
    "double_triangle"),
  hourly_methods = c("linvill", "sine"),
  ch_lower = 0,
  ch_upper = 7.2,
  chill_period = c("05-01", "08-31"),
  heat_period = c("09-01", "04-30"),
  gridded = NULL,
  temporal = c("native", "auto", "tempify")
)
```

## Arguments

- station:

  An object from
  [`prepare_station_hourly()`](https://djwillichile.github.io/thermify/reference/prepare_station_hourly.md).

- latitude:

  Station latitude in decimal degrees (Linvill model).

- indices:

  Any of `"gdd"`, `"ch"`, `"cu"`, `"cp"`.

- base, upper, cutoff:

  GDD thresholds and cutoff (see
  [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)).

- gdd_methods:

  Daily GDD methods to evaluate.

- hourly_methods:

  Hourly reconstructions to evaluate: `"linvill"` and/or `"sine"`.

- ch_lower, ch_upper:

  Chilling interval (degrees C).

- chill_period, heat_period:

  Accumulation windows (see
  [`thermify()`](https://djwillichile.github.io/thermify/reference/thermify.md)).

- gridded:

  Optional list with numeric vectors `tmin` and `tmax` of length 12
  (monthly climatology at the station location).

- temporal:

  Densification engine for the monthly levels.

## Value

An object of class `"thermify_validation"`: a list with `seasons` (one
row per season, index, level and method, with `estimate` and
`observed`), `metrics` (one row per index, level and method, from
[`validation_metrics()`](https://djwillichile.github.io/thermify/reference/validation_metrics.md)),
`excluded` (seasons not evaluated and why) and `quality` (from the
station object).

## Details

- level `"daily"`: daily extremes of the same station, with the
  analytical daily methods (GDD, chilling hours) and with hourly
  reconstructions (Linvill, sine) for chilling hours, Utah units and
  chill portions. This isolates the error of the diurnal model.

- level `"monthly"`: the station's own monthly climatology (mean daily
  extremes per calendar month over all valid days), densified with
  `pchip_mp`. This adds the loss of day-to-day variability and of
  interannual variability: one climatological value is compared with
  each season.

- level `"gridded"` (optional): a monthly climatology from a gridded
  product, for example the WorldClim cell containing the station. This
  adds the spatial interpolation error and the difference between
  climate normal periods.

Only complete seasons are evaluated: a season is excluded when any of
its days is invalid after gap filling (see
[`prepare_station_hourly()`](https://djwillichile.github.io/thermify/reference/prepare_station_hourly.md))
or when the record does not cover the whole window. Excluded seasons are
reported.

## See also

[`prepare_station_hourly()`](https://djwillichile.github.io/thermify/reference/prepare_station_hourly.md),
[`validation_metrics()`](https://djwillichile.github.io/thermify/reference/validation_metrics.md),
[`vignette("validation")`](https://djwillichile.github.io/thermify/articles/validation.md).
