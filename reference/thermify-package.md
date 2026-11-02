# thermify: Efficient Agroclimatic Thermal Indices

Computes growing degree-days (average, single and double sine, single
and double triangle methods with horizontal, vertical and intermediate
cutoffs), degree-hours, chilling hours, Utah model chill units and
Dynamic model chill portions from daily or hourly temperatures. Monthly
climatologies can be densified to daily values with a mean-preserving
interpolation, natively or through the 'tempify' Python package, and
then to hourly values with sine or Linvill diurnal models. Raster
workflows based on 'terra' process data in blocks. Outputs based on
monthly climatologies are model-based estimates, not observations.

## See also

Useful links:

- <https://github.com/djwillichile/thermify>

- <https://djwillichile.github.io/thermify/>

- Report bugs at <https://github.com/djwillichile/thermify/issues>

## Author

**Maintainer**: Guillermo Fuentes-Jaque <gfuentesj@correo.uss.cl>
