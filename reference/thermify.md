# Compute several thermal indices for one location

Integrated workflow: (optionally) densify monthly climatologies to daily
extremes, (optionally) reconstruct hourly temperatures, and compute
growing degree-days, chilling hours, Utah chill units and Dynamic model
chill portions with explicit accumulation periods.

## Usage

``` r
thermify(
  tmin = NULL,
  tmax = NULL,
  temperature = NULL,
  input = c("monthly", "daily", "hourly"),
  dates = NULL,
  year = 2023,
  latitude = NULL,
  temporal = c("auto", "tempify", "native"),
  interpolation = "pchip_mp",
  consistency = c("check", "mean_range"),
  indices = c("gdd", "ch", "cu", "cp"),
  gdd_methods = c("average", "single_sine"),
  base = c(5, 10),
  upper = NULL,
  cutoff = "horizontal",
  ch_methods = "sine",
  ch_lower = 0,
  ch_upper = 7.2,
  hourly_method = c("linvill", "sine"),
  chill_period = c("05-01", "08-31"),
  heat_period = c("09-01", "04-30")
)
```

## Arguments

- tmin, tmax:

  Monthly (length 12) or daily minimum and maximum temperatures in
  degrees Celsius.

- temperature:

  Hourly temperatures (degrees Celsius) when `input = "hourly"`.

- input:

  `"monthly"`, `"daily"` or `"hourly"`.

- dates:

  Dates of the daily values (required for `"daily"` and `"hourly"`).

- year:

  Reference calendar year for monthly input. Default 2023.

- latitude:

  Latitude in decimal degrees, required for the Linvill hourly model.

- temporal:

  Densification engine for monthly input: `"auto"`, `"tempify"` or
  `"native"` (see
  [`densify_monthly()`](https://djwillichile.github.io/thermify/reference/densify_monthly.md)).

- interpolation:

  Densification method, default `"pchip_mp"`.

- consistency:

  `"check"` or `"mean_range"` (see
  [`densify_monthly()`](https://djwillichile.github.io/thermify/reference/densify_monthly.md)).

- indices:

  Any of `"gdd"`, `"ch"`, `"cu"`, `"cp"`.

- gdd_methods:

  GDD methods, see
  [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md);
  `"hourly"` uses
  [`degree_hours()`](https://djwillichile.github.io/thermify/reference/degree_hours.md)
  on observed or reconstructed hourly temperatures.

- base:

  Lower GDD thresholds (degrees Celsius); one result per value.

- upper, cutoff:

  Upper GDD threshold and cutoff (see
  [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)).

- ch_methods:

  Chilling-hours methods: `"sine"`, `"triangle"` (from daily extremes)
  and/or `"hourly"` (counted on hourly temperatures).

- ch_lower, ch_upper:

  Chilling interval (degrees Celsius).

- hourly_method:

  Hourly reconstruction, `"linvill"` or `"sine"`.

- chill_period, heat_period:

  Accumulation windows as `c("MM-DD", "MM-DD")`. Defaults are
  southern-hemisphere conventions: chill from 1 May to 31 August, heat
  from 1 September to 30 April.

## Value

An object of class `"thermify"`: a list with `daily` (data frame of
daily temperatures and index values), `hourly` (data frame, when hourly
temperatures were used or reconstructed), `summary` (long data frame of
seasonal, annual and monthly totals with units), `config` and
`provenance`.

## Input frequency

The frequency is never inferred from the number of values; set `input`:

- `"monthly"`: `tmin`, `tmax` are 12 climatological monthly means. They
  are densified with
  [`densify_monthly()`](https://djwillichile.github.io/thermify/reference/densify_monthly.md)
  for the reference `year` and treated as a closed annual cycle. Results
  are climatological estimates, not observations of `year`.

- `"daily"`: `tmin`, `tmax` are daily extremes on `dates`.

- `"hourly"`: `temperature` holds `24 * length(dates)` hourly values
  starting at hour 0 of `dates[1]`. Daily extremes are taken from the
  hourly data, and chilling and degree-hour indices use the observations
  directly.

## Examples

``` r
tmin <- c(11.4, 11.1, 9.2, 6.8, 5.3, 3.9, 3.1, 3.6, 4.6, 6.3, 8.4, 10.3)
tmax <- c(29.6, 29.2, 26.5, 21.9, 17.2, 13.9, 13.6, 15.3, 17.9, 21.2,
          24.9, 28.2)
res <- thermify(tmin, tmax, input = "monthly", latitude = -35.97,
                temporal = "native")
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
head(res$daily)
#>         date doy month     tmin     tmax gdd_average_b5 gdd_average_b10
#> 1 2023-01-01   1     1 11.12849 29.27355       15.20102        10.20102
#> 2 2023-01-02   2     1 11.16894 29.32330       15.24612        10.24612
#> 3 2023-01-03   3     1 11.20770 29.37075       15.28923        10.28923
#> 4 2023-01-04   4     1 11.24460 29.41574       15.33017        10.33017
#> 5 2023-01-05   5     1 11.27949 29.45810       15.36879        10.36879
#> 6 2023-01-06   6     1 11.31219 29.49765       15.40492        10.40492
#>   gdd_single_sine_b5 gdd_single_sine_b10 ch_sine cu_utah cp_dynamic
#> 1           15.20102            10.20102       0      NA         NA
#> 2           15.24612            10.24612       0      NA         NA
#> 3           15.28923            10.28923       0      NA         NA
#> 4           15.33017            10.33017       0      NA         NA
#> 5           15.36879            10.36879       0      NA         NA
#> 6           15.40492            10.40492       0      NA         NA
```
