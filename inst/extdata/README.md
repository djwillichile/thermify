# External data

## cauquenes.gpkg

Administrative boundaries of the Cauquenes commune and province (Maule
Region, Chile), used by the Cauquenes tutorial and the examples of
`worldclim_region()`.

| Layer | Feature | Code | Area |
|---|---|---|---|
| `comuna` | Cauquenes commune | `CUT_COM = "07201"` | 2,124.5 km² |
| `provincia` | Cauquenes province | `CUT_PROV = "072"` | 3,021.7 km² |

* Source: División Político-Administrativa de Chile 2023 (DPA 2023), commune
  and province layers, extracted without modification of geometry or
  attributes (`CUT_REG`, `CUT_PROV`, `CUT_COM`, `REGION`, `PROVINCIA`,
  `COMUNA`, `SUPERFICIE`).
* Coordinate reference system: SIRGAS-Chile 2002 (EPSG:5360), as published.
* Reproduction: `data-raw/cauquenes_gpkg.R`.

```r
f <- system.file("extdata", "cauquenes.gpkg", package = "thermify")
comuna <- terra::vect(f, layer = "comuna")
```
