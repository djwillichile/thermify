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
