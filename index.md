# thermify

**Efficient, reproducible and spatially explicit agroclimatic thermal
indices in R.**

`thermify` computes heat and chill accumulation indices from daily or
hourly temperatures, and from monthly climatologies such as WorldClim
after a mean-preserving temporal densification.

| Family | Methods |
|----|----|
| Growing degree-days | average, single sine, single triangle, double sine, double triangle; horizontal, vertical and intermediate upper cutoffs; degree-hours |
| Chilling hours | analytical sine and triangle estimates from daily extremes; counts on hourly data |
| Chill units | Utah model (Richardson et al. 1974) |
| Chill portions | Dynamic model (Fishman et al. 1987; Erez et al. 1990), resumable across blocks |
| Temporal reconstruction | monthly to daily (`pchip_mp`, natively or via [tempify](https://github.com/djwillichile/tempify)); daily to hourly (sine or Linvill) |
| Spatial | block-wise processing of [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html) stacks, GeoTIFF and NetCDF output |

> \[!IMPORTANT\] Monthly climate normals are not daily or hourly
> observations. Indices reconstructed from monthly climatologies are
> model-based estimates and must be validated against observations
> before decision-critical use.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("djwillichile/thermify@v0.1.0")   # release
remotes::install_github("djwillichile/thermify")          # development
```

`terra` is needed for raster workflows. The optional
[tempify](https://github.com/djwillichile/tempify) backend needs Python
and `reticulate`; without it `thermify` uses an equivalent native R
engine.

## Quick start

``` r

library(thermify)

tmin <- c(4, 8, 12, 15)
tmax <- c(16, 22, 28, 34)

# Growing degree-days (degC day)
degree_days(tmin, tmax, method = "single_sine", base = 10)
degree_days(tmin, tmax, method = "single_sine", base = 10, upper = 30,
            cutoff = "vertical")

# Chilling hours estimated from daily extremes (h)
chill_hours(c(-2, 4), c(10, 12), method = "sine")

# Hourly series (observed or reconstructed)
hourly <- hourly_temperatures(rep(3, 30), rep(13, 30), latitude = -35.97,
                              doy = 152:181)
chill_units(hourly, method = "utah", output = "total")
chill_portions(hourly, method = "dynamic", output = "total")
```

From monthly climatology to seasonal indices for one location:

``` r

tmin <- c(11.4, 11.1, 9.2, 6.8, 5.3, 3.9, 3.1, 3.6, 4.6, 6.3, 8.4, 10.3)
tmax <- c(29.6, 29.2, 26.5, 21.9, 17.2, 13.9, 13.6, 15.3, 17.9, 21.2,
          24.9, 28.2)
res <- thermify(tmin, tmax, input = "monthly", latitude = -35.97,
                temporal = "auto", interpolation = "pchip_mp",
                indices = c("gdd", "ch", "cu", "cp"))
res$summary
```

WorldClim 2.1 at 30 arc-seconds can be read for a region only,
transferring just the bytes of that window (optionally masked by a
polygon):

``` r

win  <- study_window(lon = -72.3225, lat = -35.9671, size_km = 20)
tmin <- worldclim_region("tmin", win, path = "data")
tmax <- worldclim_region("tmax", win, path = "data")
```

When does a crop reach its degree-day requirement, or a cultivar its
chill requirement?

``` r

# station: data frame with daily date, tmin, tmax from 1 Sep to 30 Apr
gdd <- degree_days(station$tmin, station$tmax, method = "single_sine",
                   base = 10)
threshold_date(gdd, station$date, threshold = 500)
```

For rasters,
[`thermify_rast()`](https://djwillichile.github.io/thermify/reference/thermify_rast.md)
applies the same workflow block by block to 12-layer `SpatRaster` stacks
and writes one file per index, reporting progress (blocks done, elapsed
time and estimated time remaining).

## Verification

- Unit tests cover every method against closed forms, numerical
  integration, an independent transcription of the Dynamic model
  equations, block equivalence and raster geometry.

- `inst/verification/verify_references.R` cross-checks thermify against
  `chillR` (Dynamic, Utah, chilling hours, day length, Linvill hours)
  and `degday` (UC IPM degree-day formulas). Current differences are
  below 1e-12, except for one documented convention in the pre-dawn
  Linvill curve (`night = "chillr"` reproduces chillR exactly).

- The native `pchip_mp` engine reproduces tempify to within 1e-13 degC.

- About 400 expectations in unit, acceptance (one per [user
  story](https://djwillichile.github.io/thermify/docs/USER_STORIES.md)),
  integration and error-path tests, with 94 % line coverage; see
  [docs/TESTING.md](https://djwillichile.github.io/thermify/docs/TESTING.md).

Computational verification is not empirical validation; see
[`vignette("validation")`](https://djwillichile.github.io/thermify/articles/validation.md)
for the station-based protocol.

## Case study

[`examples/cauquenes`](https://djwillichile.github.io/thermify/examples/cauquenes)
computes all indices for a 20 x 20 km window around Cauquenes (Maule,
Chile) from WorldClim 2.1.

## Documentation

Site: <https://djwillichile.github.io/thermify/>. Articles cover GDD
methods, chill models, the tempify integration, the Cauquenes tutorial
and the validation protocol.

## Citation

``` r

citation("thermify")
```

Please also cite the original publications of the methods you use; they
are listed in each function’s help page.

## License

MIT. Copyright (c) 2026 Guillermo Fuentes-Jaque.
