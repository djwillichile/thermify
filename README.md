# thermify

**Fast agroclimatic thermal indices in R.**

`thermify` computes growing degree days (GDD) and estimates chilling hours.
Its development roadmap includes efficient WorldClim raster processing, optional
interpolation with [`tempify`](https://github.com/djwillichile/tempify), and phenological applications.

> [!IMPORTANT]
> Monthly climate normals are not daily or hourly observations. Thermal indices
> reconstructed from monthly climatologies are model-based estimates and should
> be validated against observations for decision-critical applications.

## Installation from source

```r
install.packages("remotes")
remotes::install_github("djwillichile/thermify")
library(thermify)
```

## Quick start

```r
degree_days(c(5, 10), c(15, 20), base = 10)
chill_hours(c(-2, 4), c(10, 12), lower = 0, upper = 7.2)
```

The initial functions expect **daily** minimum and maximum temperatures.
Monthly WorldClim processing is planned and is not yet implemented.

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md) for validation, raster processing,
temporal interpolation, performance benchmarks and phenological extensions.

## License

MIT. Copyright © 2026 Guillermo Fuentes-Jaque.
