# Densify monthly climatologies to daily values

Converts 12 monthly values (one climatological year) to daily values for
a reference calendar year. The default `"pchip_mp"` method fits a cyclic
piecewise cubic Hermite interpolant (PCHIP, Fritsch-Butland derivatives
as in `scipy.interpolate.PchipInterpolator`) through the monthly values
placed at mid-month and then corrects each month so that the mean of its
daily values equals the input monthly value (mean-preserving step).

## Usage

``` r
densify_monthly(
  tmin,
  tmax,
  year = 2023,
  method = "pchip_mp",
  engine = c("auto", "tempify", "native"),
  consistency = c("check", "mean_range")
)
```

## Arguments

- tmin, tmax:

  Numeric vectors of length 12, or matrices with one row per location
  and 12 columns (January to December), in degrees Celsius.

- year:

  Reference calendar year. Default 2023 (365 days); leap years give 366
  days.

- method:

  Interpolation method. `"pchip_mp"` (default) or `"pchip"` for both
  engines; tempify also offers `"linear"`, `"akima"`, `"cubic"` and
  `"fourier"`.

- engine:

  `"auto"`, `"tempify"` or `"native"`.

- consistency:

  `"check"` or `"mean_range"`.

## Value

A list with matrices `tmin` and `tmax` (one row per location, one column
per day), the vector of `dates`, and `provenance` (engine, method,
versions and diagnostics). Rows with any missing month are `NA`.

## Engines

- `engine = "tempify"` calls the Python package
  [tempify](https://github.com/djwillichile/tempify) through
  `reticulate`. It is the reference implementation and supports all
  tempify methods.

- `engine = "native"` is a pure R implementation of `"pchip"` and
  `"pchip_mp"` that follows the tempify algorithm (cyclic padding with
  two nodes on each side, mid-month anchors, uniform monthly
  correction). It needs no Python and is tested against tempify to
  within 1e-9 degrees C.

- `engine = "auto"` uses tempify when it is importable and native
  otherwise.

## Mean preservation and its side effects

The tempify mean-preserving step adds the residual of each month
uniformly to its days. Monthly means are therefore reproduced exactly
(up to the convergence tolerance), but the daily curve is piecewise
shifted and can show small steps at month boundaries.
[`densify_diagnostics()`](https://djwillichile.github.io/thermify/reference/densify_diagnostics.md)
reports the magnitude of those steps.

## Physical consistency

Independent interpolation of `tmin` and `tmax` can, in principle,
produce days with \\T\_{min} \> T\_{max}\\. With `consistency = "check"`
such days raise an error. With `consistency = "mean_range"` the daily
mean \\(T\_{min}+T\_{max})/2\\ and the diurnal range
\\T\_{max}-T\_{min}\\ are densified instead and transformed back.
Because the transformation is linear, monthly means of `tmin` and `tmax`
are still preserved exactly; an error is raised if the densified range
becomes negative. Extremes are never swapped or clipped silently.

## References

Rymes, M. D., & Myers, D. R. (2001). Mean preserving algorithm for
smoothly interpolating averaged data. *Solar Energy*, 71(4), 225-231.

Fritsch, F. N., & Butland, J. (1984). A method for constructing local
monotone piecewise cubic interpolants. *SIAM Journal on Scientific and
Statistical Computing*, 5(2), 300-304.

## See also

[`tempify_available()`](https://djwillichile.github.io/thermify/reference/tempify_available.md),
[`densify_diagnostics()`](https://djwillichile.github.io/thermify/reference/densify_diagnostics.md).

## Examples

``` r
tmin <- c(11, 11, 9, 7, 5, 4, 3, 4, 5, 7, 9, 10)
tmax <- c(29, 29, 26, 22, 17, 14, 13, 15, 18, 21, 25, 28)
d <- densify_monthly(tmin, tmax, engine = "native")
dim(d$tmin)
#> [1]   1 365
# Monthly means are preserved
tapply(d$tmin[1, ], format(d$dates, "%m"), mean)
#> 01 02 03 04 05 06 07 08 09 10 11 12 
#> 11 11  9  7  5  4  3  4  5  7  9 10 
```
