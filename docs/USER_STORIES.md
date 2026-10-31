# User stories

Each story is backed by an acceptance test in
`tests/testthat/test-story-<id>.R`. A story is done when its acceptance
criteria pass in `devtools::test()`.

Personas:

* **Agronomist**: advises growers in the Maule Region; works with station
  data in spreadsheets and R.
* **Fruit grower**: manages cherry and walnut orchards; needs chill
  requirements expressed in the model used by their cultivar data.
* **GIS analyst**: produces maps for territorial planning from gridded
  climate data.
* **Researcher**: compares methods and must document and reproduce results.

## US-01 Heat accumulation to a phenological threshold

As an **agronomist**, I want to accumulate growing degree-days from daily
station data over the season and know the date on which a phenological
threshold is reached, so that I can schedule field operations.

Acceptance criteria:

1. Daily GDD for a base and an optional upper threshold are accumulated over
   an explicit season that may cross the year end (1 September to 30 April).
2. `threshold_date()` returns the first date on which the accumulation
   reaches the threshold, and `NA` when it is not reached.
3. Missing days make the date `NA` unless the user explicitly chooses to skip
   them.

## US-02 Chill requirement from hourly station records

As a **fruit grower**, I want to compute chill portions (Dynamic model) and
chilling hours from my hourly station records between 1 May and 31 August,
and know when my cultivar's requirement is met, so that I can judge whether
the winter was sufficient and plan dormancy-breaking treatments.

Acceptance criteria:

1. Hourly input is declared explicitly (`input = "hourly"`) and indices are
   computed on the observed hours, without reconstruction.
2. Chill accumulation is restricted to the configured period and the Dynamic
   model is not reset inside it.
3. The date on which a requirement (for example 50 portions) is met can be
   obtained from the daily values.
4. Records split across several files (blocks) give the same result when the
   model state is carried over.

## US-03 Chill models when only daily extremes exist

As an **agronomist** whose stations record only daily minimum and maximum
temperatures, I want to estimate Utah chill units and chill portions through
an explicit hourly reconstruction, so that I can use hourly chill models
while knowing that the hours are modelled.

Acceptance criteria:

1. Reconstructed hours are flagged as such in the output and in the
   provenance, together with the reconstruction method.
2. The Linvill model requires a latitude and fails with an informative
   message without it; the sine model does not need one.
3. Reconstructed hours stay within the daily extremes that generated them
   (between the minimum and maximum of the day and its neighbours).
4. The analytical chilling-hours estimate from daily extremes is available
   alongside the count on reconstructed hours, so both can be compared.

## US-04 Maps for a territory from WorldClim

As a **GIS analyst**, I want to compute thermal-index maps for a territory
(a study window or a commune polygon) from WorldClim 2.1 without downloading
global files, so that I can produce planning maps quickly and with modest
storage.

Acceptance criteria:

1. Monthly 30 arc-second data are read for the territory only and can be
   masked by its polygon.
2. Output rasters keep the CRS, extent, resolution and NA mask of the input;
   cells outside the polygon stay `NA`.
3. Each index is written as one file with named, documented layers (season,
   annual, monthly) and units.

## US-05 Comparing methods on the same data

As a **researcher**, I want all GDD and chill methods computed on exactly the
same inputs and returned in one tidy table with units, so that I can quantify
differences between methods without re-running or reshaping.

Acceptance criteria:

1. One call returns every requested method x base temperature, each row with
   its key, aggregation and units.
2. Results respect known mathematical properties: without an upper threshold,
   sine and triangle GDD are never below the averaging method (Jensen's
   inequality for the convex function max(0, T - Tb)), and all methods agree
   when temperatures never cross the base.
3. Requesting several methods does not change the value of any single method.

## US-06 Reproducible and traceable results

As a **researcher**, I want every result to record the data frequency,
methods, parameters and software versions used (including the exact tempify
commit when it is used), and identical inputs to give identical outputs, so
that my analyses can be audited and reproduced.

Acceptance criteria:

1. Single-site results include provenance: input frequency, thermify version,
   densification engine, method, calendar year, consistency rule and the
   maximum monthly-mean error.
2. Raster runs write a `provenance.json` with parameters, CRS, resolution,
   extent, number of valid cells and versions; with tempify, its version and
   commit.
3. Re-running with the same inputs gives identical values.

## US-07 Large regions on modest hardware

As a **GIS analyst** working on a laptop, I want to process large rasters in
blocks with a memory limit I can set, without results depending on that
limit, so that regional or national maps do not exhaust memory.

Acceptance criteria:

1. The block size (`max_cells`) controls how many blocks are processed, and
   the number of blocks is recorded in the provenance.
2. Results are identical for any block size.
3. Daily or hourly rasters are not written unless explicitly requested
   (`keep_daily = TRUE`), in which case daily layers are dated.

## US-08 Working without Python

As an **agronomist** without a Python installation, I want the package to
work fully with daily, hourly and monthly data, and to tell me clearly what
to do if I explicitly ask for the tempify backend, so that Python is an
option and not a requirement.

Acceptance criteria:

1. With `temporal = "auto"` and no tempify, the native engine is used and
   recorded in the provenance.
2. Asking explicitly for `temporal = "tempify"` without it fails with a
   message that names the native alternative.
3. Methods only available in tempify fail with an informative message under
   the native engine.

## US-09 Protection against common input mistakes

As an **agronomist**, I want the package to stop with a clear message when
my inputs are inconsistent, instead of silently producing numbers, so that
data errors do not reach my reports.

Acceptance criteria:

1. Swapped extremes (`tmin > tmax`) are reported with the position of the
   first problem and are never corrected silently.
2. The data frequency is never guessed from the number of values: daily data
   passed as monthly, gaps in dates, or hourly series of the wrong length
   are rejected.
3. Monthly rasters with scaled values (for example degrees x 10, as in
   WorldClim 1.4) or mismatched masks are flagged by
   `check_monthly_climate()`.
