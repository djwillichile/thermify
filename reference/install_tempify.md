# Install the tempify Python backend

Creates (or updates) a persistent Python virtual environment with the
[tempify](https://github.com/djwillichile/tempify) package, which
thermify then uses automatically in every session.

## Usage

``` r
install_tempify(
  envname = tempify_envname(),
  requirement = tempify_requirement(),
  python_version = ">=3.10",
  restart_message = TRUE
)
```

## Arguments

- envname:

  Name of the virtual environment.

- requirement:

  pip requirement for tempify. The default installs the current version
  from GitHub; a tag can be pinned, for example
  `"tempify @ git+https://github.com/djwillichile/tempify@v0.1.6"`.

- python_version:

  Python version used to create the environment when it does not exist,
  passed to
  [`reticulate::virtualenv_starter()`](https://rstudio.github.io/reticulate/reference/virtualenv-tools.html).

- restart_message:

  Print the instructions to restart R?

## Value

The path of the environment's Python, invisibly.

## Details

You rarely need this function. With `reticulate` (\>= 1.41) installed,
thermify declares tempify when it is loaded, and the first time the
tempify engine is used reticulate builds and caches a Python environment
with it (this takes one or two minutes and downloads about 100 MB once).
`install_tempify()` is the alternative when that automatic route is not
available (older `reticulate`) or when you prefer a named, persistent
environment.

The automatic setup is skipped when you have already chosen a Python
(`RETICULATE_PYTHON`,
[`reticulate::use_python()`](https://rstudio.github.io/reticulate/reference/use_python.html)
and similar). Disable it with `options(thermify.tempify_auto = FALSE)`
before loading thermify, or with the environment variable
`THERMIFY_TEMPIFY_AUTO=false`.

Installing from GitHub needs `git` on the system path.

## See also

[`tempify_available()`](https://djwillichile.github.io/thermify/reference/tempify_available.md),
[`tempify_version()`](https://djwillichile.github.io/thermify/reference/tempify_version.md)

## Examples

``` r
if (FALSE) { # \dontrun{
install_tempify()
# restart R, then
library(thermify)
tempify_available()
} # }
```
