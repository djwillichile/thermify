# Read WorldClim 2.1 at 30 arc-seconds for a region only

Reads the 30 arc-second (about 1 km) WorldClim 2.1 normals (1970-2000)
for a region **without downloading global or country files**. The 30x30
degree tiles published by WorldClim are opened remotely with GDAL's
`/vsicurl/` driver and only the strips that intersect the region are
transferred via HTTP range requests (for a 20 x 20 km window, a few
hundred kilobytes per variable instead of a 40 MB country file or a 450
MB global archive). Regions spanning several tiles are read tile by tile
and merged.

## Usage

``` r
worldclim_region(
  var = c("tmin", "tmax", "tavg", "prec", "srad", "wind", "bio", "elev"),
  region,
  path,
  mask = TRUE,
  touches = TRUE,
  overwrite = FALSE
)
```

## Arguments

- var:

  One of `"tmin"`, `"tmax"`, `"tavg"`, `"prec"`, `"srad"`, `"wind"`,
  `"bio"` or `"elev"`.

- region:

  A `SpatExtent`, a numeric vector `c(xmin, xmax, ymin, ymax)` in
  longitude/latitude, or a `SpatVector` (any CRS; polygons can be used
  as a mask).

- path:

  Cache directory.

- mask:

  If `TRUE` and `region` is a polygon `SpatVector`, mask cells outside
  the polygons.

- touches:

  Passed to
  [`terra::mask()`](https://rspatial.github.io/terra/reference/mask.html):
  keep cells touched by the polygon boundary.

- overwrite:

  Ignore and replace a cached file.

## Value

A `SpatRaster` in EPSG:4326 at 30 arc-seconds. Monthly variables have 12
layers named `m01` to `m12`; `bio` has 19 layers (`bio01` to `bio19`)
and `elev` one layer. Attribute `"source"` lists the remote tiles read.

## Details

When `region` is a polygon `SpatVector` and `mask = TRUE`, cells outside
the polygons are set to `NA` (cells touched by the boundary are kept
when `touches = TRUE`). The result is cached in `path`; a later call
with the same region, variable and mask reuses the cached file without
network access.

This is the WorldClim 2.1 equivalent of the regional 30 arc-second
download that `raster::getData("worldclim", res = 0.5, lon, lat)`
offered for WorldClim 1.4. Coarser resolutions (2.5, 5 and 10
arc-minutes) are only distributed as compressed global archives, which
cannot be read partially; use
[`worldclim_monthly()`](https://djwillichile.github.io/thermify/reference/worldclim_monthly.md)
for them. Aggregating the 30 arc-second data is not a substitute: in
tests over central Chile the official 2.5 arc-minute product differed
from the 5 x 5 cell mean of the 30 arc-second product by up to about 0.9
degrees C.

## References

Fick, S. E., & Hijmans, R. J. (2017). WorldClim 2: new 1-km spatial
resolution climate surfaces for global land areas. *International
Journal of Climatology*, 37(12), 4302-4315.

## See also

[`worldclim_monthly()`](https://djwillichile.github.io/thermify/reference/worldclim_monthly.md),
[`study_window()`](https://djwillichile.github.io/thermify/reference/study_window.md),
[`check_monthly_climate()`](https://djwillichile.github.io/thermify/reference/check_monthly_climate.md).

## Examples

``` r
if (FALSE) { # \dontrun{
win <- study_window(-72.3225, -35.9671, size_km = 20)
tmin <- worldclim_region("tmin", win, path = "data")

# Mask with a polygon (for example a commune boundary)
# comuna <- terra::vect("cauquenes.gpkg")
# tmax <- worldclim_region("tmax", comuna, path = "data", mask = TRUE)
} # }
```
