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

thermify never downloads Python or tempify unless you ask for it. There
are two ways to do so:

- `install_tempify()` creates a named, persistent environment once;
  thermify uses it in every later session.

- The automatic route: with `reticulate` (\>= 1.41), set
  `options(thermify.tempify_auto = TRUE)` or the environment variable
  `THERMIFY_TEMPIFY_AUTO=true` before loading thermify. thermify then
  declares tempify with
  [`reticulate::py_require()`](https://rstudio.github.io/reticulate/reference/py_require.html),
  and the first time the tempify engine is used reticulate builds and
  caches a Python environment with it (one or two minutes and about 100
  MB, once).

Both are skipped when you have already chosen a Python
(`RETICULATE_PYTHON`,
[`reticulate::use_python()`](https://rstudio.github.io/reticulate/reference/use_python.html)
and similar), which is used as is. Without tempify, thermify uses an
equivalent native R engine; the first time that happens in a session
with `temporal = "auto"` (or `engine = "auto"`), a note says how to
install tempify. Hide it with `options(thermify.tempify_hint = FALSE)`.

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
