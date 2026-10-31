# Cauquenes case study

Reproducible experiment that applies `thermify` to WorldClim 2.1 monthly
temperature normals around Cauquenes (Maule Region, Chile).

> [!IMPORTANT]
> Results are **climatological estimates** obtained from 1970-2000 monthly
> normals, densified to a reference 365-day calendar (2023) and then
> disaggregated to hours. They are not observations of 2023 and this
> experiment is **not an empirical validation** of any method.

## Design

| Item | Value |
|---|---|
| Centre (WGS84) | -35.9671, -72.3225 |
| Window | 20 x 20 km square in UTM 18S (EPSG:32718), returned as its enclosing lon/lat extent. Experimental area around the town, not the commune boundary. |
| Climate data | WorldClim 2.1 `tmin`, `tmax`, 12 months, 1970-2000 |
| Resolution | The number of 2.5 arc-minute cells in the window is computed from the grid (36 cells of about 3.8 x 4.6 km). Below 100 cells the 30 arc-second product is used, read with `worldclim_region()`: only the window is transferred (about 0.3 MB per variable) instead of the 41 MB country file or the 450 MB global archive. |
| Daily reconstruction | `pchip_mp` (tempify, or the equivalent native engine) |
| Hourly reconstruction | Linvill (1990), cell latitude |
| GDD | average, single/double sine, single/double triangle, degree-hours; bases 5 and 10 degC; heat period 1 Sep - 30 Apr |
| Chill | chilling hours 0-7.2 degC (analytical sine and hourly count), Utah, Dynamic; chill period 1 May - 31 Aug |

## Running

From the repository root:

```sh
# Optional: Python with tempify for the reference densification engine
export RETICULATE_PYTHON=/path/to/venv/bin/python
Rscript examples/cauquenes/run.R
```

The script reads WorldClim into `examples/cauquenes/data/` once (cached,
git-ignored) and needs access to `geodata.ucdavis.edu`. Set
`THERMIFY_COMPARE_RES=1` to also download the global 2.5 arc-minute archives
(about 0.9 GB) for the resolution comparison. Set
`THERMIFY_ENGINE=native` to run without Python.

`THERMIFY_SMOKE_TEST=1` replaces WorldClim with a synthetic field and writes to
a temporary directory. It exists only to test the script; its numbers must
not be reported.

## Outputs

```
output/
├── rasters/   GeoTIFF + NetCDF per index (layers: season, annual, m01-m12),
│              method differences (diff_*.tif), cropped WorldClim inputs,
│              provenance.json
├── tables/    input validation, monthly inputs, densification diagnostics,
│              reference-cell daily/hourly/accumulation tables, spatial
│              statistics, resolution comparison, benchmarks
├── figures/   01-09 PNG figures (reconstruction, methods, maps, performance)
└── reports/   report.html, session_info.txt, run_metadata.rds
```

Large rasters are git-ignored; tables, figures and the report are small
enough to be versioned once the experiment has been run with real data.

## Files

* `run.R`: the experiment.
* `benchmark.R`: benchmark helper (sourced by `run.R`).
* `figures.R`: figure helper (sourced by `run.R`).
* `report.Rmd`: report template rendered into `output/reports/`.
