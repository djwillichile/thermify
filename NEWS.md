# thermify (development version)

## New features

* `thermify_rast()` returns an object of class `"thermify_rast"` (still a
  named list of `SpatRaster`) with a `plot()` method: `variable` selects
  indices or families, `type` the layer (`"season"`, `"annual"`,
  `"monthly"` or months such as `"m07"`), `nrow`/`ncol` the layout, plus
  `col`, `boundary`, a common or per-panel colour scale and `titles`; and a
  `print()` method that summarises indices, units, layers and files. Titles
  that do not fit in a panel are wrapped onto several lines; a single index
  shown month by month gets short titles (month and units) with the index
  name above the panels; months without data (outside the chill period)
  are left out.

# thermify 0.2.0

Adds the tools for empirical validation against station records, the
official DPA 2023 boundaries of Cauquenes, and attaches `terra` with the
package. Validation results with real stations (#3) are not part of this
release. Archived on Zenodo: <https://doi.org/10.5281/zenodo.23905378>.

## Breaking changes

* `terra` is now a dependency (`Depends`) instead of a suggested package:
  installing thermify installs terra, and `library(thermify)` attaches it,
  so `vect()`, `rast()`, `plot()` and the other `terra` functions are
  available without `terra::`. On Linux, terra needs the GDAL, GEOS and PROJ
  system libraries.

## New features

* `cauquenes` dataset: official DPA 2023 boundaries of the Cauquenes commune
  and province (packed `SpatVector`, EPSG:5360), replacing the
  undocumented `cauquenes.gpkg` referenced in earlier documentation.
* `cauquenes_boundary()` returns one or both levels as a `SpatVector`,
  optionally projected (`crs`).
* Station validation (#3): `prepare_station_hourly()` regularises hourly
  records, fills short gaps and flags incomplete days; `validate_station()`
  compares indices observed on hourly data with estimates from daily
  extremes, from the station's densified monthly climatology and,
  optionally, from a gridded climatology; `validation_metrics()` returns
  bias, MAE, RMSE, relative bias and correlation. The protocol is tested on
  synthetic records; results with real stations are pending.

## Documentation

* The `cauquenes` dataset cites its source (SUBDERE, DPA 2023) and carries
  the DIFROL circulation notice (Resolución Nº 87 de 2023).
* `vignette("validation")` documents the implementation; examples, the
  Cauquenes tutorial and the README use `cauquenes_boundary()` and bare
  `terra` calls.
* Release and development version badges in the README and the site.

# thermify 0.1.0

Archived on Zenodo: <https://doi.org/10.5281/zenodo.23841857>.

First release. Functional, documented and tested package for agroclimatic
thermal indices: growing degree-days, chilling hours, Utah chill units and
Dynamic model chill portions, from hourly, daily or monthly temperatures, for
single sites and rasters.

Verified on Ubuntu (R release and oldrel), Windows and macOS. Results based on
monthly climatologies are model-based estimates; empirical validation against
station data is planned (see `vignette("validation")`).

## Breaking changes

* `degree_days()` gains `method` as its third argument and defaults to
  `"single_sine"`. The previous behaviour (daily average) is
  `method = "average"`. Name `base` explicitly in existing calls.
* `chill_hours()` gains `method` as its third argument; `lower` and `upper`
  must now be named when passed by position.

## New features

* Growing degree-days by the average, single/double sine and single/double
  triangle methods, with horizontal, vertical and intermediate upper cutoffs
  (`degree_days()`), and degree-hours (`degree_hours()`).
* Chilling hours from daily extremes (analytical sine and triangle, numerical
  reference) and counted on hourly data (`chill_hours_hourly()`).
* Utah model chill units (`chill_units()`, `utah_weights()`).
* Dynamic model chill portions with state carried across blocks
  (`chill_portions()`).
* Hourly reconstruction with the Linvill and continuous sine models
  (`hourly_temperatures()`, `daylength()`).
* Monthly-to-daily densification through tempify or a native `pchip_mp`
  engine, with consistency checks and diagnostics (`densify_monthly()`,
  `densify_diagnostics()`, `tempify_available()`, `tempify_version()`).
* Accumulation periods that may cross the year end (`season_days()`).
* `threshold_date()` returns the date on which an accumulated index reaches
  a requirement (for example a degree-day or chill-portion target).
* Progress reporting (blocks, percentage, elapsed time, ETA) in
  `thermify_rast()` and for archive downloads, controlled by `progress` or
  the option `thermify.progress`.
* Integrated workflows for one site (`thermify()`) and for monthly
  `SpatRaster` stacks processed in blocks (`thermify_rast()`), with GeoTIFF,
  NetCDF and provenance output.
* WorldClim 2.1 helpers: `worldclim_region()` reads 30 arc-second normals
  for a region (extent or polygon, optional mask) through HTTP range
  requests on the remote tiles, without downloading global or country
  files; `worldclim_monthly()`, `study_window()`, `check_monthly_climate()`.
* Cauquenes case study in `examples/cauquenes`.

## Verification

* Cross-checks against chillR and degday in
  `inst/verification/verify_references.R`.

## Documentation

* User stories with acceptance tests (`docs/USER_STORIES.md`,
  `tests/testthat/test-story-*.R`) and a testing strategy
  (`docs/TESTING.md`): unit, acceptance, integration and error-path tests,
  397 expectations and 94 % line coverage with all optional groups.
