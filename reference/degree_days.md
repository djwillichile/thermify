# Growing degree-days from daily minimum and maximum temperatures

Computes daily growing degree-days (GDD, in degree Celsius day) with the
averaging, single sine, single triangle, double sine or double triangle
methods, optionally bounded by an upper developmental threshold.

## Usage

``` r
degree_days(
  tmin,
  tmax,
  method = c("single_sine", "average", "single_triangle", "double_sine",
    "double_triangle"),
  base = 10,
  upper = NULL,
  cutoff = c("horizontal", "vertical", "intermediate"),
  tmin_next = NULL
)
```

## Arguments

- tmin, tmax:

  Numeric vectors of daily minimum and maximum temperatures (degrees
  Celsius), of equal length, ordered in time for double methods.

- method:

  One of `"single_sine"` (default), `"average"`, `"single_triangle"`,
  `"double_sine"` or `"double_triangle"`.

- base:

  Lower developmental threshold (degrees Celsius).

- upper:

  Optional upper developmental threshold (degrees Celsius).

- cutoff:

  Upper threshold treatment: `"horizontal"` (default), `"vertical"` or
  `"intermediate"`. Ignored when `upper` is `NULL`.

- tmin_next:

  Optional numeric vector with the minimum temperature of the following
  day, used only by double methods.

## Value

Numeric vector of daily degree-days (degree Celsius day), same length as
`tmin`.

## Methods

All sine and triangle methods are evaluated with closed-form
expressions; no hourly temperatures are generated.

- `"average"`: \\\max(0, (T\_{max} + T\_{min}) / 2 - T_b)\\ (McMaster &
  Wilhelm 1997, method 1). With an upper threshold the cutoff is applied
  to the daily mean.

- `"single_sine"`: a sine wave between `tmin` and `tmax` over 24 h
  (Baskerville & Emin 1969).

- `"single_triangle"`: a symmetric triangle between `tmin` and `tmax`
  (Lindsey & Newman 1956; Sevacherian et al. 1977).

- `"double_sine"`, `"double_triangle"`: the day is split into two
  half-day segments: `tmin` to `tmax` of the same day, then `tmax` to
  the minimum of the following day (`tmin_next`). Each half contributes
  half a day (Allen 1976; Zalom et al. 1983).

## Upper threshold cutoffs

With an upper threshold \\T_u\\:

- `"horizontal"`: development continues at the constant rate reached at
  \\T_u\\; the area above \\T_u\\ is removed.

- `"vertical"`: no development while temperature exceeds \\T_u\\; the
  whole area under the curve during those hours is removed.

- `"intermediate"`: development decreases linearly above \\T_u\\ with
  slope -1 (the area above \\T_u\\ is subtracted a second time), with
  the rate floored at zero. The floor only matters when temperatures
  exceed \\2T_u - T_b\\.

The three cutoffs coincide when temperatures stay below `upper` and give
different results otherwise; they are not interchangeable.

## Missing values and boundaries

Missing `tmin` or `tmax` give `NA` for that day. Double methods need the
minimum of the next day; when `tmin_next` is `NULL` it is taken from the
following element of `tmin`, and the last day is `NA`. Supply
`tmin_next` explicitly to close the series (for a cyclic climatological
year pass `c(tmin[-1], tmin[1])`). If the following minimum is above the
current maximum, the second half-day segment is evaluated between the
two values in increasing order.

## References

Allen, J. C. (1976). A modified sine wave method for calculating degree
days. *Environmental Entomology*, 5(3), 388-396.

Baskerville, G. L., & Emin, P. (1969). Rapid estimation of heat
accumulation from maximum and minimum temperatures. *Ecology*, 50(3),
514-517.

Lindsey, A. A., & Newman, J. E. (1956). Use of official weather data in
spring time temperature analysis of an Indiana phenological record.
*Ecology*, 37(4), 812-823.

McMaster, G. S., & Wilhelm, W. W. (1997). Growing degree-days: one
equation, two interpretations. *Agricultural and Forest Meteorology*,
87(4), 291-300.

Sevacherian, V., Stern, V. M., & Mueller, A. J. (1977). Heat
accumulation for timing Lygus control measures in a safflower-cotton
complex. *Journal of Economic Entomology*, 70(4), 399-402.

Zalom, F. G., Goodell, P. B., Wilson, L. T., Barnett, W. W., & Bentley,
W. J. (1983). *Degree-days: the calculation and use of heat units in
pest management*. University of California DANR Leaflet 21373.

## See also

[`degree_hours()`](https://djwillichile.github.io/thermify/reference/degree_hours.md)
for hourly temperatures.

## Examples

``` r
tmin <- c(4, 8, 12, 15)
tmax <- c(16, 22, 28, 34)
degree_days(tmin, tmax, method = "average", base = 10)
#> [1]  0.0  5.0 10.0 14.5
degree_days(tmin, tmax, method = "single_sine", base = 10)
#> [1]  1.909859  5.325635 10.000000 14.500000
degree_days(tmin, tmax, method = "single_sine", base = 10, upper = 30,
            cutoff = "vertical")
#> [1]  1.909859  5.325635 10.000000  7.634159
degree_days(tmin, tmax, method = "double_sine", base = 10,
            tmin_next = c(tmin[-1], 10))
#> [1]  2.172925  6.162818 10.750000 13.250000
```
