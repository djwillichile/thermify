# Utah model chill units

Accumulates chill units (CU) with the Utah model of Richardson, Seeley &
Walker (1974). Each hourly temperature receives a weight that can be
positive, zero or negative; the accumulation is the running sum of
weights.

## Usage

``` r
chill_units(
  temperature,
  method = "utah",
  output = c("cumulative", "hourly", "total"),
  na_action = c("propagate", "skip")
)
```

## Arguments

- temperature:

  Numeric vector, or matrix with one row per series and one column per
  hour, of hourly temperatures in degrees Celsius.

- method:

  Currently only `"utah"`.

- output:

  `"cumulative"` (default) running sum, `"hourly"` weights or `"total"`
  sum.

- na_action:

  `"propagate"` (default): the running sum becomes `NA` from the first
  missing hour; `"skip"`: missing hours contribute zero and their count
  is returned in the `"n_missing"` attribute.

## Value

Chill units (dimensionless) with the shape implied by `output`.

## Weights and boundary convention

The original model is stated in tenths of a degree Celsius. For
continuous temperatures thermify uses left-open, right-closed intervals
\\(a, b\]\\, the same convention as `chillR::Utah_Model()`:

|                         |        |
|-------------------------|--------|
| Temperature (degrees C) | Weight |
| \\T \le 1.4\\           | 0      |
| \\1.4 \< T \le 2.4\\    | 0.5    |
| \\2.4 \< T \le 9.1\\    | 1      |
| \\9.1 \< T \le 12.4\\   | 0.5    |
| \\12.4 \< T \le 15.9\\  | 0      |
| \\15.9 \< T \le 18.0\\  | -0.5   |
| \\T \> 18.0\\           | -1     |

Negative weights are kept and the running sum is **not** truncated at
zero. Variants that reset or floor the sum (for example the "positive
Utah" model) are different models and are not applied implicitly.

## Input

`temperature` must be an hourly series, observed or reconstructed with
[`hourly_temperatures()`](https://djwillichile.github.io/thermify/reference/hourly_temperatures.md),
ordered in time with one value per hour. Applying the weights to monthly
or daily means is not meaningful because the weight function is
non-linear and non-monotonic.

## References

Richardson, E. A., Seeley, S. D., & Walker, D. R. (1974). A model for
estimating the completion of rest for 'Redhaven' and 'Elberta' peach
trees. *HortScience*, 9(4), 331-332.

## See also

[`utah_weights()`](https://djwillichile.github.io/thermify/reference/utah_weights.md),
[`chill_portions()`](https://djwillichile.github.io/thermify/reference/chill_portions.md).

## Examples

``` r
temp <- c(0, 2, 5, 10, 14, 17, 20)
utah_weights(temp)
#> [1]  0.0  0.5  1.0  0.5  0.0 -0.5 -1.0
chill_units(temp)
#> [1] 0.0 0.5 1.5 2.0 2.0 1.5 0.5
chill_units(temp, output = "total")
#> [1] 0.5
```
