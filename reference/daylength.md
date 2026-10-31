# Astronomical day length, sunrise and sunset

Computes solar declination with the Fourier series of Spencer (1971) and
sunrise and sunset (local solar time, hours) for a solar altitude of
-0.8333 degrees (upper limb of the disc with standard refraction).

## Usage

``` r
daylength(latitude, doy)
```

## Arguments

- latitude:

  Latitude in decimal degrees (south negative). Scalar or a vector
  recycled against `doy`.

- doy:

  Day of the year (1-366).

## Value

A data frame with columns `doy`, `sunrise`, `sunset` and `daylength`
(hours). Polar day gives `daylength = 24` and polar night
`daylength = 0`; `sunrise` and `sunset` are then set to 0/24 and 12/12.

## References

Spencer, J. W. (1971). Fourier series representation of the position of
the sun. *Search*, 2(5), 172.

## Examples

``` r
daylength(-35.97, c(172, 355))
#>   doy  sunrise   sunset daylength
#> 1 172 7.144844 16.85516  9.710312
#> 2 355 4.699464 19.30054 14.601072
```
