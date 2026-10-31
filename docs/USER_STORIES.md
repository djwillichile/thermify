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
