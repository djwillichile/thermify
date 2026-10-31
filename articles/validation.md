# Verification and validation protocol

## Two different questions

- **Computational verification**: does the code implement the published
  equations correctly? Answered by unit tests (closed forms, numerical
  integration, independent transcriptions, block equivalence) and by
  cross-checks against `chillR` and `degday`
  (`inst/verification/verify_references.R`).
- **Empirical validation**: do the estimates agree with indices computed
  from independent observations? This requires station data and is not
  answered by any WorldClim experiment.

No claim of predictive superiority of one method over another should be
made without empirical validation.

## Verification summary

| Check | Reference | Max. abs. difference |
|----|----|----|
| Dynamic model (cumulative, lag-aligned) | chillR 0.77 | \< 1e-13 |
| Utah model | chillR 0.77 | 0 |
| Chilling hours 0-7.2 | chillR 0.77 | 0 |
| Day length | chillR 0.77 | \< 1e-14 |
| Linvill hourly (`night = "chillr"`) | chillR 0.77 | \< 1e-13 |
| GDD sine/triangle, single/double, horizontal | degday 0.4.0 (UC IPM) | \< 1e-12 |
| `pchip_mp`, 365 and 366 days | tempify 0.1.6 | \< 1e-13 |

## Protocol for empirical validation with hourly stations

1.  **Data.** Stations with hourly temperature (e.g. agrometeorological
    networks such as Agromet INIA or CEAZA in Chile), at least 5
    complete years, with documented quality control. Reject days with
    more than 2 missing hours; fill isolated gaps of 1-2 hours by linear
    interpolation and report them.
2.  **Reference values.** Compute “observed” indices directly from
    hourly data: `degree_hours(by_day = TRUE)`,
    [`chill_hours_hourly()`](https://djwillichile.github.io/thermify/reference/chill_hours_hourly.md),
    [`chill_units()`](https://djwillichile.github.io/thermify/reference/chill_units.md),
    [`chill_portions()`](https://djwillichile.github.io/thermify/reference/chill_portions.md),
    over the same accumulation periods.
3.  **Estimates to evaluate.**
    1.  daily extremes from the station plus each daily method
        (analytical GDD and chilling hours; Linvill or sine
        reconstruction for Utah/Dynamic);
    2.  monthly station climatology densified with `pchip_mp`;
    3.  WorldClim cell containing the station. Level (a) isolates the
        diurnal model error, (b) adds densification error,
    4.  adds spatial interpolation error.
4.  **Metrics** per index, period and station: bias $`= \bar{e}`$, MAE,
    RMSE, relative error $`e / O`$ where $`O`$ is not near zero (not for
    Utah units, which can be zero or negative), and Pearson correlation
    across years.
5.  **Stratification.** By season (monthly), by threshold (sensitivity
    to the base temperature and chilling interval), and by geographic
    setting (coast, valley, foothills).
6.  **Spatial evaluation.** Leave-one-station-out comparison of level
    (c); map residuals against elevation and distance to the coast.
7.  **Reporting.** Report sample sizes, gaps filled, the exact package
    versions
    ([`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html),
    [`tempify_version()`](https://djwillichile.github.io/thermify/reference/tempify_version.md)),
    and uncertainty intervals (bootstrap across years).

``` r

metrics <- function(est, obs) {
  e <- est - obs
  c(bias = mean(e), mae = mean(abs(e)), rmse = sqrt(mean(e^2)),
    r = stats::cor(est, obs))
}
```
