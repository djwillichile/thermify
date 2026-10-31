# Chilling hours estimated from daily minimum and maximum temperatures

Estimates the number of hours per day with temperatures inside the
chilling interval `[lower, upper]` from daily extremes, by assuming an
idealised diurnal profile. The default interval (0 to 7.2 degrees
Celsius) corresponds to the "0-7.2 degrees C" chilling-hours model
derived from the 45 degrees F threshold of Weinberger (1950).

## Usage

``` r
chill_hours(
  tmin,
  tmax,
  method = c("sine", "triangle", "numerical"),
  lower = 0,
  upper = 7.2,
  n_steps = 1440L
)
```

## Arguments

- tmin, tmax:

  Numeric vectors of daily minimum and maximum temperatures (degrees
  Celsius).

- method:

  `"sine"`, `"triangle"` or `"numerical"`.

- lower, upper:

  Bounds of the chilling interval (degrees Celsius).

- n_steps:

  Number of evaluation instants per day for `method = "numerical"`.

## Value

Numeric vector of estimated hours per day, between 0 and 24.

## Methods

- `"sine"` (default): closed-form duration for a sine wave between
  `tmin` and `tmax`. With mean \\M\\ and amplitude \\A\\, the fraction
  of the day above \\x\\ is \\1/2 - \arcsin((x - M)/A)/\pi\\.

- `"triangle"`: closed-form duration for a symmetric triangular profile
  (temperatures uniformly distributed between `tmin` and `tmax`).

- `"numerical"`: numerical reference for the sine profile, evaluated on
  `n_steps` equally spaced instants per day. It converges to `"sine"`
  and is intended for verification only.

The duration depends only on the distribution of temperatures within the
day, not on the timing of the extremes. Results are model-based
**estimates**, not observed chilling hours; real diurnal cycles depart
from a sine wave (cloudiness, advection, cold-air pooling). Use
[`chill_hours_hourly()`](https://djwillichile.github.io/thermify/reference/chill_hours_hourly.md)
when hourly observations are available.

When `tmin == tmax` the day is either entirely inside (24 h) or outside
(0 h) the interval; both bounds are inclusive in that case.

## References

Weinberger, J. H. (1950). Chilling requirements of peach varieties.
*Proceedings of the American Society for Horticultural Science*, 56,
122-128.

Luedeling, E. (2012). Climate change impacts on winter chill for
temperate fruit and nut production: a review. *Scientia Horticulturae*,
144, 218-229.

## See also

[`chill_hours_hourly()`](https://djwillichile.github.io/thermify/reference/chill_hours_hourly.md),
[`chill_units()`](https://djwillichile.github.io/thermify/reference/chill_units.md),
[`chill_portions()`](https://djwillichile.github.io/thermify/reference/chill_portions.md).

## Examples

``` r
chill_hours(c(-2, 4, 10), c(10, 12, 20))
#> [1]  9.872169 10.461739  0.000000
chill_hours(c(-2, 4, 10), c(10, 12, 20), method = "triangle")
#> [1] 14.4  9.6  0.0
chill_hours(c(-2, 4, 10), c(10, 12, 20), lower = -Inf, upper = 7.2)
#> [1] 16.29746 10.46174  0.00000
```
