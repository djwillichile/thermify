# Diagnostics of a monthly-to-daily densification

Summarises how well a densified series reproduces the monthly input and
how smooth it is at month boundaries.

## Usage

``` r
densify_diagnostics(daily, monthly, dates)
```

## Arguments

- daily:

  Matrix of daily values (one row per location).

- monthly:

  Matrix of the 12 monthly input values (one row per location).

- dates:

  Dates of the daily columns.

## Value

A data frame with one row per location: `max_abs_mean_error` (degrees
C), `max_boundary_step` (largest absolute day-to-day change across a
month boundary, degrees C) and `max_interior_step` (largest absolute
day-to-day change within months, degrees C).
