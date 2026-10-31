# Square study window around a point

Builds a square window of `size_km` side centred on a WGS84 point. The
square is defined in the local UTM zone (metres) and returned as the
enclosing longitude/latitude extent, so that its size does not depend on
latitude.

## Usage

``` r
study_window(lon, lat, size_km = 20)
```

## Arguments

- lon, lat:

  Centre in decimal degrees (WGS84).

- size_km:

  Side of the square in kilometres.

## Value

A `SpatExtent` in longitude/latitude, with attribute `"utm"` (the EPSG
code used).

## Examples

``` r
if (requireNamespace("terra", quietly = TRUE)) {
  study_window(-72.3225, -35.9671, 20)
}
#> SpatExtent : -72.436203822487983, -72.208545100818711, -36.059590989047777, -35.874521561573218 (xmin, xmax, ymin, ymax)
```
