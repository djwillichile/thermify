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
