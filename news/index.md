# Changelog

## thermify (development version)

## thermify 0.1.0

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
