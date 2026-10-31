# Development roadmap

## v0.1 — Numerical core and chill models
- [x] GDD: average, single/double sine, single/double triangle.
- [x] Horizontal, vertical and intermediate cutoffs; degree-hours.
- [x] Chilling hours (analytical, numerical reference, hourly counts).
- [x] Utah and Dynamic models; Dynamic state across blocks.
- [x] Verification against chillR and degday.
- [ ] Verify the intermediate cutoff against the original Zalom et al. (1983)
      tables.

## v0.2 — Temporal reconstruction and spatial processing
- [x] tempify integration (reticulate) and native `pchip_mp` engine.
- [x] Tmin <= Tmax checks and joint mean/range densification.
- [x] Linvill and sine hourly reconstruction.
- [x] Block-wise `SpatRaster` processing, GeoTIFF/NetCDF, provenance.
- [ ] Daily `SpatRaster` input (observed gridded daily data).

## v0.3 — Case study and documentation
- [x] Cauquenes experiment script, figures, report template.
- [x] Run the Cauquenes experiment with WorldClim 2.1 and publish outputs.
- [x] Region-only WorldClim 2.1 reads at 30 arc-seconds (`worldclim_region()`).
- [x] User stories with acceptance tests; integration and error-path tests.
- [x] Progress feedback for long raster runs.
- [ ] Deploy the pkgdown site (workflow ready; deploys on merge to main).
- [x] Release process documented (`docs/RELEASING.md`) and automated.

## v0.4 — Empirical validation and dissemination
- [ ] Validate against hourly station data (protocol in the validation
      vignette).
- [ ] Publish error metrics and benchmarks; first tagged release.
