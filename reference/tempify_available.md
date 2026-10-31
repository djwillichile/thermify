# Is the tempify Python package available?

Checks that `reticulate` is installed and that the active Python
environment can import `tempify`. Use
[`reticulate::use_virtualenv()`](https://rstudio.github.io/reticulate/reference/use_python.html)
or the `RETICULATE_PYTHON` environment variable to select the
environment.

## Usage

``` r
tempify_available()
```

## Value

`TRUE` or `FALSE`.
