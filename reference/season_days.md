# Select the days of an accumulation period

Returns the positions of `dates` that fall inside a seasonal window
given as `"MM-DD"` bounds (both inclusive), in chronological order of
the season. Windows may cross the end of the year (for example `"09-01"`
to `"04-30"`, the southern-hemisphere growing season).

## Usage

``` r
season_days(dates, start, end, cyclic = FALSE)
```

## Arguments

- dates:

  Vector of class `Date`.

- start, end:

  Window bounds as `"MM-DD"`.

- cyclic:

  Treat `dates` as one closed climatological year.

## Value

Integer vector of positions in `dates`, with attribute `"season"`.

## Details

For a climatological year (`cyclic = TRUE`, one calendar year
representing a closed annual cycle) a window that crosses the year end
is returned as the tail of the year followed by its head, so that
sequential models such as the Dynamic model run through the season in
the right order. For observed multi-year series (`cyclic = FALSE`) the
attribute `"season"` gives the calendar year in which each selected
day's season starts.

Southern-hemisphere defaults used by
[`thermify()`](https://djwillichile.github.io/thermify/reference/thermify.md):
chill accumulation from 1 May to 31 August and heat accumulation from 1
September to 30 April. They are conventions, not universal truths: adapt
them to the species, cultivar and region.

## Examples

``` r
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "day")
idx <- season_days(d, "09-01", "04-30", cyclic = TRUE)
range(d[idx][1:3]); length(idx)
#> [1] "2023-09-01" "2023-09-03"
#> [1] 242
```
