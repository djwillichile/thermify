# Utah model hourly weights

Vectorised weight function of the Utah model (see
[`chill_units()`](https://djwillichile.github.io/thermify/reference/chill_units.md)
for the interval convention).

## Usage

``` r
utah_weights(temperature)
```

## Arguments

- temperature:

  Numeric vector or matrix of hourly temperatures (degrees Celsius).

## Value

Weights with the same shape as `temperature`; `NA` where the input is
missing.
