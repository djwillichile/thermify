# Read WorldClim 2.1 CMIP6 future climate for a region

Reads the part of a WorldClim 2.1 downscaled CMIP6 projection (monthly
minimum or maximum temperature, or precipitation, at 30 arc-seconds)
that covers a region, without downloading the global file (about 5 GB
per variable, model, scenario and period). Only the bytes of the region
are read with GDAL `/vsicurl/`, and the result is cached in `path`.

## Usage

``` r
worldclim_future_region(
  var = c("tmin", "tmax", "prec"),
  region,
  gcm,
  ssp = c("245", "126", "370", "585"),
  period = c("2041-2060", "2021-2040", "2061-2080", "2081-2100"),
  path,
  mask = TRUE,
  touches = TRUE,
  overwrite = FALSE
)
```

## Arguments

- var:

  `"tmin"`, `"tmax"` or `"prec"`.

- region:

  A `SpatExtent`, a numeric vector `c(xmin, xmax, ymin, ymax)` in
  longitude/latitude, or a `SpatVector` (any CRS; polygons can be used
  as a mask).

- gcm:

  Global climate model, for example `"MPI-ESM1-2-HR"`. See
  `worldclim_cmip6_gcms` for the models listed by WorldClim.

- ssp:

  Shared socio-economic pathway: `"126"`, `"245"`, `"370"` or `"585"`.

- period:

  `"2021-2040"`, `"2041-2060"`, `"2061-2080"` or `"2081-2100"`.

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

A `SpatRaster` in EPSG:4326 at 30 arc-seconds with 12 layers `m01` to
`m12`. Attribute `"source"` gives the remote file read.

## Details

WorldClim derives the future surfaces from each global climate model
(GCM) by adding the model's change to the WorldClim 2.1 baseline
(1970-2000) and applying a bias correction. Differences between a future
layer and
[`worldclim_region()`](https://djwillichile.github.io/thermify/reference/worldclim_region.md)
are therefore the projected change of that model. Single models can be
far from the multi-model consensus: use several GCMs and report their
spread.

Not every model provides every scenario; a missing combination gives an
informative error.

## References

Fick, S. E., & Hijmans, R. J. (2017). WorldClim 2: new 1-km spatial
resolution climate surfaces for global land areas. *International
Journal of Climatology*, 37(12), 4302-4315.
[doi:10.1002/joc.5086](https://doi.org/10.1002/joc.5086)

Eyring, V., et al. (2016). Overview of the Coupled Model Intercomparison
Project Phase 6 (CMIP6) experimental design and organization.
*Geoscientific Model Development*, 9(5), 1937-1958.
[doi:10.5194/gmd-9-1937-2016](https://doi.org/10.5194/gmd-9-1937-2016)

## See also

[`worldclim_region()`](https://djwillichile.github.io/thermify/reference/worldclim_region.md)
for the 1970-2000 baseline.

## Examples

``` r
if (FALSE) { # \dontrun{
prov <- cauquenes_boundary("provincia")
now <- worldclim_region("tmin", prov, path = tempdir())
fut <- worldclim_future_region("tmin", prov, gcm = "MPI-ESM1-2-HR",
                               ssp = "245", period = "2041-2060",
                               path = tempdir())
fut - now   # projected change of this model, degrees C
} # }
```
