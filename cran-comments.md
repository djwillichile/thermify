## Submission

This is a new submission.

## Test environments

* GitHub Actions: Ubuntu (R release and oldrel-1), Windows (R release),
  macOS (R release).
* Local: Ubuntu 24.04, R release, `R CMD check --as-cran`.

## R CMD check results

0 errors | 0 warnings | 1 note

* New submission.

## Notes for the CRAN team

* Network access. `worldclim_monthly()`, `worldclim_region()` and
  `worldclim_future_region()` download WorldClim 2.1 data (current
  climate and downscaled CMIP6 projections). Their examples are wrapped in
  `\dontrun{}`, and the tests that read remote data run only when
  `THERMIFY_ONLINE_TESTS=true`. `worldclim_region()` and
  `worldclim_future_region()` read only the bytes of the requested region
  from the remote files instead of downloading the global files.
* Vignettes. The vignettes that need WorldClim data show their code
  without evaluating it during package checks; they are evaluated when
  the documentation website is built. The remaining vignettes run offline
  with small synthetic inputs.
* Python. The optional 'tempify' backend is a Python package reached
  through 'reticulate' (in Suggests). The package never installs or
  downloads Python or 'tempify' unless the user asks for it explicitly,
  either by calling `install_tempify()` or by setting
  `options(thermify.tempify_auto = TRUE)` (or `THERMIFY_TEMPIFY_AUTO=true`)
  before loading the package; this holds in interactive and
  non-interactive sessions alike. `tempify_available()` does not start
  Python unless one has been configured. Without Python, all computations
  use an equivalent native R engine (results agree to within 1e-13).
  `install_tempify()` installs software and its example is therefore
  wrapped in `\dontrun{}`.
* Files. Files written by the package go only to the directories given by
  the user (`output_dir`, and `path`, which has no default) or to
  `tempdir()` in examples, tests and vignettes.
* Messages. When `thermify()` or `thermify_rast()` is called without
  `ch_methods`, a note about a change of default is shown once per
  session with `message()`, so it can be suppressed.
