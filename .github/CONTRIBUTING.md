# Contributing to thermify

Thanks for your interest in thermify! Contributions of every size are
welcome: a typo fix, a clearer example, a bug report with a reproducible
case, a new index or a validation against station data.

## Ways to help

* **Report a bug** with the *Bug report* template. A minimal reproducible
  example (a few lines of R that anyone can run) is the most useful thing you
  can give.
* **Suggest a feature** with the *Feature request* template: say what you
  want to compute, for which crop or region, and which reference describes the
  method.
* **Ask a question** in [Discussions](https://github.com/djwillichile/thermify/discussions)
  rather than in an issue.
* **Pick an issue** labelled
  [`good first issue`](https://github.com/djwillichile/thermify/labels/good%20first%20issue):
  they are small, self-contained and described step by step.

## Development set-up

```r
# install.packages(c("devtools", "testthat", "roxygen2"))
# clone https://github.com/djwillichile/thermify and open the project, then:
devtools::install_deps(dependencies = TRUE)
devtools::load_all()
devtools::test()
```

Optional test groups (network reads, the tempify backend, reference
implementations) are described in [`docs/TESTING.md`](../docs/TESTING.md).

## Making a change

1. Open an issue first for anything larger than a small fix, so we can agree
   on the approach.
2. Create a branch from `main` named `code/<short-description>`.
3. Keep the change focused. Add or update tests in `tests/testthat/` for any
   change in behaviour: every method in thermify is tested against closed
   forms, numerical integration or an independent implementation, and new
   code should follow that standard.
4. Document functions with roxygen2 (`#'` comments) and run
   `devtools::document()`.
5. Add a bullet to the top section of `NEWS.md`.
6. Run `devtools::check()` and make sure it passes without errors or
   warnings.
7. Open a pull request. The CI runs `R CMD check` on Linux, Windows and
   macOS plus the full test battery; please make sure it is green.

## Style

* Code follows the [tidyverse style guide](https://style.tidyverse.org/):
  two-space indent, `snake_case`, lines up to 80 characters.
* Functions from other packages are called with `pkg::fun()` inside the
  package.
* Methods cite their original publication in `@references`.
* Messages, documentation and code are written in English; issues and
  discussions may be in English or Spanish.

## Scientific changes

thermify computes quantities that people use to make decisions. A change that
alters numerical results must explain why, cite the source of the method and
include a test that reproduces a published or independently computed value.

## Code of conduct

Please note that this project is released with a
[Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating you agree
to abide by its terms.
