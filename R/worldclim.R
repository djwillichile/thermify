#' Square study window around a point
#'
#' Builds a square window of `size_km` side centred on a WGS84 point. The
#' square is defined in the local UTM zone (metres) and returned as the
#' enclosing longitude/latitude extent, so that its size does not depend on
#' latitude.
#'
#' @param lon,lat Centre in decimal degrees (WGS84).
#' @param size_km Side of the square in kilometres.
#' @return A `SpatExtent` in longitude/latitude, with attribute `"utm"` (the
#'   EPSG code used).
#' @examples
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   study_window(-72.3225, -35.9671, 20)
#' }
#' @export
study_window <- function(lon, lat, size_km = 20) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("study_window() requires the 'terra' package.", call. = FALSE)
  }
  check_scalar(lon, "lon")
  check_scalar(lat, "lat")
  check_scalar(size_km, "size_km")
  zone <- floor((lon + 180) / 6) + 1
  epsg <- sprintf("EPSG:%d", if (lat < 0) 32700 + zone else 32600 + zone)
  centre <- terra::project(terra::vect(cbind(lon, lat), crs = "EPSG:4326"),
                           epsg)
  xy <- terra::crds(centre)
  half <- size_km * 500
  sq <- terra::vect(cbind(xy[1] + c(-half, half, half, -half),
                          xy[2] + c(-half, -half, half, half)),
                    type = "polygons", crs = epsg)
  e <- terra::ext(terra::project(sq, "EPSG:4326"))
  attr(e, "utm") <- epsg
  e
}

#' Download (or reuse) WorldClim 2.1 monthly temperature normals
#'
#' Returns the 12 monthly layers of WorldClim 2.1 (1970-2000 normals) for
#' `tmin` or `tmax`, in degrees Celsius. Files are cached in `path` and are
#' not downloaded again when a valid copy exists. The `geodata` package is
#' used when installed; otherwise the files are downloaded directly from the
#' same server.
#'
#' Global files are used for `res` 10, 5 and 2.5 arc-minutes. For 30
#' arc-seconds (`res = 0.5`) a `country` ISO3 code is required and the
#' country tile is downloaded (for Chile, `"CHL"`).
#'
#' @param var `"tmin"` or `"tmax"`.
#' @param res Resolution in arc-minutes: 10, 5, 2.5 or 0.5.
#' @param path Cache directory.
#' @param country ISO3 code, required for `res = 0.5`.
#' @param timeout Download timeout in seconds.
#' @return A 12-layer `SpatRaster` with layers named `m01` to `m12`.
#' @references
#' Fick, S. E., & Hijmans, R. J. (2017). WorldClim 2: new 1-km spatial
#' resolution climate surfaces for global land areas. *International Journal
#' of Climatology*, 37(12), 4302-4315.
#' @export
worldclim_monthly <- function(var = c("tmin", "tmax"), res = 2.5, path,
                              country = NULL, timeout = 3600) {
  var <- match.arg(var)
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("worldclim_monthly() requires the 'terra' package.", call. = FALSE)
  }
  if (!res %in% c(10, 5, 2.5, 0.5)) {
    stop("`res` must be one of 10, 5, 2.5 or 0.5.", call. = FALSE)
  }
  if (res == 0.5 && is.null(country)) {
    stop("`res = 0.5` requires `country` (ISO3 code).", call. = FALSE)
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  base <- "https://geodata.ucdavis.edu/climate/worldclim/2_1"
  if (requireNamespace("geodata", quietly = TRUE)) {
    r <- if (res == 0.5) {
      geodata::worldclim_country(country, var = var, path = path)
    } else {
      geodata::worldclim_global(var = var, res = res, path = path)
    }
  } else if (res == 0.5) {
    f <- file.path(path, sprintf("%s_wc2.1_30s_%s.tif", country, var))
    if (!valid_raster(f, 12L)) {
      download(sprintf("%s/tiles/iso/%s", base, basename(f)), f, timeout)
    }
    r <- terra::rast(f)
  } else {
    tag <- sprintf("wc2.1_%sm_%s", format(res), var)
    dir <- file.path(path, "climate", sprintf("wc2.1_%sm", format(res)))
    tifs <- file.path(dir, sprintf("%s_%02d.tif", tag, 1:12))
    if (!all(vapply(tifs, valid_raster, logical(1), n = 1L))) {
      zip <- file.path(path, paste0(tag, ".zip"))
      if (!file.exists(zip)) {
        download(sprintf("%s/base/%s.zip", base, tag), zip, timeout)
      }
      utils::unzip(zip, exdir = dir)
    }
    r <- terra::rast(tifs)
  }
  if (terra::nlyr(r) != 12L) {
    stop("Expected 12 monthly layers, found ", terra::nlyr(r), call. = FALSE)
  }
  ord <- order(as.integer(sub(".*_([0-9]{1,2})$", "\\1", names(r))))
  r <- r[[ord]]
  names(r) <- sprintf("m%02d", 1:12)
  r
}

valid_raster <- function(f, n) {
  file.exists(f) && isTRUE(tryCatch(terra::nlyr(terra::rast(f)) == n,
                                    error = function(e) FALSE))
}

download <- function(url, dest, timeout) {
  old <- options(timeout = max(timeout, getOption("timeout")))
  on.exit(options(old))
  tmp <- paste0(dest, ".part")
  status <- utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
  if (status != 0L) stop("Download failed: ", url, call. = FALSE)
  file.rename(tmp, dest)
}

#' Validate a pair of monthly temperature rasters
#'
#' Runs the checks recommended before computing thermal indices from monthly
#' climatologies: number and order of layers, CRS, resolution and extent
#' agreement, plausible value range (a range beyond +/-100 suggests scaled
#' integers, as in WorldClim 1.4, which stored degrees C times 10), missing
#' values, identical NA masks and \eqn{T_{min} \le T_{max}}.
#'
#' @param tmin,tmax 12-layer `SpatRaster` objects.
#' @return A data frame with columns `check`, `value` and `ok`.
#' @export
check_monthly_climate <- function(tmin, tmax) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("check_monthly_climate() requires the 'terra' package.",
         call. = FALSE)
  }
  vmin <- terra::values(tmin)
  vmax <- terra::values(tmax)
  na_min <- !stats::complete.cases(vmin)
  na_max <- !stats::complete.cases(vmax)
  rng <- range(c(vmin, vmax), na.rm = TRUE)
  cross <- sum(vmin > vmax, na.rm = TRUE)
  geom <- isTRUE(terra::compareGeom(tmin, tmax, stopOnError = FALSE))
  rows <- list(
    c("layers tmin / tmax", sprintf("%d / %d", terra::nlyr(tmin),
                                    terra::nlyr(tmax)),
      terra::nlyr(tmin) == 12 && terra::nlyr(tmax) == 12),
    c("layer names (month order)", paste(names(tmin), collapse = ","), TRUE),
    c("CRS", terra::crs(tmin, describe = TRUE)$code, nzchar(terra::crs(tmin))),
    c("resolution", paste(signif(terra::res(tmin), 6), collapse = " x "),
      TRUE),
    c("extent", paste(signif(as.vector(terra::ext(tmin)), 7),
                      collapse = ", "), TRUE),
    c("same geometry", geom, geom),
    c("value range (degC)", paste(signif(rng, 4), collapse = " to "),
      rng[1] > -100 && rng[2] < 100),
    c("cells / valid cells", sprintf("%d / %d", nrow(vmin), sum(!na_min)),
      sum(!na_min) > 0),
    c("identical NA mask", identical(na_min, na_max),
      identical(na_min, na_max)),
    c("tmin > tmax (cell-months)", cross, cross == 0)
  )
  out <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(out) <- c("check", "value", "ok")
  out$ok <- as.logical(out$ok)
  out
}
