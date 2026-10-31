# thermify 0.0.0.9000 (development version)

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
* Integrated workflows for one site (`thermify()`) and for monthly
  `SpatRaster` stacks processed in blocks (`thermify_rast()`), with GeoTIFF,
  NetCDF and provenance output.
* WorldClim 2.1 helpers (`worldclim_monthly()`, `study_window()`,
  `check_monthly_climate()`).
* Cauquenes case study in `examples/cauquenes`.

## Verification

* Cross-checks against chillR and degday in
  `inst/verification/verify_references.R`.
