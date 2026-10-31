# Thermal indices from monthly climatology rasters

Spatial version of
[`thermify()`](https://djwillichile.github.io/thermify/reference/thermify.md)
for 12-layer monthly `SpatRaster` stacks (for example WorldClim 2.1
`tmin` and `tmax`). Rasters are processed in blocks of rows: for each
block, valid cells are densified to daily values, hourly temperatures
are reconstructed when needed, indices are computed and only the
aggregated layers are written to disk. Daily or hourly rasters are never
held for the whole extent.

## Usage

``` r
thermify_rast(
  tmin,
  tmax,
  output_dir,
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
  heat_period = c("09-01", "04-30"),
  temporal_aggregation = c("season", "annual", "monthly"),
  max_cells = 2000L,
  format = "GTiff",
  keep_daily = FALSE,
  overwrite = FALSE,
  progress = getOption("thermify.progress", interactive())
)
```

## Arguments

- tmin, tmax:

  `SpatRaster` objects with 12 layers (January to December) in degrees
  Celsius and identical geometry.

- output_dir:

  Directory for the output files (created if needed).

- year:

  Reference calendar year for monthly input. Default 2023.

- latitude:

  Optional fixed latitude for the Linvill model. By default the latitude
  of each cell centre is used (cells are projected to EPSG:4326 when the
  CRS is not geographic).

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

- temporal_aggregation:

  Any of `"season"`, `"annual"`, `"monthly"`.

- max_cells:

  Maximum number of cells per processing block.

- format:

  `"GTiff"` and/or `"netCDF"`.

- keep_daily:

  If `TRUE`, also write the reconstructed daily `tmin` and `tmax` (365
  or 366 layers each) for diagnosis.

- overwrite:

  Overwrite existing files.

- progress:

  Show progress (blocks done, percentage, elapsed time and estimated
  time remaining). Defaults to the option `thermify.progress`, or `TRUE`
  in interactive sessions. In non-interactive runs a status line is
  written at most every 10 seconds, so logs show the process is alive.

## Value

A named list of file-backed `SpatRaster` objects, one per index key,
with attribute `"provenance"`.

## Outputs

One GeoTIFF per index key (for example `gdd_single_sine_b10.tif`) is
written to `output_dir`, with layers named after the temporal
aggregation: `season` (accumulation period), `annual` (1 January to 31
December, GDD and chilling hours only) and `m01`...`m12` (monthly
totals; for Utah and Dynamic models only months inside the chill period
are filled). The CRS, extent, resolution and NA mask of `tmin` are
preserved. With `format = "netCDF"` the same layers are also written to
one NetCDF file per index. A `provenance.json` (or `.txt` without
jsonlite) file records parameters and versions.

## Memory

Peak memory is roughly proportional to `max_cells` times the number of
hours in a year (8760 values per cell) when hourly-based indices are
requested. Lower `max_cells` to reduce memory; results do not depend on
the block size.

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  r <- terra::rast(nrows = 3, ncols = 3, nlyrs = 12,
                   xmin = -72.4, xmax = -72.3, ymin = -36, ymax = -35.9)
  base_min <- c(11, 11, 9, 7, 5, 4, 3, 4, 5, 6, 8, 10)
  base_max <- c(29, 29, 26, 22, 17, 14, 13, 15, 18, 21, 25, 28)
  tmin <- terra::setValues(r, rep(base_min, each = 9))
  tmax <- terra::setValues(r, rep(base_max, each = 9))
  out <- thermify_rast(tmin, tmax, output_dir = tempfile(),
                       temporal = "native", indices = c("gdd", "cp"),
                       gdd_methods = "single_sine", base = 10)
  out$gdd_single_sine_b10
}
#> class       : SpatRaster
#> size        : 3, 3, 14  (nrow, ncol, nlyr)
#> resolution  : 0.03333333, 0.03333333  (x, y)
#> extent      : -72.4, -72.3, -36, -35.9  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source      : gdd_single_sine_b10.tif
#> names       :      season,      annual, m01, m02,        m03,       m04, ...
#> min values  : 1686.064087, 1865.361572, 310, 280, 236.363266, 152.88443, ...
#> max values  : 1686.064087, 1865.361572, 310, 280, 236.363266, 152.88443, ...
#> unit        : degC day
# }
```
