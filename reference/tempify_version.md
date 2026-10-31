# Version information of the tempify backend

Returns the tempify version, the git commit of its source tree when it
is installed from a git checkout, and the Python, NumPy and xarray
versions. Recorded in the provenance of every densification for
reproducibility.

## Usage

``` r
tempify_version()
```

## Value

A named list, or `NULL` when tempify is not available.
