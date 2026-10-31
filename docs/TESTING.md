# Testing strategy

thermify is tested at four levels. Together they cover each stage of the
workflow: input validation, monthly-to-daily densification, hourly
reconstruction, index computation, temporal aggregation, spatial block
processing, file output and provenance.

| Level | Files | What it shows |
|---|---|---|
| Unit | `test-degree-days.R`, `test-chill-*.R`, `test-hourly.R`, `test-densify.R`, `test-periods.R`, `test-thermify.R`, `test-rast.R`, `test-worldclim.R` | Each method reproduces closed forms, numerical integration or an independent transcription of the published equations; edge cases and missing values. |
| Acceptance | `test-story-01.R` ... `test-story-10.R` | Each user story in [`USER_STORIES.md`](USER_STORIES.md) meets its acceptance criteria. |
| Integration | `test-integration.R` | The stages fit together: layers on disk add up (months to year and season), NetCDF equals GeoTIFF, block size does not change results, tempify and native engines agree on rasters, multi-season series restart the Dynamic model, and the case-study script runs end to end. |
| Error paths | `test-errors.R` | Invalid input is rejected with informative messages instead of producing numbers. |

## Running the tests

```r
devtools::test()          # default: no network, no Python required
```

Optional groups are enabled with environment variables; when not set they
are skipped with an explicit message:

| Variable | Enables |
|---|---|
| `RETICULATE_PYTHON` | tempify engine tests (Python environment with tempify) |
| `THERMIFY_ONLINE_TESTS=true` | network reads of WorldClim 2.1 with `worldclim_region()` |
| `CHILLR_SRC`, `DEGDAY_SRC` | regression against chillR and degday (paths to source checkouts of https://github.com/cran/chillR and https://github.com/cran/degday) |
| `THERMIFY_SLOW_TESTS=true` | the Cauquenes script in synthetic smoke mode (about 30 s) |
| `NOT_CRAN=true` | tests skipped on CRAN (set automatically by `devtools::test()`) |

The CI job `full tests` sets all of them and fails if any test is skipped.

## Current status

With every group enabled: 397 expectations, 0 failures, 0 warnings,
0 skipped; line coverage 93.6 % (`covr::package_coverage()`).

| File | Coverage |
|---|---|
| chill_hours, chill_portions, chill_units, engine, hourly, profiles, threshold, utils-validate | 100 % |
| thermify, thermify_rast, progress, degree_days, densify, periods | 95-98 % |
| worldclim | 68 % |

## Known gaps

* `worldclim_monthly()` (global 2.5-10 arc-minute archives, about 0.45 GB
  per variable) is not exercised by the tests because of download size. It
  was exercised manually by the first Cauquenes run (2.5' archives and the
  30" `CHL` tile).
* Some messages only reachable when tempify is installed but broken, and the
  `commit = NA` path of `tempify_version()` for non-git installations.
* Tests verify implementations against equations and reference software
  (computational verification). They do not validate the models against
  observations; see `vignette("validation")`.
