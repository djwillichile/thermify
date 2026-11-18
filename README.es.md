# thermify <img src="man/figures/logo.png" align="right" height="139" alt="thermify logo" />

<!-- badges: start -->
[![GitHub release](https://img.shields.io/github/v/release/djwillichile/thermify?label=release)](https://github.com/djwillichile/thermify/releases/latest)
[![Development version](https://img.shields.io/github/r-package/v/djwillichile/thermify?label=devel)](https://github.com/djwillichile/thermify/blob/main/DESCRIPTION)
[![R-CMD-check](https://github.com/djwillichile/thermify/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/djwillichile/thermify/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23841856.svg)](https://doi.org/10.5281/zenodo.23841856)
<!-- badges: end -->

[English](README.md)

**Índices térmicos agroclimáticos eficientes, reproducibles y espacialmente
explícitos en R.**

`thermify` calcula índices de acumulación de calor y de frío a partir de
temperaturas diarias u horarias, y de climatologías mensuales como WorldClim,
tras una densificación temporal que preserva la media.

| Familia | Métodos |
|---|---|
| Grados-día de crecimiento | promedio, seno simple, triángulo simple, seno doble, triángulo doble; umbrales superiores horizontal, vertical e intermedio; grados-hora |
| Horas de frío | estimaciones analíticas con seno y triángulo a partir de los extremos diarios; conteos con datos horarios |
| Unidades de frío | modelo Utah (Richardson et al. 1974) |
| Porciones de frío | modelo dinámico (Fishman et al. 1987; Erez et al. 1990), reanudable entre bloques |
| Reconstrucción temporal | de mensual a diario (`pchip_mp`, de forma nativa o mediante [tempify](https://github.com/djwillichile/tempify)); de diario a horario (seno o Linvill) |
| Espacial | procesamiento por bloques de pilas `terra::SpatRaster`, salida en GeoTIFF y NetCDF; lecturas regionales de WorldClim 2.1; límites oficiales DPA 2023 de Cauquenes (`cauquenes_boundary()`) |

> [!IMPORTANT]
> Las normales climáticas mensuales no son observaciones diarias ni horarias.
> Los índices reconstruidos a partir de climatologías mensuales son
> estimaciones basadas en modelos y deben validarse con observaciones antes de
> usarse en decisiones críticas.

## Instalación

```r
# install.packages("remotes")
remotes::install_github("djwillichile/thermify@v0.3.1")   # release
remotes::install_github("djwillichile/thermify")          # development
```

`library(thermify)` también adjunta `terra`, por lo que `rast()`, `vect()`,
`plot()` y las demás funciones de `terra` quedan disponibles directamente. El
backend opcional [tempify](https://github.com/djwillichile/tempify) se
configura automáticamente en sesiones interactivas cuando `reticulate`
(>= 1.41) está instalado: el primer uso construye y guarda en caché un entorno
de Python con él (véase `install_tempify()` para un entorno persistente). Sin
él, `thermify` usa un motor nativo en R equivalente.

## Inicio rápido

```r
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

De la climatología mensual a los índices estacionales para un punto:

```r
tmin <- c(11.4, 11.1, 9.2, 6.8, 5.3, 3.9, 3.1, 3.6, 4.6, 6.3, 8.4, 10.3)
tmax <- c(29.6, 29.2, 26.5, 21.9, 17.2, 13.9, 13.6, 15.3, 17.9, 21.2,
          24.9, 28.2)
res <- thermify(tmin, tmax, input = "monthly", latitude = -35.97,
                temporal = "auto", interpolation = "pchip_mp",
                indices = c("gdd", "ch", "cu", "cp"))
res$summary
```

WorldClim 2.1 a 30 segundos de arco puede leerse solo para una región,
transfiriendo únicamente los bytes de esa ventana (opcionalmente recortada con
un polígono):

```r
win  <- study_window(lon = -72.3225, lat = -35.9671, size_km = 20)
tmin <- worldclim_region("tmin", win, path = "data")
tmax <- worldclim_region("tmax", win, path = "data")

# Official DPA 2023 boundary of the Cauquenes commune, as a mask
comuna <- cauquenes_boundary("comuna")        # or "provincia"
tmin_c <- worldclim_region("tmin", comuna, path = "data", mask = TRUE)
```

¿Cuándo alcanza un cultivo su requerimiento de grados-día, o un cultivar su
requerimiento de frío?

```r
# station: data frame with daily date, tmin, tmax from 1 Sep to 30 Apr
gdd <- degree_days(station$tmin, station$tmax, method = "single_sine",
                   base = 10)
threshold_date(gdd, station$date, threshold = 500)
```

Para datos ráster, `thermify_rast()` aplica el mismo flujo de trabajo bloque
por bloque a pilas `SpatRaster` de 12 capas y escribe un archivo por índice,
informando el avance (bloques procesados, tiempo transcurrido y tiempo
restante estimado).

## Verificación

* Las pruebas unitarias cubren cada método frente a formas cerradas,
  integración numérica, una transcripción independiente de las ecuaciones del
  modelo dinámico, la equivalencia entre bloques y la geometría ráster.
* `inst/verification/verify_references.R` contrasta thermify con `chillR`
  (modelo dinámico, Utah, horas de frío, duración del día, horas de Linvill) y
  `degday` (fórmulas de grados-día de UC IPM). Las diferencias actuales son
  inferiores a 1e-12, salvo una convención documentada en la curva de Linvill
  previa al amanecer (`night = "chillr"` reproduce chillR exactamente).
* El motor nativo `pchip_mp` reproduce tempify con una diferencia de hasta
  1e-13 degC.

* Cerca de 400 expectativas en pruebas unitarias, de aceptación (una por
  [historia de usuario](docs/USER_STORIES.md)), de integración y de rutas de
  error, con 94 % de cobertura de líneas; véase
  [docs/TESTING.md](docs/TESTING.md).

La verificación computacional no es validación empírica; véase
`vignette("validation")` para el protocolo basado en estaciones.

## Caso de estudio

[`examples/cauquenes`](examples/cauquenes) calcula todos los índices para una
ventana de 20 x 20 km alrededor de Cauquenes (Maule, Chile) a partir de
WorldClim 2.1.

## Documentación

Sitio: <https://djwillichile.github.io/thermify/>. Los artículos cubren los
métodos de GDD, los modelos de frío, la integración con tempify, el tutorial de
Cauquenes y el protocolo de validación.

## Cita

```r
citation("thermify")
```

> Fuentes-Jaque, G. (2026). *thermify: Efficient Agroclimatic Thermal
> Indices* [R package]. Zenodo. https://doi.org/10.5281/zenodo.23841856

Este DOI siempre apunta a la última versión. Para citar una versión
específica, use su propio DOI del [registro de Zenodo](https://doi.org/10.5281/zenodo.23841856)
(por ejemplo, v0.3.0: 10.5281/zenodo.23922611) y la versión que indica
`packageVersion("thermify")`.

Cite también las publicaciones originales de los métodos que utilice; figuran
en la página de ayuda de cada función.

## Licencia

MIT. Copyright (c) 2026 Guillermo Fuentes-Jaque.
