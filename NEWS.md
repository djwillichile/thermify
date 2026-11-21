# thermify 0.5.1

Prepares the package for CRAN and corrects the station results of the
climate-change article. Computed results of the package functions are
unchanged.

* thermify no longer downloads Python or tempify without the user's
  explicit request (see "Changes").
* The station results of the climate-change article published with 0.5.0
  counted part of the recent warming twice; they are corrected here (see
  "Documentation"). The province results are unchanged.

## Changes

* The automatic installation of the tempify Python backend is now opt-in:
  thermify never downloads Python or tempify unless the user asks for it,
  with `install_tempify()` or with `options(thermify.tempify_auto = TRUE)`
  (or `THERMIFY_TEMPIFY_AUTO=true`) before loading the package. Before, it
  was on by default in interactive sessions. A Python chosen by the user and
  an existing `install_tempify()` environment are used as before, and
  without tempify all computations use the equivalent native R engine. The
  error raised when the tempify engine is requested but unavailable now
  says how to install it.
* When `temporal = "auto"` (or `engine = "auto"`) falls back to the native
  engine because tempify is not installed, a note says, once per session,
  that tempify is optional and how to install it. It is not shown during
  package checks, and `options(thermify.tempify_hint = FALSE)` hides it.

## Documentation

* The climate-change article has a new section with degree-days and chill
  portions through time: the province of Cauquenes (WorldClim historical
  monthly weather 1951-2023 and CMIP6 projections) and the Vicuna station
  (observed seasons and projections), for four scenarios and four periods.
  Each model's trajectory is interpolated through its 20-year period means
  with a monotone spline, and the figure shows the median and likely range
  of the models year by year.
* Correction of the station results of the climate-change article: the
  delta method now applies each model's change from the period of the
  station record (about 2015) to 2041-2060, instead of from 1970-2000, which
  counted the warming already contained in the records twice. The median
  loss of chill portions at the CEAZA-Met stations is 19 % under SSP2-4.5
  and 25 % under SSP5-8.5 (previously reported as 37 % and 42 %).
* The Vicuna panel of that figure adds the WorldClim historical series
  1951-2023 at the station's cell and shows the observed seasons as a
  curve, as relative change from 2005-2023.
* README links to files outside the source package now point to GitHub, and
  the documentation site has a short description and a link-preview image.

# thermify 0.5.0

First release validated against observed hourly temperatures (30 CEAZA-Met
stations), with a change of default that follows from that validation, and
WorldClim CMIP6 projections. Results of `thermify()` and `thermify_rast()`
change only for chilling hours when `ch_methods` is not set (see "Breaking
changes"); all other methods and indices are unchanged.
Archived on Zenodo: <https://doi.org/10.5281/zenodo.24407244>.

The validation covers the semi-arid north-central Chile (Coquimbo and
Atacama regions, from the coast to 2,543 m). It has not yet been repeated in
the central-south: hourly records were requested from INIA, and the
recommendations may need revision for wetter or colder climates.

Not yet included: the Winkler, Huglin and Cool Night viticultural indices.

## Breaking changes

* `thermify()` and `thermify_rast()` now count chilling hours on the hourly
  temperatures by default (`ch_methods = "hourly"`, from observed or
  reconstructed hourly series) instead of the analytical sine estimate
  from daily extremes (`"sine"`). In the CEAZA-Met validation the hourly
  count (Linvill reconstruction) was within 1 % of the observed chilling
  hours, against -9 % for the sine estimate. Results keyed `ch_sine` are
  now `ch_hourly`; set `ch_methods = "sine"` to keep the previous output.
  A note is shown once per session when the default is used (#43).

## New features

* `worldclim_future_region()` reads WorldClim 2.1 downscaled CMIP6
  projections (monthly `tmin`, `tmax`, `prec` at 30 arc-seconds) for a
  region, reading only the bytes of the region from the global files
  (about 5 GB each) and caching the result. `worldclim_cmip6_gcms` lists
  the available global climate models.

## Changes

* `validate_station()` also evaluates degree-days computed on the hourly
  reconstructions from daily extremes (`"hourly_linvill"`,
  `"hourly_sine"`), at the daily, monthly and gridded levels.

## Documentation

* New article "Projected change of thermal indices: WorldClim CMIP6": change
  of degree-days, chilling hours, Utah units and chill portions by
  2041-2060 (14 GCMs, SSP2-4.5 and SSP5-8.5) over the province of Cauquenes,
  and at 29 CEAZA-Met stations with a delta method applied to the
  observed hourly records. Scripts in `data-raw/climate-change/`.
* New article "Validation with observed hourly temperature: CEAZA-Met
  network" with the results of the 30-station validation, per-station
  figures and practical guidance; `vignette("validation")` summarises them.
* `vignette("gdd-methods")` ("Which method?") and the synthetic comparison
  article are updated: the observed stations contradict the synthetic
  ranking of degree-day methods in semi-arid climates.

## Validation

* First empirical validation with observed hourly temperature: 30 stations of
  the CEAZA-Met network (Coquimbo and Atacama regions), with scripts in
  `data-raw/validation-ceaza/`. Only derived seasonal totals and metrics are
  stored in the repository; the hourly records stay with CEAZA.

# thermify 0.4.0

Adds the modified average degree-day method and experimental ensembles of
degree-day methods, and documents a controlled comparison of all methods on
synthetic temperatures. Results of the existing methods are unchanged.
Archived on Zenodo: <https://doi.org/10.5281/zenodo.24385014>.

Not yet included: validation against observed hourly station records (data
requested from CEAZA and INIA, issue #3), and the Winkler and Huglin
viticultural indices.

## New features

* `degree_days()` gains `method = "modified_average"` (McMaster & Wilhelm
  1997, method 2): the daily extremes are bounded by the base and upper
  thresholds before averaging, as in the "86/50" rule for maize. It is also
  available in `thermify()`, `thermify_rast()` and `validate_station()`
  through `gdd_methods`.
* GDD ensembles (experimental): `gdd_ensemble_weights()` estimates the weights of a
  combination of daily GDD methods from `validate_station()` results with
  observed hourly data, by stacking (default), Bayesian model averaging or
  Akaike weights, and assesses it by leave-one-station-out
  cross-validation. `degree_days(method = "ensemble")`, `gdd_ensemble()`
  (weighted mean plus the spread between members) and `gdd_methods =
  "ensemble"` with `gdd_weights` in `thermify()` and `thermify_rast()` apply
  the weights. No default weights are shipped: they depend on the climate,
  the base temperature and the data available.

## Documentation

* New article "Degree-day methods compared on synthetic temperatures": a
  controlled experiment with **synthetic** daily and hourly temperatures
  generated from WorldClim normals at four sites in the Maule Region
  (Parton & Logan diurnal model), comparing every GDD method at the daily,
  monthly and climatological levels. Reproducible with
  `data-raw/gdd-synthetic/run.R`. It complements, and does not replace,
  validation against observed station data. Its figures show the bias of
  each method by level of information and site, and the seasonal bias next
  to the monthly reference degree-days.
* README with an animated demo, a one-line summary, the install command and a
  link to the live Cauquenes example; social preview image
  (`man/figures/social-preview.png`), rebuilt with `data-raw/readme-figures.R`.
* Contributing guide, Contributor Covenant code of conduct, issue forms (bug
  report, feature request) and a pull request template.

# thermify 0.3.1

Prepares the package for a CRAN submission: no Python is downloaded during
package checks or in non-interactive sessions, and the package metadata
cite the methods with DOIs. Results are unchanged. Archived on Zenodo:
<https://doi.org/10.5281/zenodo.23937033>.

## Changes

* The automatic tempify set-up now runs only in interactive sessions and
  never while a package is being checked; in scripts, enable it with
  `THERMIFY_TEMPIFY_AUTO=true`. A Python chosen by the user and the
  `"r-thermify"` environment of `install_tempify()` are always used.
* `tempify_available()` no longer starts Python when none is configured,
  so recent versions of 'reticulate' do not download one to answer it.

## Documentation

* `DESCRIPTION` cites the methods with DOIs and includes the maintainer's
  ORCID; `Language: en-GB` and a word list for spell checks.
* Network examples write to `tempdir()`; `cran-comments.md` documents the
  network and Python behaviour for a CRAN submission.

# thermify 0.3.0

Adds plot() and print() methods for raster results, sets up the tempify
backend automatically, and turns the Cauquenes tutorial into a worked
example with computed results for the whole province. Archived on Zenodo:
<https://doi.org/10.5281/zenodo.23922611>.

## Breaking changes

* `thermify_rast()` returns an object of class `"thermify_rast"` instead of
  a plain list. It is still a named list of `SpatRaster`, so `x$cp_dynamic`,
  `names(x)` and `lapply(x, ...)` work as before; only code that tests the
  class exactly (for example `identical(class(x), "list")`) is affected.

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
  are left out. Default palettes are multi-hue sequential (`YlOrRd`,
  `YlGnBu`, `BuPu`, `YlGn`), Utah units crossing zero use a diverging
  palette centred on zero, and `col` accepts any `hcl.colors()` palette
  name such as `"Spectral"`.
* tempify is set up automatically. With `reticulate` (>= 1.41) thermify
  declares it with `reticulate::py_require()` on load, and the first use of
  the tempify engine builds and caches a Python environment with it.
  `install_tempify()` creates a persistent environment `"r-thermify"`
  instead, which is then used on load. A Python chosen by the user is
  respected; `options(thermify.tempify_auto = FALSE)` or
  `THERMIFY_TEMPIFY_AUTO=false` disables the setup.
* `tempify_version()` records the tempify git commit also when tempify was
  installed from a git URL (PEP 610 `direct_url.json`).

## Documentation

* `vignette("cauquenes")` is evaluated when the documentation site is built
  and shows results for the whole province of Cauquenes (4,554 WorldClim
  2.1 cells at 30 arc-seconds): climatology, seasonal indices for the town,
  maps drawn with `plot()`, the annual cycle month by month, spatial
  statistics and method differences. Package checks still show the code
  only, with a link to the site.
* `vignette("tempify-integration")` explains how tempify is installed.

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
