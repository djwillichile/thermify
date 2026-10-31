# Dynamic model chill portions

Accumulates chill portions (CP) with the Dynamic model of Fishman, Erez
and Couvillon (1987a, b) as parameterised by Erez et al. (1990).

## Usage

``` r
chill_portions(
  temperature,
  method = "dynamic",
  output = c("cumulative", "hourly", "total"),
  state = NULL,
  na_action = c("propagate", "hold"),
  e0 = 4153.5,
  e1 = 12888.8,
  a0 = 139500,
  a1 = 2.567e+18,
  slope = 1.6,
  tf = 277
)
```

## Arguments

- temperature:

  Numeric vector, or matrix with one row per series and one column per
  hour, of hourly temperatures (degrees Celsius) ordered in time.

- method:

  Currently only `"dynamic"`.

- output:

  `"cumulative"` (default), `"hourly"` increments or `"total"`.

- state:

  Optional state returned by a previous call (attribute `"state"`), to
  continue the accumulation. `NULL` starts from zero.

- na_action:

  `"propagate"` or `"hold"` (see Missing values).

- e0, e1, a0, a1, slope, tf:

  Model constants.

## Value

Chill portions with the shape implied by `output`, with attribute
`"state"`: a list with elements `inter` (intermediate at the start of
the next hour) and `portions` (accumulated portions), one value per
series.

## Model

Chill accumulates in two steps. A thermally labile intermediate \\x\\
forms in cool conditions and is destroyed by warm conditions. Once \\x
\ge 1\\, a temperature-dependent fraction \\\xi\\ of it is fixed
irreversibly as a chill portion. For each hour with temperature \\T_K =
T + 273\\ (K):

\$\$x_s = \frac{A_0}{A_1} e^{(E_1 - E_0)/T_K}, \qquad k_1 = A_1 e^{-E_1
/ T_K}\$\$ \$\$\xi = \frac{s}{1 + s}, \qquad s =
\exp\left(\frac{\mathrm{slope}\\ T_f (T_K - T_f)}{T_K}\right)\$\$
\$\$x_h = x_s - (x_s - S_h) e^{-k_1}\$\$

where \\S_h\\ is the intermediate at the start of the hour. If \\x_h \ge
1\\, \\\Delta CP_h = \xi_h x_h\\ and the next hour starts from
\\S\_{h+1} = x_h (1 - \xi_h)\\; otherwise \\\Delta CP_h = 0\\ and
\\S\_{h+1} = x_h\\. The defaults are the published constants (E0 =
4153.5 K, E1 = 12888.8 K, A0 = 139500, A1 = 2.567e18, slope = 1.6, Tf =
277 K), identical to those of `chillR::Dynamic_Model()`.

## State and blocks

The intermediate is carried from hour to hour and day to day; the model
is never reset implicitly (for example at month boundaries). The state
after the last hour is returned in the `"state"` attribute. Passing it
as `state` to a subsequent call continues the accumulation, so
processing a season in blocks gives the same result as processing it at
once. Define the accumulation period by subsetting `temperature` (see
[`season_days()`](https://djwillichile.github.io/thermify/reference/season_days.md)).

## Indexing relative to chillR

thermify assigns the portion produced during hour \\h\\ to hour \\h\\.
`chillR::Dynamic_Model()` reports the same quantity one position later
(its first element is always zero and the contribution of the final hour
is not included), so `chillR` cumulative output at position \\h + 1\\
equals thermify cumulative output at position \\h\\.

## Missing values

With `na_action = "propagate"` (default) the state becomes `NA` from the
first missing hour onwards, because the intermediate cannot be updated
without temperature. `na_action = "hold"` keeps the intermediate
unchanged and adds no portion during missing hours; this is a pragmatic
gap-bridging assumption that should be reported, and the number of held
hours is returned in the `"n_missing"` attribute. Gaps longer than a few
hours should be filled with a defensible method before using the model.

## References

Fishman, S., Erez, A., & Couvillon, G. A. (1987a). The temperature
dependence of dormancy breaking in plants: computer simulation of
processes studied under controlled temperatures. *Journal of Theoretical
Biology*, 126(3), 309-321.

Fishman, S., Erez, A., & Couvillon, G. A. (1987b). The temperature
dependence of dormancy breaking in plants: mathematical analysis of a
two-step model involving a cooperative transition. *Journal of
Theoretical Biology*, 124(4), 473-483.

Erez, A., Fishman, S., Linsley-Noakes, G. C., & Allan, P. (1990). The
dynamic model for rest completion in peach buds. *Acta Horticulturae*,
276, 165-174.

Luedeling, E., Zhang, M., & Girvetz, E. H. (2009). Climatic changes lead
to declining winter chill for fruit and nut trees in California during
1950-2099. *PLoS ONE*, 4(7), e6166.

## See also

[`chill_units()`](https://djwillichile.github.io/thermify/reference/chill_units.md),
[`hourly_temperatures()`](https://djwillichile.github.io/thermify/reference/hourly_temperatures.md).

## Examples

``` r
temp <- rep(c(2, 4, 6, 8, 10, 12, 10, 8, 6, 4), length.out = 24 * 30)
cp <- chill_portions(temp)
tail(cp, 1)
#> [1] 23.01771

# Block processing gives the same answer
a <- chill_portions(temp[1:300])
b <- chill_portions(temp[301:720], state = attr(a, "state"))
all.equal(tail(as.vector(b), 1), tail(as.vector(cp), 1))
#> [1] TRUE
```
