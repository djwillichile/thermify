# Reconstruct hourly temperatures from daily extremes

Builds an ordered, continuous hourly series (hours 0 to 23 of each day)
from daily minimum and maximum temperatures. This is a modelling step
with its own uncertainty: reconstructed hours are not observations.

## Usage

``` r
hourly_temperatures(
  tmin,
  tmax,
  method = c("linvill", "sine"),
  latitude = NULL,
  doy = NULL,
  hour_tmin = 6,
  hour_tmax = 15,
  cyclic = FALSE,
  night = c("continuous", "chillr")
)
```

## Arguments

- tmin, tmax:

  Numeric vectors (or matrices with one row per series and one column
  per day) of daily extremes in degrees Celsius.

- method:

  `"linvill"` or `"sine"`.

- latitude:

  Latitude in decimal degrees, required by `"linvill"`. Scalar, or one
  value per row when `tmin` is a matrix.

- doy:

  Day of the year of each day (required by `"linvill"`).

- hour_tmin, hour_tmax:

  Local times (hours) of the minimum and maximum for `method = "sine"`.

- cyclic:

  Treat the series as a closed annual cycle.

- night:

  Pre-dawn formulation for `"linvill"`: `"continuous"` (default) or
  `"chillr"` (see Methods).

## Value

For vector input, a numeric vector of length `24 * length(tmin)` ordered
by day and hour. For matrix input, a matrix with one row per series and
`24 * ncol(tmin)` columns.

## Methods

- `"linvill"` (default): sine curve during daylight and logarithmic
  decay at night (Linvill 1990), with sunrise and sunset from
  [`daylength()`](https://djwillichile.github.io/thermify/reference/daylength.md).
  The minimum occurs at sunrise and daytime temperatures follow
  \\T\_{min} + (T\_{max} - T\_{min}) \sin(\pi (h - h\_{sr}) / (D +
  4))\\. Night temperatures decay from the sunset temperature to the
  minimum of the next day as \\\ln(h - h\_{ss} + 1) / \ln(N + 1)\\,
  where \\N\\ is the night length. This is the formulation used by
  `chillR::make_hourly_temps()`; thermify uses the same \\+1\\ offset
  before and after midnight, so the curve reaches exactly \\T\_{min}\\
  at sunrise (chillR omits the offset in the pre-dawn denominator,
  giving values slightly below \\T\_{min}\\ just before sunrise and a
  small discontinuity at midnight). Set `night = "chillr"` to reproduce
  chillR exactly, for example when comparing with published chillR
  results.

- `"sine"`: continuous half-cosine segments joining \\T\_{max,d-1} \to
  T\_{min,d}\\ (minimum at `hour_tmin`), \\T\_{min,d} \to T\_{max,d}\\
  (maximum at `hour_tmax`) and \\T\_{max,d} \to T\_{min,d+1}\\. With
  `hour_tmax - hour_tmin = 12` it is the symmetric sine; other timings
  give an asymmetric cycle. It does not need latitude and is consistent
  with the double sine degree-day method.

The extremes are reached exactly only at the modelled times; integer
hours may therefore not include the exact daily minimum or maximum.

## Boundaries

The first night needs the previous day's maximum and the last evening
the next day's minimum. With `cyclic = TRUE` the series is treated as a
closed climatological year (day 1 follows the last day). Otherwise the
first day uses its own maximum and the last day its own minimum.

## References

Linvill, D. E. (1990). Calculating chilling hours and chill units from
daily maximum and minimum temperature observations. *HortScience*,
25(1), 14-16.

Luedeling, E. (2012). Climate change impacts on winter chill for
temperate fruit and nut production: a review. *Scientia Horticulturae*,
144, 218-229.

## Examples

``` r
h <- hourly_temperatures(c(2, 4), c(14, 16), latitude = -35.97,
                         doy = c(180, 181))
round(h, 1)
#>  [1]  4.2  3.8  3.4  3.1  2.8  2.5  2.3  2.0  4.4  7.0  9.3 11.3 12.8 13.7 14.0
#> [16] 13.7 12.8 11.2  9.4  8.4  7.6  7.0  6.5  6.1  5.7  5.4  5.1  4.9  4.6  4.4
#> [31]  4.2  4.0  6.4  9.0 11.3 13.3 14.8 15.7 16.0 15.7 14.8 13.1 10.9  9.5  8.6
#> [46]  7.8  7.2  6.7
hourly_temperatures(c(2, 4), c(14, 16), method = "sine")
#>  [1]  6.145898  5.000000  3.985216  3.145898  2.518727  2.131114  2.000000
#>  [8]  2.361844  3.403733  5.000000  6.958111  9.041889 11.000000 12.596267
#> [15] 13.638156 14.000000 13.890738 13.567727 13.045085 12.345653 11.500000
#> [22] 10.545085  9.522642  8.477358  7.454915  6.500000  5.654347  4.954915
#> [29]  4.432273  4.109262  4.000000  4.361844  5.403733  7.000000  8.958111
#> [36] 11.041889 13.000000 14.596267 15.638156 16.000000 15.868886 15.481273
#> [43] 14.854102 14.014784 13.000000 11.854102 10.627171  9.372829
```
