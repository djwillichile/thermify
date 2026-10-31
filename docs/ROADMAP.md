# Development roadmap

## v0.1 — Numeric core
- [ ] Confirm GDD definitions, thresholds, and methods with literature.
- [ ] Validate the analytical chill-hour estimator by numerical integration.
- [ ] Add input validation, boundary tests and complete reference documentation.
- [ ] Run R CMD check on supported platforms.

## v0.2 — WorldClim raster support
- [ ] Process 12-month minimum/maximum SpatRaster stacks with `terra`.
- [ ] Handle temperature scale and units explicitly.
- [ ] Compute monthly and annual indices with transparent assumptions.
- [ ] Store metadata and enable file-backed outputs.

## v0.3 — Optional tempify backend
- [ ] Verify Python tempify compatibility.
- [ ] Reconstruct daily minimum/maximum values using `pchip_mp`.
- [ ] Enforce Tmin <= Tmax in reconstructed data.
- [ ] Compare memory usage, throughput, and output differences.

## v0.4 — Validation and dissemination
- [ ] Validate against observed daily/hourly station data.
- [ ] Publish reproducible error metrics and benchmarks.
- [ ] Add phenological examples, pkgdown documentation and release.
