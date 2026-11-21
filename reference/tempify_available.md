# Is the tempify Python package available?

Checks that `reticulate` is installed and that the active Python
environment can import `tempify`. Python is not started, and nothing is
downloaded, unless a Python was chosen by the user, the environment of
[`install_tempify()`](https://djwillichile.github.io/thermify/reference/install_tempify.md)
exists, or the automatic setup was enabled with
`options(thermify.tempify_auto = TRUE)`; see
[`install_tempify()`](https://djwillichile.github.io/thermify/reference/install_tempify.md).

## Usage

``` r
tempify_available()
```

## Value

`TRUE` or `FALSE`.
