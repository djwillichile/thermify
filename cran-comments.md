## Submission

This is a new submission.

## Test environments

* GitHub Actions: Ubuntu (R release and oldrel-1), Windows (R release),
  macOS (R release).
* Local: Ubuntu, R release.

## R CMD check results

0 errors | 0 warnings | 1 note

* New submission.

## Notes for the CRAN team

* Network access. `worldclim_region()` and `worldclim_monthly()` download
  WorldClim 2.1 data, so their examples are wrapped in `\dontrun{}` and the
  tests that read remote data run only when `THERMIFY_ONLINE_TESTS=true`.
  The vignettes show code only during package checks; they are evaluated
  when the documentation website is built.
* Python. The optional 'tempify' backend is a Python package reached
  through 'reticulate' (in Suggests). It is never installed or downloaded
  during checks or in non-interactive sessions: the automatic set-up runs
  only in interactive sessions and outside `R CMD check`, and
  `tempify_available()` does not start Python unless one has been
  configured. Without Python, all computations use an equivalent native R
  engine. `install_tempify()` installs software and its example is
  therefore wrapped in `\dontrun{}`.
* Files written by the package go only to the directories given by the
  user (`output_dir`, `path`) or to `tempdir()` in examples, tests and
  vignettes.
