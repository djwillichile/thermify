# Download (or reuse) WorldClim 2.1 monthly temperature normals

Returns the 12 monthly layers of WorldClim 2.1 (1970-2000 normals) for
`tmin` or `tmax`, in degrees Celsius. Files are cached in `path` and are
not downloaded again when a valid copy exists. The `geodata` package is
used when installed; otherwise the files are downloaded directly from
the same server.

## Usage

``` r
worldclim_monthly(
  var = c("tmin", "tmax"),
  res = 2.5,
  path,
  country = NULL,
  timeout = 3600,
  progress = getOption("thermify.progress", interactive())
)
```

## Arguments

- var:

  `"tmin"` or `"tmax"`.

- res:

  Resolution in arc-minutes: 10, 5, 2.5 or 0.5.

- path:

  Cache directory.

- country:

  ISO3 code, required for `res = 0.5`.

- timeout:

  Download timeout in seconds.

- progress:

  Show the download progress bar. Defaults to the option
  `thermify.progress`, or `TRUE` in interactive sessions.

## Value

A 12-layer `SpatRaster` with layers named `m01` to `m12`.

## Details

Global files are used for `res` 10, 5 and 2.5 arc-minutes. For 30
arc-seconds (`res = 0.5`) a `country` ISO3 code is required and the
country tile is downloaded (for Chile, `"CHL"`).

## References

Fick, S. E., & Hijmans, R. J. (2017). WorldClim 2: new 1-km spatial
resolution climate surfaces for global land areas. *International
Journal of Climatology*, 37(12), 4302-4315.
