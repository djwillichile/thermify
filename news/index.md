# Changelog

## thermify (development version)

### Changes

- The automatic tempify set-up now runs only in interactive sessions and
  never while a package is being checked; in scripts, enable it with
  `THERMIFY_TEMPIFY_AUTO=true`. A Python chosen by the user and the
  `"r-thermify"` environment of
  [`install_tempify()`](https://djwillichile.github.io/thermify/reference/install_tempify.md)
  are always used.
- [`tempify_available()`](https://djwillichile.github.io/thermify/reference/tempify_available.md)
  no longer starts Python when none is configured, so recent versions of
  ‘reticulate’ do not download one to answer it.

### Documentation

- `DESCRIPTION` cites the methods with DOIs and includes the
  maintainer’s ORCID; `Language: en-GB` and a word list for spell
  checks.
- Network examples write to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html);
  `cran-comments.md` documents the network and Python behaviour for a
  CRAN submission.

## thermify 0.3.0

Adds plot() and print() methods for raster results, sets up the tempify
backend automatically, and turns the Cauquenes tutorial into a worked
example with computed results for the whole province. Archived on
Zenodo: <https://doi.org/10.5281/zenodo.23922611>.

### Breaking changes

- [`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)
  returns an object of class `"thermify_rast"` instead of a plain list.
  It is still a named list of `SpatRaster`, so `x$cp_dynamic`,
  `names(x)` and `lapply(x, ...)` work as before; only code that tests
  the class exactly (for example `identical(class(x), "list")`) is
  affected.

### New features

- [`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)
  returns an object of class `"thermify_rast"` (still a named list of
  `SpatRaster`) with a
  [`plot()`](https://rspatial.github.io/terra/reference/plot.html)
  method: `variable` selects indices or families, `type` the layer
  (`"season"`, `"annual"`, `"monthly"` or months such as `"m07"`),
  `nrow`/`ncol` the layout, plus `col`, `boundary`, a common or
  per-panel colour scale and `titles`; and a
  [`print()`](https://rdrr.io/r/base/print.html) method that summarises
  indices, units, layers and files. Titles that do not fit in a panel
  are wrapped onto several lines; a single index shown month by month
  gets short titles (month and units) with the index name above the
  panels; months without data (outside the chill period) are left out.
  Default palettes are multi-hue sequential (`YlOrRd`, `YlGnBu`, `BuPu`,
  `YlGn`), Utah units crossing zero use a diverging palette centred on
  zero, and `col` accepts any
  [`hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html) palette
  name such as `"Spectral"`.
- tempify is set up automatically. With `reticulate` (\>= 1.41) thermify
  declares it with
  [`reticulate::py_require()`](https://rstudio.github.io/reticulate/reference/py_require.html)
  on load, and the first use of the tempify engine builds and caches a
  Python environment with it.
  [`install_tempify()`](https://djwillichile.github.io/thermify/reference/install_tempify.md)
  creates a persistent environment `"r-thermify"` instead, which is then
  used on load. A Python chosen by the user is respected;
  `options(thermify.tempify_auto = FALSE)` or
  `THERMIFY_TEMPIFY_AUTO=false` disables the setup.
- [`tempify_version()`](https://djwillichile.github.io/thermify/reference/tempify_version.md)
  records the tempify git commit also when tempify was installed from a
  git URL (PEP 610 `direct_url.json`).

### Documentation

- [`vignette("cauquenes")`](https://djwillichile.github.io/thermify/articles/cauquenes.md)
  is evaluated when the documentation site is built and shows results
  for the whole province of Cauquenes (4,554 WorldClim 2.1 cells at 30
  arc-seconds): climatology, seasonal indices for the town, maps drawn
  with [`plot()`](https://rspatial.github.io/terra/reference/plot.html),
  the annual cycle month by month, spatial statistics and method
  differences. Package checks still show the code only, with a link to
  the site.
- [`vignette("tempify-integration")`](https://djwillichile.github.io/thermify/articles/tempify-integration.md)
  explains how tempify is installed.

## thermify 0.2.0

Adds the tools for empirical validation against station records, the
official DPA 2023 boundaries of Cauquenes, and attaches `terra` with the
package. Validation results with real stations
([\#3](https://github.com/djwillichile/thermify/issues/3)) are not part
of this release. Archived on Zenodo:
<https://doi.org/10.5281/zenodo.23905378>.

### Breaking changes

- `terra` is now a dependency (`Depends`) instead of a suggested
  package: installing thermify installs terra, and
  [`library(thermify)`](https://github.com/djwillichile/thermify)
  attaches it, so
  [`vect()`](https://rspatial.github.io/terra/reference/vect.html),
  [`rast()`](https://rspatial.github.io/terra/reference/rast.html),
  [`plot()`](https://rspatial.github.io/terra/reference/plot.html) and
  the other `terra` functions are available without `terra::`. On Linux,
  terra needs the GDAL, GEOS and PROJ system libraries.

### New features

- `cauquenes` dataset: official DPA 2023 boundaries of the Cauquenes
  commune and province (packed `SpatVector`, EPSG:5360), replacing the
  undocumented `cauquenes.gpkg` referenced in earlier documentation.
- [`cauquenes_boundary()`](https://djwillichile.github.io/thermify/reference/cauquenes_boundary.md)
  returns one or both levels as a `SpatVector`, optionally projected
  (`crs`).
- Station validation
  ([\#3](https://github.com/djwillichile/thermify/issues/3)):
  [`prepare_station_hourly()`](https://djwillichile.github.io/thermify/reference/prepare_station_hourly.md)
  regularises hourly records, fills short gaps and flags incomplete
  days;
  [`validate_station()`](https://djwillichile.github.io/thermify/reference/validate_station.md)
  compares indices observed on hourly data with estimates from daily
  extremes, from the station’s densified monthly climatology and,
  optionally, from a gridded climatology;
  [`validation_metrics()`](https://djwillichile.github.io/thermify/reference/validation_metrics.md)
  returns bias, MAE, RMSE, relative bias and correlation. The protocol
  is tested on synthetic records; results with real stations are
  pending.

### Documentation

- The `cauquenes` dataset cites its source (SUBDERE, DPA 2023) and
  carries the DIFROL circulation notice (Resolución Nº 87 de 2023).
- [`vignette("validation")`](https://djwillichile.github.io/thermify/articles/validation.md)
  documents the implementation; examples, the Cauquenes tutorial and the
  README use
  [`cauquenes_boundary()`](https://djwillichile.github.io/thermify/reference/cauquenes_boundary.md)
  and bare `terra` calls.
- Release and development version badges in the README and the site.

## thermify 0.1.0

Archived on Zenodo: <https://doi.org/10.5281/zenodo.23841857>.

First release. Functional, documented and tested package for
agroclimatic thermal indices: growing degree-days, chilling hours, Utah
chill units and Dynamic model chill portions, from hourly, daily or
monthly temperatures, for single sites and rasters.

Verified on Ubuntu (R release and oldrel), Windows and macOS. Results
based on monthly climatologies are model-based estimates; empirical
validation against station data is planned (see
[`vignette("validation")`](https://djwillichile.github.io/thermify/articles/validation.md)).

### Breaking changes

- [`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)
  gains `method` as its third argument and defaults to `"single_sine"`.
  The previous behaviour (daily average) is `method = "average"`. Name
  `base` explicitly in existing calls.
- [`chill_hours()`](https://djwillichile.github.io/thermify/reference/chill_hours.md)
  gains `method` as its third argument; `lower` and `upper` must now be
  named when passed by position.

### New features

- Growing degree-days by the average, single/double sine and
  single/double triangle methods, with horizontal, vertical and
  intermediate upper cutoffs
  ([`degree_days()`](https://djwillichile.github.io/thermify/reference/degree_days.md)),
  and degree-hours
  ([`degree_hours()`](https://djwillichile.github.io/thermify/reference/degree_hours.md)).
- Chilling hours from daily extremes (analytical sine and triangle,
  numerical reference) and counted on hourly data
  ([`chill_hours_hourly()`](https://djwillichile.github.io/thermify/reference/chill_hours_hourly.md)).
- Utah model chill units
  ([`chill_units()`](https://djwillichile.github.io/thermify/reference/chill_units.md),
  [`utah_weights()`](https://djwillichile.github.io/thermify/reference/utah_weights.md)).
- Dynamic model chill portions with state carried across blocks
  ([`chill_portions()`](https://djwillichile.github.io/thermify/reference/chill_portions.md)).
- Hourly reconstruction with the Linvill and continuous sine models
  ([`hourly_temperatures()`](https://djwillichile.github.io/thermify/reference/hourly_temperatures.md),
  [`daylength()`](https://djwillichile.github.io/thermify/reference/daylength.md)).
- Monthly-to-daily densification through tempify or a native `pchip_mp`
  engine, with consistency checks and diagnostics
  ([`densify_monthly()`](https://djwillichile.github.io/thermify/reference/densify_monthly.md),
  [`densify_diagnostics()`](https://djwillichile.github.io/thermify/reference/densify_diagnostics.md),
  [`tempify_available()`](https://djwillichile.github.io/thermify/reference/tempify_available.md),
  [`tempify_version()`](https://djwillichile.github.io/thermify/reference/tempify_version.md)).
- Accumulation periods that may cross the year end
  ([`season_days()`](https://djwillichile.github.io/thermify/reference/season_days.md)).
- [`threshold_date()`](https://djwillichile.github.io/thermify/reference/threshold_date.md)
  returns the date on which an accumulated index reaches a requirement
  (for example a degree-day or chill-portion target).
- Progress reporting (blocks, percentage, elapsed time, ETA) in
  [`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)
  and for archive downloads, controlled by `progress` or the option
  `thermify.progress`.
- Integrated workflows for one site
  ([`thermify()`](https://djwillichile.github.io/thermify/reference/thermify.md))
  and for monthly `SpatRaster` stacks processed in blocks
  ([`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)),
  with GeoTIFF, NetCDF and provenance output.
- WorldClim 2.1 helpers:
  [`worldclim_region()`](https://djwillichile.github.io/thermify/reference/worldclim_region.md)
  reads 30 arc-second normals for a region (extent or polygon, optional
  mask) through HTTP range requests on the remote tiles, without
  downloading global or country files;
  [`worldclim_monthly()`](https://djwillichile.github.io/thermify/reference/worldclim_monthly.md),
  [`study_window()`](https://djwillichile.github.io/thermify/reference/study_window.md),
  [`check_monthly_climate()`](https://djwillichile.github.io/thermify/reference/check_monthly_climate.md).
- Cauquenes case study in `examples/cauquenes`.

### Verification

- Cross-checks against chillR and degday in
  `inst/verification/verify_references.R`.

### Documentation

- User stories with acceptance tests (`docs/USER_STORIES.md`,
  `tests/testthat/test-story-*.R`) and a testing strategy
  (`docs/TESTING.md`): unit, acceptance, integration and error-path
  tests, 397 expectations and 94 % line coverage with all optional
  groups.
