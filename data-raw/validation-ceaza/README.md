# Validation with CEAZA-Met hourly stations

First empirical validation of thermify against **observed** hourly air
temperature, following `vignette("validation")`.

Data: Centro de Estudios Avanzados en Zonas Áridas (CEAZA), www.ceazamet.cl,
2026. Hourly records were obtained through the CEAZA-Met web service with a
research user granted by CEAZA. They are **not** stored in this repository;
only station metadata, seasonal totals and metrics derived from them are.

## Steps

| Script | What it does |
|---|---|
| `ceaza-api.R` | Web-service client; reads the user from `CEAZA_USER`. |
| `01-screen.R` | Picks each station's air temperature sensor (closest to 2 m) and counts seasons whose months are at least 98 % complete. |
| `02-download.R` | Downloads the hourly series of the selected stations into a local cache (one request per station-year, spaced). |
| `03-validate.R` | Runs `validate_station()` (base 10 degrees C, 0-7.2 degrees C chilling interval) with the WorldClim 2.1 30" cell of each station and writes the results. |

```sh
CEAZA_USER=name@institution Rscript data-raw/validation-ceaza/01-screen.R
CEAZA_USER=name@institution Rscript data-raw/validation-ceaza/02-download.R
Rscript data-raw/validation-ceaza/03-validate.R
```

## Stations and seasons

- 30 of the 53 CEAZA-Met stations with an air temperature sensor have at
  least 5 complete heat and chill seasons (`results/ceaza-stations.csv`).
- Latitude 29.1-32.1 degrees S (29 stations in the Coquimbo region, 1 in Atacama), elevation
  7-2,543 m, from the coast to the Andes, 2004-2025.
- Evaluated: 264 heat seasons (1 September - 30 April) and 313 chill seasons
  (1 May - 31 August). Seasons with any day missing more than 2 consecutive
  hours are excluded (`results/ceaza-excluded.csv`).

## Results (pooled over stations and seasons)

Relative bias of the season total against the value computed from the
observed hourly series (`results/ceaza-metrics.csv`).

**From daily extremes of the station**

| Index | Best method | Bias | Other methods |
|---|---|---|---|
| Degree-days (base 10) | average | +5.4 % | hourly Linvill +6.0 % (lowest MAE, 97 degC day); triangle +7.2 %; sine +8.4 %; modified average +12.2 % |
| Chilling hours (0-7.2) | hourly Linvill | +1.0 % | sine -9.4 % |
| Utah chill units | hourly Linvill | -9.3 % | hourly sine -43.6 % |
| Chill portions | hourly Linvill | -4.3 % | hourly sine -16.3 % |

Degree-days (base 10 degrees C) for every method, from daily extremes (264
heat seasons, 30 stations):

| Method | Relative bias | MAE (degC day) |
|---|---|---|
| average | +5.4 % | 100.7 |
| hourly Linvill | +6.0 % | 97.0 |
| single triangle | +7.20 % | 116.6 |
| double triangle | +7.23 % | 117.2 |
| single sine | +8.36 % | 135.3 |
| double sine | +8.39 % | 135.7 |
| modified average | +12.2 % | 196.5 |

The double methods split the day into a rising half (minimum to maximum of
the same day) and a falling half (maximum to the **next day's** minimum).
They differ from the single methods only when consecutive minima differ,
for example when a front passes; those differences change sign from day to
day and cancel over a season of about 240 days, so the season totals differ
by about 0.03 percentage points. The double methods can matter for short
sums (a week, a month) or around abrupt air-mass changes, which this
season-level validation does not assess.

**From the station's monthly climatology (densified with `pchip_mp`)**:
degree-days +4 to +10 %; chilling hours -25 to -29 %; Utah units -1 %
(Linvill) to -41 % (sine); chill portions -11 % (Linvill) to -32 % (sine).

**From the WorldClim 2.1 30" cell**: degree-days -5 to -12 %, chilling hours
+28 to +44 %, chill portions +31 to +43 %, Utah units +69 to +99 %, with
mean absolute errors several times larger than at the other levels.

## Interpretation

- **All daily degree-day methods overestimate at these sites.** In the
  semi-arid north the night is long and cool and the warm peak is short, so
  the mid-range (Tmin + Tmax) / 2 is above the true daily mean (by 0.9
  degrees C at Illapel). Methods that assume a symmetric day (sine,
  triangle) overestimate most. The synthetic experiment
  (`data-raw/gdd-synthetic/`) did not reproduce this asymmetry: real
  diurnal cycles here are more skewed than the generator assumed.
- **Ensembles cannot remove a shared bias.** Because every member
  overestimates, stacking, BMA and Akaike weights all put the whole weight
  on the averaging method (`results/ceaza-ensemble-weights.csv`); the
  cross-validated error equals that of the averaging method.
- **For chill, the Linvill reconstruction is clearly better than the sine**,
  especially for the non-linear Utah and Dynamic models.
- **Monthly climatologies lose the cold nights**: densified monthly values
  have no day-to-day variability, so chilling hours are underestimated by
  about a quarter.
- **WorldClim cells should be used with caution here.** Part of the error
  comes from the different periods (WorldClim 1970-2000 normals against
  station seasons of 2004-2025, a period of warming) and part from complex
  terrain, where a 30" cell does not represent valley or slope stations.
  These two effects are not separated in this analysis.

## Limitations

- Arid and semi-arid sites only. The validation in the central-south (INIA
  network, Maule-Ñuble-O'Higgins) is pending.
- Hourly values are hourly means; daily extremes taken from them are
  slightly narrower than those of sub-hourly records.
- One base temperature (10 degrees C) and no upper threshold.
- Seasons, not individual days, are evaluated.
