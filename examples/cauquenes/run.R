# Cauquenes case study (Maule Region, Chile) ---------------------------------
#
# Reproducible experiment: WorldClim 2.1 monthly tmin/tmax (1970-2000) for a
# 20 x 20 km window around Cauquenes, densified to daily values for the
# reference (non-leap) calendar year 2023, hourly reconstruction, and
# computation of growing degree-days, chilling hours, Utah chill units and
# Dynamic model chill portions.
#
# Results are CLIMATOLOGICAL ESTIMATES derived from monthly normals. They are
# not observations of the year 2023: the year only fixes a 365-day calendar.
#
# Run from the repository root:
#   Rscript examples/cauquenes/run.R
#
# Environment variables:
#   THERMIFY_ENGINE      densification engine: auto (default), tempify, native
#   RETICULATE_PYTHON    Python with tempify installed (optional)
#   THERMIFY_COMPARE_RES if "1", also downloads the global 2.5' archive to
#                        compare resolutions (reused when already cached)
#   THERMIFY_SMOKE_TEST  if "1", replaces WorldClim by a synthetic field and
#                        writes to THERMIFY_SMOKE_DIR (default: a temporary
#                        directory). For software testing only; its numbers
#                        must never be reported as results.

suppressPackageStartupMessages({
  if (requireNamespace("thermify", quietly = TRUE) &&
      !nzchar(Sys.getenv("THERMIFY_DEV"))) {
    library(thermify)
  } else {
    devtools::load_all(".", quiet = TRUE)
  }
  library(terra)
})

# Configuration ---------------------------------------------------------------
cfg <- list(
  centre = c(lon = -72.3225, lat = -35.9671),
  size_km = 20,
  year = 2023,
  engine = Sys.getenv("THERMIFY_ENGINE", "auto"),
  interpolation = "pchip_mp",
  gdd_methods = c("average", "single_sine", "single_triangle",
                  "double_sine", "double_triangle", "hourly"),
  base = c(5, 10),
  ch_methods = c("sine", "hourly"),
  hourly_method = "linvill",
  # Southern hemisphere conventions (see ?season_days)
  chill_period = c("05-01", "08-31"),
  heat_period = c("09-01", "04-30"),
  min_cells = 100   # finer resolution is used below this number of cells
)
smoke_test <- identical(Sys.getenv("THERMIFY_SMOKE_TEST"), "1")
root <- if (smoke_test) {
  Sys.getenv("THERMIFY_SMOKE_DIR", file.path(tempdir(), "cauquenes-smoke"))
} else {
  "examples/cauquenes"
}
data_dir <- file.path("examples/cauquenes", "data")
out <- file.path(root, "output")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
out <- normalizePath(out)
dirs <- file.path(out, c("rasters", "tables", "figures", "reports"))
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
names(dirs) <- c("rasters", "tables", "figures", "reports")
log_msg <- function(...) message(format(Sys.time(), "%H:%M:%S "), ...)
write_tab <- function(x, name) {
  utils::write.csv(x, file.path(dirs[["tables"]], name), row.names = FALSE)
}
if (cfg$engine == "auto") {
  cfg$engine <- if (tempify_available()) "tempify" else "native"
}
log_msg("Densification engine: ", cfg$engine)

# 1. Study window ---------------------------------------------------------------
win <- study_window(cfg$centre[["lon"]], cfg$centre[["lat"]], cfg$size_km)
log_msg("Window (", attr(win, "utm"), "): ",
        paste(round(as.vector(win), 4), collapse = ", "))

# 2. WorldClim 2.1 ---------------------------------------------------------------
get_climate <- function(res) {
  if (smoke_test) {
    # Synthetic field for software testing only (NOT WorldClim).
    step <- res / 60
    r <- rast(xmin = -73, xmax = -71.5, ymin = -36.7, ymax = -35.3,
              resolution = step, nlyrs = 12, crs = "EPSG:4326")
    xy <- crds(r[[1]], na.rm = FALSE)
    m <- 1:12
    tmin_m <- 8 + 4 * cos(2 * pi * (m - 1) / 12)
    tmax_m <- 22 + 8 * cos(2 * pi * (m - 1) / 12)
    grad <- (xy[, 1] + 72.3) * 1.5 + (xy[, 2] + 36) * 0.8
    lapply(list(tmin = setValues(r, outer(grad, tmin_m, "+")),
                tmax = setValues(r, outer(grad * 0.6, tmax_m, "+"))),
           crop, win, snap = "out")
  } else if (res == 0.5) {
    # Only the window is transferred (HTTP range requests on the 30" tiles).
    list(tmin = worldclim_region("tmin", win, data_dir),
         tmax = worldclim_region("tmax", win, data_dir))
  } else {
    # Coarser resolutions exist only as global archives (full download).
    lapply(list(tmin = worldclim_monthly("tmin", res, data_dir),
                tmax = worldclim_monthly("tmax", res, data_dir)),
           crop, win, snap = "out")
  }
}

# Number of 2.5' cells in the window, computed from the grid geometry so that
# the resolution decision does not require downloading the global archive.
grid25 <- rast(ext(-180, 180, -90, 90), resolution = 2.5 / 60)
n25 <- ncell(crop(grid25, win, snap = "out"))
log_msg("2.5' cells in the window: ", n25)
res_choice <- if (n25 < cfg$min_cells) 0.5 else 2.5
if (res_choice == 0.5) {
  # About 3.8 x 4.6 km cells at this latitude: too few to represent the
  # Coastal Range relief and the Cauquenes valley. Use 30 arc-seconds.
  log_msg("Fewer than ", cfg$min_cells, " cells: using 30 arc-seconds")
}
wc <- get_climate(res_choice)
# The official 2.5' product (global archive, ~0.9 GB for tmin + tmax) is
# read only for the optional resolution comparison, or when already cached.
compare_res <- res_choice == 0.5 && (
  identical(Sys.getenv("THERMIFY_COMPARE_RES"), "1") || smoke_test ||
    file.exists(file.path(data_dir, "wc2.1_2.5m_tmax.zip")))
wc25 <- if (compare_res) get_climate(2.5) else NULL
for (v in names(wc)) {
  writeRaster(wc[[v]], file.path(dirs[["rasters"]],
                                 sprintf("worldclim_%s_monthly.tif", v)),
              overwrite = TRUE)
}

# 3. Validation of inputs ------------------------------------------------------
validation <- check_monthly_climate(wc$tmin, wc$tmax)
validation$product <- if (smoke_test) "SYNTHETIC TEST FIELD" else
  sprintf("WorldClim 2.1 %s", if (res_choice == 0.5) "30s" else "2.5m")
write_tab(validation, "input_validation.csv")
print(validation, row.names = FALSE)
if (!all(validation$ok)) stop("Input validation failed; see table.")
n_valid <- sum(!is.na(values(wc$tmin[[1]])))

# 4. Monthly inputs table -------------------------------------------------------
vmin <- values(wc$tmin); vmax <- values(wc$tmax)
valid <- which(stats::complete.cases(vmin))
xy <- xyFromCell(wc$tmin, valid)
monthly_long <- data.frame(
  cell = rep(valid, 12), lon = rep(xy[, 1], 12), lat = rep(xy[, 2], 12),
  month = rep(1:12, each = length(valid)),
  tmin = as.vector(vmin[valid, ]), tmax = as.vector(vmax[valid, ]))
write_tab(monthly_long, "monthly_worldclim_by_cell.csv")
monthly_domain <- data.frame(month = 1:12,
  tmin_mean = colMeans(vmin[valid, ]), tmin_sd = apply(vmin[valid, ], 2, sd),
  tmax_mean = colMeans(vmax[valid, ]), tmax_sd = apply(vmax[valid, ], 2, sd))
write_tab(monthly_domain, "monthly_worldclim_domain.csv")

# 5. Densification of all valid cells -------------------------------------------
log_msg("Densifying ", length(valid), " cells (", cfg$interpolation, ", ",
        cfg$engine, ")")
dens <- densify_monthly(vmin[valid, ], vmax[valid, ], year = cfg$year,
                        method = cfg$interpolation, engine = cfg$engine,
                        consistency = "check")
diag_min <- densify_diagnostics(dens$tmin, vmin[valid, ], dens$dates)
diag_max <- densify_diagnostics(dens$tmax, vmax[valid, ], dens$dates)
dens_summary <- data.frame(
  variable = c("tmin", "tmax"),
  max_abs_monthly_mean_error = c(max(diag_min$max_abs_mean_error),
                                 max(diag_max$max_abs_mean_error)),
  max_boundary_step = c(max(diag_min$max_boundary_step),
                        max(diag_max$max_boundary_step)),
  median_boundary_step = c(median(diag_min$max_boundary_step),
                           median(diag_max$max_boundary_step)),
  max_interior_step = c(max(diag_min$max_interior_step),
                        max(diag_max$max_interior_step)),
  days_tmin_gt_tmax = sum(dens$tmin > dens$tmax),
  min_daily_range = min(dens$tmax - dens$tmin))
write_tab(dens_summary, "densification_diagnostics.csv")
print(dens_summary, row.names = FALSE)

# 6. Reference cell (closest to the town centre) --------------------------------
ref_cell <- cellFromXY(wc$tmin, rbind(cfg$centre))
if (is.na(vmin[ref_cell, 1])) ref_cell <- valid[which.min(
  (xy[, 1] - cfg$centre[["lon"]])^2 + (xy[, 2] - cfg$centre[["lat"]])^2)]
ref_xy <- xyFromCell(wc$tmin, ref_cell)
log_msg("Reference cell ", ref_cell, " at ", paste(round(ref_xy, 4),
                                                   collapse = ", "))
ref <- thermify(vmin[ref_cell, ], vmax[ref_cell, ], input = "monthly",
                year = cfg$year, latitude = ref_xy[2],
                temporal = cfg$engine, interpolation = cfg$interpolation,
                gdd_methods = cfg$gdd_methods, base = cfg$base,
                ch_methods = cfg$ch_methods,
                hourly_method = cfg$hourly_method,
                chill_period = cfg$chill_period,
                heat_period = cfg$heat_period)
write_tab(ref$daily, "reference_cell_daily.csv")
write_tab(ref$summary, "reference_cell_summary.csv")
hr <- ref$hourly
in_chill <- ref$daily$date[!is.na(ref$daily$cp_dynamic)]
hr_chill <- hr[hr$date %in% in_chill, ]
hr_chill$utah_weight <- utah_weights(hr_chill$temperature)
hr_chill$cu_cumulative <- cumsum(hr_chill$utah_weight)
hr_chill$cp_cumulative <- as.vector(chill_portions(hr_chill$temperature))
hr_chill$ch_cumulative <- as.vector(chill_hours_hourly(hr_chill$temperature))
write_tab(hr, "reference_cell_hourly.csv")
write_tab(hr_chill, "reference_cell_chill_accumulation.csv")

# 7. Spatial computation -----------------------------------------------------------
log_msg("Spatial computation")
t_rast <- system.time(
  maps <- thermify_rast(wc$tmin, wc$tmax, output_dir = dirs[["rasters"]],
                        year = cfg$year, temporal = cfg$engine,
                        interpolation = cfg$interpolation,
                        gdd_methods = cfg$gdd_methods, base = cfg$base,
                        ch_methods = cfg$ch_methods,
                        hourly_method = cfg$hourly_method,
                        chill_period = cfg$chill_period,
                        heat_period = cfg$heat_period,
                        format = c("GTiff", "netCDF"), overwrite = TRUE)
)[["elapsed"]]
season <- lapply(maps, function(r) r[["season"]])

# Differences between methods (same period, same base)
diffs <- list(
  gdd_b10_sine_minus_average = season$gdd_single_sine_b10 -
    season$gdd_average_b10,
  gdd_b10_triangle_minus_sine = season$gdd_single_triangle_b10 -
    season$gdd_single_sine_b10,
  gdd_b10_double_minus_single_sine = season$gdd_double_sine_b10 -
    season$gdd_single_sine_b10,
  gdd_b10_hourly_minus_sine = season$gdd_hourly_b10 -
    season$gdd_single_sine_b10,
  gdd_b5_sine_minus_average = season$gdd_single_sine_b5 -
    season$gdd_average_b5,
  ch_hourly_minus_sine = season$ch_hourly - season$ch_sine)
for (k in names(diffs)) {
  writeRaster(diffs[[k]], file.path(dirs[["rasters"]],
                                    paste0("diff_", k, ".tif")),
              overwrite = TRUE)
}

spatial_stats <- function(r, name) {
  v <- values(r, mat = FALSE)
  v <- v[!is.na(v)]
  data.frame(product = name, n = length(v), mean = mean(v), sd = sd(v),
             min = min(v), p05 = unname(quantile(v, 0.05)),
             median = median(v), p95 = unname(quantile(v, 0.95)),
             max = max(v))
}
stats_tab <- rbind(
  do.call(rbind, lapply(names(season), function(k)
    cbind(spatial_stats(season[[k]], k), units = thermify:::index_units(k)))),
  do.call(rbind, lapply(names(diffs), function(k)
    cbind(spatial_stats(diffs[[k]], paste0("diff_", k)),
          units = if (startsWith(k, "ch")) "h" else "degC day"))))
write_tab(stats_tab, "spatial_statistics.csv")

# Resolution comparison: same workflow on the official 2.5' grid
if (!is.null(wc25)) {
  coarse <- thermify_rast(wc25$tmin, wc25$tmax,
                          output_dir = file.path(tempdir(), "coarse"),
                          year = cfg$year, temporal = cfg$engine,
                          indices = c("gdd", "cp"),
                          gdd_methods = "single_sine", base = 10,
                          temporal_aggregation = "season", overwrite = TRUE)
  res_tab <- rbind(
    cbind(resolution = "30s", spatial_stats(season$gdd_single_sine_b10,
                                            "gdd_single_sine_b10")),
    cbind(resolution = "2.5m", spatial_stats(coarse$gdd_single_sine_b10,
                                             "gdd_single_sine_b10")),
    cbind(resolution = "30s", spatial_stats(season$cp_dynamic,
                                            "cp_dynamic")),
    cbind(resolution = "2.5m", spatial_stats(coarse$cp_dynamic,
                                             "cp_dynamic")))
  write_tab(res_tab, "resolution_comparison.csv")
}

# 8. Benchmarks -----------------------------------------------------------------------
log_msg("Benchmarks")
source(file.path("examples/cauquenes", "benchmark.R"), local = TRUE)
bench_tab <- run_benchmarks(vmin[valid, ], vmax[valid, ], ref, cfg,
                            wc = wc, dirs = dirs)
write_tab(bench_tab, "benchmarks.csv")
session <- c(utils::capture.output(utils::sessionInfo()),
             "", "tempify:", utils::capture.output(str(tempify_version())))
writeLines(session, file.path(dirs[["reports"]], "session_info.txt"))

# 9. Figures ----------------------------------------------------------------------
log_msg("Figures")
source(file.path("examples/cauquenes", "figures.R"), local = TRUE)
make_figures(ref, monthly_domain, vmin[ref_cell, ], vmax[ref_cell, ],
             hr_chill, season, diffs, bench_tab, cfg, dirs, smoke_test)

# 10. Report ----------------------------------------------------------------------
meta <- list(cfg = cfg, n_valid = n_valid, res_choice = res_choice,
             n25 = n25, ref_xy = ref_xy, t_rast = t_rast,
             smoke_test = smoke_test, window = as.vector(win),
             utm = attr(win, "utm"))
saveRDS(meta, file.path(dirs[["reports"]], "run_metadata.rds"))
if (requireNamespace("rmarkdown", quietly = TRUE) &&
    rmarkdown::pandoc_available()) {
  rmarkdown::render(file.path("examples/cauquenes", "report.Rmd"),
                    output_dir = dirs[["reports"]],
                    params = list(output = out),
                    quiet = TRUE, envir = new.env())
}
log_msg("Done. Outputs in ", out)
