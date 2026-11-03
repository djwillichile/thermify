# Is the tempify Python package available?

Checks that `reticulate` is installed and that the active Python
environment can import `tempify`. With `reticulate` (\>= 1.41), thermify
declares tempify when it is loaded, so the first call builds and caches
a Python environment with it; see
[`install_tempify()`](https://djwillichile.github.io/thermify/reference/install_tempify.md)
for the alternatives and how to disable this. A Python chosen with
`RETICULATE_PYTHON` or
[`reticulate::use_virtualenv()`](https://rstudio.github.io/reticulate/reference/use_python.html)
is respected.

## Usage

``` r
tempify_available()
```

## Value

`TRUE` or `FALSE`.
