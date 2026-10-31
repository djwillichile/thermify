# US-04 Maps for a territory from WorldClim (docs/USER_STORIES.md)

skip_if_not_installed("terra")

synthetic_monthly <- function() {
  r <- terra::rast(nrows = 12, ncols = 12, nlyrs = 12, xmin = -72.45,
                   xmax = -72.2, ymin = -36.06, ymax = -35.87,
                   crs = "EPSG:4326")
  xy <- terra::crds(r[[1]], na.rm = FALSE)
  grad <- (xy[, 1] + 72.3) * 4
  bmin <- c(11.8, 11.1, 9.6, 7.9, 6.6, 5.5, 4.8, 4.9, 5.9, 7.5, 9.2, 11.1)
  bmax <- c(27.4, 26.5, 23.5, 19.3, 15.5, 12.9, 12.6, 13.9, 16.1, 18.8,
            21.9, 25.2)
  list(tmin = terra::setValues(r, outer(grad, bmin, "+")),
       tmax = terra::setValues(r, outer(grad, bmax, "+")))
}

territory <- function() {
  terra::buffer(terra::vect(cbind(-72.3225, -35.9671), crs = "EPSG:4326"),
                7000)
}

test_that("cells outside the territory stay NA and geometry is kept", {
  s <- synthetic_monthly()
  poly <- territory()
  tmin <- terra::mask(s$tmin, poly)
  tmax <- terra::mask(s$tmax, poly)
  out <- thermify_rast(tmin, tmax, output_dir = tempfile(),
                       temporal = "native", indices = c("gdd", "cp"),
                       gdd_methods = "single_sine", base = 10)
  outside <- is.na(terra::values(tmin[[1]], mat = FALSE))
  expect_true(any(outside) && any(!outside))
  for (k in names(out)) {
    expect_true(terra::compareGeom(out[[k]], tmin))
    v <- terra::values(out[[k]]$season, mat = FALSE)
    expect_identical(is.na(v), outside)
  }
})

test_that("each index is one file with named layers and units", {
  s <- synthetic_monthly()
  dir <- tempfile()
  out <- thermify_rast(s$tmin, s$tmax, output_dir = dir, temporal = "native",
                       indices = c("gdd", "cu"), gdd_methods = "average",
                       base = 5)
  expect_setequal(list.files(dir, "\\.tif$"),
                  c("gdd_average_b5.tif", "cu_utah.tif"))
  gdd <- terra::rast(file.path(dir, "gdd_average_b5.tif"))
  expect_equal(names(gdd), c("season", "annual", sprintf("m%02d", 1:12)))
  expect_equal(unique(terra::units(out$gdd_average_b5)), "degC day")
  # Utah has no calendar-year total: chill is accumulated in its period.
  expect_false("annual" %in% names(out$cu_utah))
})

test_that("WorldClim is read for the territory only and masked", {
  skip_on_cran()
  skip_if_not(identical(Sys.getenv("THERMIFY_ONLINE_TESTS"), "true"),
              "set THERMIFY_ONLINE_TESTS=true to run network tests")
  poly <- territory()
  dir <- tempfile()
  tmin <- worldclim_region("tmin", poly, dir, mask = TRUE)
  tmax <- worldclim_region("tmax", poly, dir, mask = TRUE)
  e <- terra::ext(poly)
  expect_lte(terra::xmax(tmin) - terra::xmin(tmin),
             terra::xmax(e) - terra::xmin(e) + 2 / 120)
  expect_true(all(check_monthly_climate(tmin, tmax)$ok))
  # Only the window was stored locally (kilobytes, not country files).
  expect_lt(sum(file.size(list.files(dir, full.names = TRUE))), 1e6)
  out <- thermify_rast(tmin, tmax, output_dir = tempfile(),
                       temporal = "native", indices = "gdd",
                       gdd_methods = "single_sine", base = 10)
  expect_identical(
    is.na(terra::values(out$gdd_single_sine_b10$season, mat = FALSE)),
    is.na(terra::values(tmin[[1]], mat = FALSE)))
})
