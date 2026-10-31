skip_if_not_installed("terra")

make_stack <- function(seed = 1, nrow = 6, ncol = 5, crs = "EPSG:4326") {
  set.seed(seed)
  r <- terra::rast(nrows = nrow, ncols = ncol, nlyrs = 12, xmin = -72.4,
                   xmax = -72.3, ymin = -36, ymax = -35.9, crs = crs)
  bmin <- c(11, 11, 9, 7, 5, 4, 3, 4, 5, 6, 8, 10)
  bmax <- c(29, 29, 26, 22, 17, 14, 13, 15, 18, 21, 25, 28)
  off <- stats::rnorm(nrow * ncol)
  tmin <- terra::setValues(r, outer(off, bmin, "+"))
  tmax <- terra::setValues(r, outer(off * 0.5, bmax, "+"))
  tmin[3] <- NA
  tmax[3] <- NA
  list(tmin = tmin, tmax = tmax)
}

test_that("raster outputs keep geometry and NA mask, blocks are exact", {
  s <- make_stack()
  a <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                     temporal = "native", max_cells = 7,
                     format = c("GTiff", "netCDF"))
  b <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                     temporal = "native", max_cells = 1e6)
  for (k in names(a)) {
    expect_true(terra::compareGeom(a[[k]], s$tmin))
    expect_equal(terra::values(a[[k]]), terra::values(b[[k]]))
    expect_true(is.na(terra::values(a[[k]])[3, 1]))
    expect_false(anyNA(terra::values(a[[k]])[-3, "season"]))
  }
  prov <- attr(a, "provenance")
  expect_equal(prov$n_valid_cells, 29)
  dir <- dirname(terra::sources(a$cp_dynamic))
  expect_true(file.exists(file.path(dir, "cp_dynamic.nc")))
  back <- terra::rast(file.path(dir, "gdd_average_b10.tif"))
  expect_equal(names(back), c("season", "annual", sprintf("m%02d", 1:12)))
})

test_that("raster cells match the single-site workflow", {
  s <- make_stack()
  a <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                     temporal = "native")
  cell <- 10
  lat <- terra::yFromCell(s$tmin, cell)
  x <- thermify(as.numeric(s$tmin[cell]), as.numeric(s$tmax[cell]),
                latitude = lat, temporal = "native")
  for (k in names(a)) {
    expect_equal(as.numeric(a[[k]]$season[cell]),
                 x$summary$value[x$summary$key == k &
                                   x$summary$aggregation == "season"],
                 tolerance = 1e-5)
  }
})

test_that("projected CRS uses cell latitude and existing files are protected", {
  s <- make_stack()
  pr <- lapply(s, terra::project, "EPSG:32718")
  out <- tempfile()
  r <- thermify_rast(pr$tmin, pr$tmax, output_dir = out, temporal = "native",
                     indices = "cp")
  expect_true(terra::compareGeom(r$cp_dynamic, pr$tmin))
  expect_error(thermify_rast(pr$tmin, pr$tmax, output_dir = out,
                             temporal = "native", indices = "cp"), "exist")
  expect_error(thermify_rast(s$tmin[[1:11]], s$tmax[[1:11]], tempfile()),
               "12 monthly")
})
