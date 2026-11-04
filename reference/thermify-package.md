# thermify: Efficient Agroclimatic Thermal Indices

Computes growing degree-days (average, single and double sine, single
and double triangle methods with horizontal, vertical and intermediate
cutoffs; Allen (1976)
[doi:10.1093/ee/5.3.388](https://doi.org/10.1093/ee/5.3.388) ),
degree-hours, chilling hours, Utah model chill units (Richardson et al.
1974) and Dynamic model chill portions (Fishman et al. (1987)
[doi:10.1016/S0022-5193(87)80237-0](https://doi.org/10.1016/S0022-5193%2887%2980237-0)
) from daily or hourly temperatures. Monthly climatologies such as
'WorldClim' 2.1 (Fick and Hijmans (2017)
[doi:10.1002/joc.5086](https://doi.org/10.1002/joc.5086) ) can be
densified to daily values with a mean-preserving interpolation, natively
or through the 'tempify' Python package, and then to hourly values with
sine or Linvill (1990)
[doi:10.21273/HORTSCI.25.1.14](https://doi.org/10.21273/HORTSCI.25.1.14)
diurnal models. Raster workflows based on 'terra' process data in
blocks. Outputs based on monthly climatologies are model-based
estimates, not observations.

## See also

Useful links:

- <https://github.com/djwillichile/thermify>

- <https://djwillichile.github.io/thermify/>

- Report bugs at <https://github.com/djwillichile/thermify/issues>

## Author

**Maintainer**: Guillermo Fuentes-Jaque <gfuentesj@correo.uss.cl>
([ORCID](https://orcid.org/0000-0002-7864-4899))
