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
#' @param progress Show the download progress bar. Defaults to the option
#'   `thermify.progress`, or `TRUE` in interactive sessions.
#' @return A 12-layer `SpatRaster` with layers named `m01` to `m12`.
#' @references
#' Fick, S. E., & Hijmans, R. J. (2017). WorldClim 2: new 1-km spatial
#' resolution climate surfaces for global land areas. *International Journal
#' of Climatology*, 37(12), 4302-4315.
#' @export
worldclim_monthly <- function(var = c("tmin", "tmax"), res = 2.5, path,
                              country = NULL, timeout = 3600,
                              progress = getOption("thermify.progress",
                                                   interactive())) {
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
      download(sprintf("%s/tiles/iso/%s", base, basename(f)), f, timeout,
               progress)
    }
    r <- terra::rast(f)
  } else {
    tag <- sprintf("wc2.1_%sm_%s", format(res), var)
    dir <- file.path(path, "climate", sprintf("wc2.1_%sm", format(res)))
    tifs <- file.path(dir, sprintf("%s_%02d.tif", tag, 1:12))
    if (!all(vapply(tifs, valid_raster, logical(1), n = 1L))) {
      zip <- file.path(path, paste0(tag, ".zip"))
      if (!file.exists(zip)) {
        download(sprintf("%s/base/%s.zip", base, tag), zip, timeout,
                 progress)
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

#' Read WorldClim 2.1 at 30 arc-seconds for a region only
#'
#' Reads the 30 arc-second (about 1 km) WorldClim 2.1 normals (1970-2000) for
#' a region **without downloading global or country files**. The 30x30 degree
#' tiles published by WorldClim are opened remotely with GDAL's `/vsicurl/`
#' driver and only the strips that intersect the region are transferred via
#' HTTP range requests (for a 20 x 20 km window, a few hundred kilobytes per
#' variable instead of a 40 MB country file or a 450 MB global archive).
#' Regions spanning several tiles are read tile by tile and merged.
#'
#' When `region` is a polygon `SpatVector` and `mask = TRUE`, cells outside
#' the polygons are set to `NA` (cells touched by the boundary are kept when
#' `touches = TRUE`). The result is cached in `path`; a later call with the
#' same region, variable and mask reuses the cached file without network
#' access.
#'
#' This is the WorldClim 2.1 equivalent of the regional 30 arc-second
#' download that `raster::getData("worldclim", res = 0.5, lon, lat)` offered
#' for WorldClim 1.4. Coarser resolutions (2.5, 5 and 10 arc-minutes) are only
#' distributed as compressed global archives, which cannot be read partially;
#' use [worldclim_monthly()] for them. Aggregating the 30 arc-second data is
#' not a substitute: in tests over central Chile the official 2.5 arc-minute
#' product differed from the 5 x 5 cell mean of the 30 arc-second product by
#' up to about 0.9 degrees C.
#'
#' @param var One of `"tmin"`, `"tmax"`, `"tavg"`, `"prec"`, `"srad"`,
#'   `"wind"`, `"bio"` or `"elev"`.
#' @param region A `SpatExtent`, a numeric vector `c(xmin, xmax, ymin, ymax)`
#'   in longitude/latitude, or a `SpatVector` (any CRS; polygons can be used
#'   as a mask).
#' @param path Cache directory.
#' @param mask If `TRUE` and `region` is a polygon `SpatVector`, mask cells
#'   outside the polygons.
#' @param touches Passed to [terra::mask()]:
#'   keep cells touched by the polygon boundary.
#' @param overwrite Ignore and replace a cached file.
#' @return A `SpatRaster` in EPSG:4326 at 30 arc-seconds. Monthly variables
#'   have 12 layers named `m01` to `m12`; `bio` has 19 layers (`bio01` to
#'   `bio19`) and `elev` one layer. Attribute `"source"` lists the remote
#'   tiles read.
#' @references
#' Fick, S. E., & Hijmans, R. J. (2017). WorldClim 2: new 1-km spatial
#' resolution climate surfaces for global land areas. *International Journal
#' of Climatology*, 37(12), 4302-4315.
#' @seealso [worldclim_monthly()], [study_window()],
#'   [check_monthly_climate()].
#' @examples
#' \dontrun{
#' win <- study_window(-72.3225, -35.9671, size_km = 20)
#' tmin <- worldclim_region("tmin", win, path = "data")
#'
#' # Mask with a polygon (for example a commune boundary)
#' # comuna <- terra::vect("cauquenes.gpkg")
#' # tmax <- worldclim_region("tmax", comuna, path = "data", mask = TRUE)
#' }
#' @export
worldclim_region <- function(var = c("tmin", "tmax", "tavg", "prec", "srad",
                                     "wind", "bio", "elev"),
                             region, path, mask = TRUE, touches = TRUE,
                             overwrite = FALSE) {
  var <- match.arg(var)
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("worldclim_region() requires the 'terra' package.", call. = FALSE)
  }
  polygons <- NULL
  if (inherits(region, "SpatVector")) {
    region_ll <- terra::project(region, "EPSG:4326")
    if (terra::geomtype(region_ll) == "polygons") polygons <- region_ll
    e <- terra::ext(region_ll)
  } else if (inherits(region, "SpatExtent")) {
    e <- region
  } else if (is.numeric(region) && length(region) == 4L) {
    e <- terra::ext(region)
  } else {
    stop("`region` must be a SpatExtent, SpatVector or c(xmin, xmax, ymin, ",
         "ymax).", call. = FALSE)
  }
  v <- as.vector(e)
  if (v[1] < -180 || v[2] > 180 || v[3] < -90 || v[4] > 90 ||
      v[1] >= v[2] || v[3] >= v[4]) {
    stop("`region` must be a valid longitude/latitude extent.", call. = FALSE)
  }
  do_mask <- isTRUE(mask) && !is.null(polygons)

  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  key <- paste(sprintf("%.6f", v), collapse = "_")
  if (do_mask) {
    key <- paste0(key, "_mask", if (touches) "t" else "c",
                  sprintf("%08x", checksum32(terra::geom(polygons, wkt = TRUE))))
  }
  cache <- file.path(path, sprintf("wc2.1_30s_%s_region_%s.tif", var,
                                   checksum_name(key)))
  if (!overwrite && file.exists(cache)) {
    r <- terra::rast(cache)
    attr(r, "source") <- "cache"
    return(r)
  }

  tiles <- worldclim_tiles(v)
  base <- "https://geodata.ucdavis.edu/climate/worldclim/2_1/tiles/tile"
  urls <- sprintf("/vsicurl/%s/tile_%d_wc2.1_30s_%s.tif", base, tiles, var)
  old <- set_gdal_remote()
  on.exit(restore_gdal(old), add = TRUE)
  parts <- lapply(urls, function(u) {
    r <- terra::rast(u)
    ov <- terra::intersect(terra::ext(r), e)
    if (is.null(ov)) return(NULL)
    terra::crop(r, e, snap = "out")
  })
  parts <- Filter(Negate(is.null), parts)
  if (!length(parts)) stop("The region does not intersect any WorldClim tile.",
                           call. = FALSE)
  r <- if (length(parts) == 1L) parts[[1L]] else
    do.call(terra::merge, unname(parts))
  if (do_mask) {
    r <- terra::mask(r, polygons, touches = touches)
  }
  names(r) <- switch(var,
    bio = sprintf("bio%02d", seq_len(terra::nlyr(r))),
    elev = "elev",
    sprintf("m%02d", seq_len(terra::nlyr(r))))
  r <- terra::writeRaster(r, cache, overwrite = TRUE,
                          gdal = c("COMPRESS=DEFLATE"))
  attr(r, "source") <- sub("^/vsicurl/", "", urls)
  r
}

# WorldClim 30 arc-second tiles: 12 columns x 6 rows of 30 degrees, numbered
# row-wise from the north-west corner (tile 1 = 180-150 W, 60-90 N).
worldclim_tiles <- function(v) {
  eps <- 1e-9
  cols <- seq(floor((v[1] + 180) / 30), floor((v[2] - eps + 180) / 30))
  rows <- seq(floor((90 - v[4]) / 30), floor((90 - v[3] - eps) / 30))
  cols <- pmin(pmax(cols, 0), 11)
  rows <- pmin(pmax(rows, 0), 5)
  as.vector(outer(cols, rows * 12, `+`)) + 1L
}

# Remote-read settings: avoid directory listings and restrict to .tif.
set_gdal_remote <- function() {
  opts <- c(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR",
            CPL_VSIL_CURL_ALLOWED_EXTENSIONS = ".tif",
            GDAL_HTTP_MAX_RETRY = "3", GDAL_HTTP_RETRY_DELAY = "2")
  old <- vapply(names(opts), function(o) {
    val <- tryCatch(terra::getGDALconfig(o), error = function(e) "")
    if (length(val) == 0L || is.na(val)) "" else val
  }, character(1))
  for (o in names(opts)) terra::setGDALconfig(o, opts[[o]])
  old
}

restore_gdal <- function(old) {
  for (o in names(old)) terra::setGDALconfig(o, old[[o]])
}

# Small deterministic string hash used only to name cache files (all
# intermediate values stay below 2^53, so the arithmetic is exact).
checksum32 <- function(x) {
  h <- 0
  for (b in as.integer(charToRaw(paste(x, collapse = "")))) {
    h <- (h * 31 + b) %% 2147483647
  }
  h
}

checksum_name <- function(key) sprintf("%08x", checksum32(key))

valid_raster <- function(f, n) {
  file.exists(f) && isTRUE(tryCatch(terra::nlyr(terra::rast(f)) == n,
                                    error = function(e) FALSE))
}

download <- function(url, dest, timeout, progress = FALSE) {
  old <- options(timeout = max(timeout, getOption("timeout")))
  on.exit(options(old))
  tmp <- paste0(dest, ".part")
  if (isTRUE(progress)) message("Downloading ", url)
  status <- utils::download.file(url, tmp, mode = "wb",
                                 quiet = !isTRUE(progress))
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
