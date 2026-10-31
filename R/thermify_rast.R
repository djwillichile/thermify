#' Thermal indices from monthly climatology rasters
#'
#' Spatial version of [thermify()] for 12-layer monthly `SpatRaster` stacks
#' (for example WorldClim 2.1 `tmin` and `tmax`). Rasters are processed in
#' blocks of rows: for each block, valid cells are densified to daily values,
#' hourly temperatures are reconstructed when needed, indices are computed
#' and only the aggregated layers are written to disk. Daily or hourly
#' rasters are never held for the whole extent.
#'
#' @section Outputs:
#' One GeoTIFF per index key (for example `gdd_single_sine_b10.tif`) is
#' written to `output_dir`, with layers named after the temporal aggregation:
#' `season` (accumulation period), `annual` (1 January to 31 December, GDD
#' and chilling hours only) and `m01`...`m12` (monthly totals; for Utah and
#' Dynamic models only months inside the chill period are filled). The CRS,
#' extent, resolution and NA mask of `tmin` are preserved. With
#' `format = "netCDF"` the same layers are also written to one NetCDF file
#' per index. A `provenance.json` (or `.txt` without jsonlite) file records
#' parameters and versions.
#'
#' @section Memory:
#' Peak memory is roughly proportional to `max_cells` times the number of
#' hours in a year (8760 values per cell) when hourly-based indices are
#' requested. Lower `max_cells` to reduce memory; results do not depend on
#' the block size.
#'
#' @param tmin,tmax `SpatRaster` objects with 12 layers (January to December)
#'   in degrees Celsius and identical geometry.
#' @param output_dir Directory for the output files (created if needed).
#' @param latitude Optional fixed latitude for the Linvill model. By default
#'   the latitude of each cell centre is used (cells are projected to
#'   EPSG:4326 when the CRS is not geographic).
#' @param temporal_aggregation Any of `"season"`, `"annual"`, `"monthly"`.
#' @param max_cells Maximum number of cells per processing block.
#' @param format `"GTiff"` and/or `"netCDF"`.
#' @param keep_daily If `TRUE`, also write the reconstructed daily `tmin` and
#'   `tmax` (365 or 366 layers each) for diagnosis.
#' @param overwrite Overwrite existing files.
#' @inheritParams thermify
#' @return A named list of file-backed `SpatRaster` objects, one per index
#'   key, with attribute `"provenance"`.
#' @examples
#' \donttest{
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   r <- terra::rast(nrows = 3, ncols = 3, nlyrs = 12,
#'                    xmin = -72.4, xmax = -72.3, ymin = -36, ymax = -35.9)
#'   base_min <- c(11, 11, 9, 7, 5, 4, 3, 4, 5, 6, 8, 10)
#'   base_max <- c(29, 29, 26, 22, 17, 14, 13, 15, 18, 21, 25, 28)
#'   tmin <- terra::setValues(r, rep(base_min, each = 9))
#'   tmax <- terra::setValues(r, rep(base_max, each = 9))
#'   out <- thermify_rast(tmin, tmax, output_dir = tempfile(),
#'                        temporal = "native", indices = c("gdd", "cp"),
#'                        gdd_methods = "single_sine", base = 10)
#'   out$gdd_single_sine_b10
#' }
#' }
#' @export
thermify_rast <- function(tmin, tmax, output_dir, year = 2023,
                          latitude = NULL,
                          temporal = c("auto", "tempify", "native"),
                          interpolation = "pchip_mp",
                          consistency = c("check", "mean_range"),
                          indices = c("gdd", "ch", "cu", "cp"),
                          gdd_methods = c("average", "single_sine"),
                          base = c(5, 10), upper = NULL,
                          cutoff = "horizontal", ch_methods = "sine",
                          ch_lower = 0, ch_upper = 7.2,
                          hourly_method = c("linvill", "sine"),
                          chill_period = c("05-01", "08-31"),
                          heat_period = c("09-01", "04-30"),
                          temporal_aggregation = c("season", "annual",
                                                   "monthly"),
                          max_cells = 2000L, format = "GTiff",
                          keep_daily = FALSE, overwrite = FALSE) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("thermify_rast() requires the 'terra' package.", call. = FALSE)
  }
  temporal <- match.arg(temporal)
  consistency <- match.arg(consistency)
  hourly_method <- match.arg(hourly_method)
  temporal_aggregation <- match.arg(temporal_aggregation,
                                    several.ok = TRUE)
  format <- match.arg(format, c("GTiff", "netCDF"), several.ok = TRUE)
  check_monthly_rasters(tmin, tmax)
  cfg <- thermal_config(indices, gdd_methods, base, upper, cutoff,
                        ch_methods, ch_lower, ch_upper, hourly_method,
                        chill_period, heat_period)
  if (temporal == "auto") temporal <- if (tempify_available()) "tempify" else
    "native"
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  dates <- seq(as.Date(sprintf("%d-01-01", year)),
               as.Date(sprintf("%d-12-31", year)), by = "day")
  keys <- expected_keys(cfg)
  layer_names <- expected_layers(keys, temporal_aggregation)

  outputs <- lapply(keys, function(k) {
    r <- terra::rast(tmin, nlyrs = length(layer_names[[k]]))
    names(r) <- layer_names[[k]]
    r
  })
  names(outputs) <- keys
  files <- file.path(output_dir, paste0(keys, ".tif"))
  names(files) <- keys
  existing <- file.exists(files)
  if (any(existing) && !overwrite) {
    stop("Output files exist; set overwrite = TRUE: ",
         paste(basename(files[existing]), collapse = ", "), call. = FALSE)
  }
  wopt <- list(gdal = c("COMPRESS=DEFLATE", "TILED=YES"), datatype = "FLT4S")
  for (k in keys) {
    terra::writeStart(outputs[[k]], files[[k]], overwrite = TRUE,
                      wopt = wopt)
  }
  daily_out <- NULL
  if (keep_daily) {
    daily_out <- list(
      tmin = terra::rast(tmin, nlyrs = length(dates)),
      tmax = terra::rast(tmin, nlyrs = length(dates)))
    for (v in names(daily_out)) {
      names(daily_out[[v]]) <- format(dates)
      terra::writeStart(daily_out[[v]],
                        file.path(output_dir, sprintf("daily_%s.tif", v)),
                        overwrite = TRUE, wopt = wopt)
    }
  }
  terra::readStart(tmin)
  terra::readStart(tmax)
  on.exit({
    terra::readStop(tmin)
    terra::readStop(tmax)
  }, add = TRUE)

  nc <- terra::ncol(tmin)
  rows_per_block <- max(1L, as.integer(max_cells %/% nc))
  starts <- seq(1L, terra::nrow(tmin), by = rows_per_block)
  n_valid <- 0L
  max_mean_error <- 0
  t0 <- proc.time()[["elapsed"]]

  for (row in starts) {
    nr <- min(rows_per_block, terra::nrow(tmin) - row + 1L)
    vmin <- terra::readValues(tmin, row, nr, 1, nc, mat = TRUE)
    vmax <- terra::readValues(tmax, row, nr, 1, nc, mat = TRUE)
    valid <- stats::complete.cases(vmin) & stats::complete.cases(vmax)
    n_valid <- n_valid + sum(valid)
    block_out <- lapply(layer_names, function(l)
      matrix(NA_real_, nrow(vmin), length(l)))
    dmin_all <- dmax_all <- NULL
    if (any(valid)) {
      dens <- densify_monthly(vmin[valid, , drop = FALSE],
                              vmax[valid, , drop = FALSE], year = year,
                              method = interpolation, engine = temporal,
                              consistency = consistency)
      max_mean_error <- max(max_mean_error,
                            dens$provenance$max_abs_mean_error)
      lat <- latitude
      if (is.null(lat) && needs_hourly(cfg) && hourly_method == "linvill") {
        cells <- terra::cellFromRowCol(tmin, rep(row:(row + nr - 1L),
                                                 each = nc),
                                       rep(seq_len(nc), nr))[valid]
        lat <- cell_latitude(tmin, cells)
      }
      daily <- compute_daily(dens$tmin, dens$tmax, dates, cyclic = TRUE,
                             cfg = cfg, latitude = lat)
      agg <- aggregate_daily(daily, dates, cyclic = TRUE, cfg = cfg,
                             temporal = temporal_aggregation)
      for (k in keys) block_out[[k]][valid, ] <- agg[[k]][, layer_names[[k]],
                                                         drop = FALSE]
      if (keep_daily) {
        dmin_all <- dmax_all <- matrix(NA_real_, nrow(vmin), length(dates))
        dmin_all[valid, ] <- dens$tmin
        dmax_all[valid, ] <- dens$tmax
      }
    }
    for (k in keys) {
      terra::writeValues(outputs[[k]], block_out[[k]], row, nr)
    }
    if (keep_daily) {
      if (is.null(dmin_all)) dmin_all <- dmax_all <-
          matrix(NA_real_, nrow(vmin), length(dates))
      terra::writeValues(daily_out$tmin, dmin_all, row, nr)
      terra::writeValues(daily_out$tmax, dmax_all, row, nr)
    }
  }
  elapsed <- proc.time()[["elapsed"]] - t0

  result <- lapply(keys, function(k) {
    r <- terra::writeStop(outputs[[k]])
    terra::units(r) <- rep(index_units(k), terra::nlyr(r))
    r
  })
  names(result) <- keys
  if (keep_daily) for (v in names(daily_out)) terra::writeStop(daily_out[[v]])

  if ("netCDF" %in% format) {
    for (k in keys) {
      terra::writeCDF(result[[k]], file.path(output_dir, paste0(k, ".nc")),
                      varname = k, unit = index_units(k),
                      overwrite = TRUE)
    }
  }

  provenance <- list(
    thermify = as.character(utils::packageVersion("thermify")),
    terra = as.character(utils::packageVersion("terra")),
    created = format(Sys.time(), tz = "UTC"),
    year = year, engine = temporal, interpolation = interpolation,
    consistency = consistency,
    tempify = if (temporal == "tempify") tempify_version() else NULL,
    max_abs_monthly_mean_error = max_mean_error,
    config = cfg, temporal_aggregation = temporal_aggregation,
    crs = terra::crs(tmin, describe = TRUE)$code,
    resolution = terra::res(tmin), extent = as.vector(terra::ext(tmin)),
    n_cells = terra::ncell(tmin), n_valid_cells = n_valid,
    max_cells_per_block = max_cells, n_blocks = length(starts),
    elapsed_seconds = elapsed, outputs = unname(basename(files)))
  write_provenance(provenance, output_dir)
  attr(result, "provenance") <- provenance
  result
}

check_monthly_rasters <- function(tmin, tmax) {
  if (!inherits(tmin, "SpatRaster") || !inherits(tmax, "SpatRaster")) {
    stop("`tmin` and `tmax` must be SpatRaster objects.", call. = FALSE)
  }
  if (terra::nlyr(tmin) != 12L || terra::nlyr(tmax) != 12L) {
    stop("`tmin` and `tmax` must have 12 monthly layers.", call. = FALSE)
  }
  if (!isTRUE(terra::compareGeom(tmin, tmax, stopOnError = FALSE))) {
    stop("`tmin` and `tmax` must share CRS, extent and resolution.",
         call. = FALSE)
  }
  invisible(TRUE)
}

cell_latitude <- function(r, cells) {
  xy <- terra::xyFromCell(r, cells)
  if (!terra::is.lonlat(r)) {
    v <- terra::vect(xy, crs = terra::crs(r))
    xy <- terra::crds(terra::project(v, "EPSG:4326"))
  }
  xy[, 2]
}

expected_keys <- function(cfg) {
  keys <- character()
  if ("gdd" %in% cfg$indices) {
    for (m in cfg$gdd_methods) for (b in cfg$base) {
      keys <- c(keys, sprintf("gdd_%s_b%s", m, format(b)))
    }
  }
  if ("ch" %in% cfg$indices) keys <- c(keys, paste0("ch_", cfg$ch_methods))
  if ("cu" %in% cfg$indices) keys <- c(keys, "cu_utah")
  if ("cp" %in% cfg$indices) keys <- c(keys, "cp_dynamic")
  keys
}

expected_layers <- function(keys, temporal) {
  out <- lapply(keys, function(k) {
    l <- character()
    if ("season" %in% temporal) l <- c(l, "season")
    if ("annual" %in% temporal && !k %in% c("cu_utah", "cp_dynamic")) {
      l <- c(l, "annual")
    }
    if ("monthly" %in% temporal) l <- c(l, sprintf("m%02d", 1:12))
    l
  })
  names(out) <- keys
  out
}

write_provenance <- function(provenance, output_dir) {
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(provenance, file.path(output_dir, "provenance.json"),
                         auto_unbox = TRUE, pretty = TRUE, null = "null",
                         digits = NA)
  } else {
    utils::capture.output(utils::str(provenance),
                          file = file.path(output_dir, "provenance.txt"))
  }
}
