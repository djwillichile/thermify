test_that("WorldClim tile indices follow the 12 x 6 grid", {
  tiles <- thermify:::worldclim_tiles
  expect_equal(tiles(c(-179, -151, 61, 89)), 1)
  expect_equal(tiles(c(151, 179, 61, 89)), 12)
  expect_equal(tiles(c(-72.4, -72.2, -36.1, -35.8)), 52)
  expect_setequal(tiles(c(-60.2, -59.8, -30.2, -29.8)), c(40, 41, 52, 53))
  # Bounds on tile edges do not pull in neighbours.
  expect_equal(tiles(c(-90, -60, -60, -30)), 52)
})

test_that("cache keys are deterministic", {
  expect_identical(thermify:::checksum_name("abc"),
                   thermify:::checksum_name("abc"))
  expect_false(identical(thermify:::checksum_name("abc"),
                         thermify:::checksum_name("abd")))
})

test_that("worldclim_region validates its input", {
  skip_if_not_installed("terra")
  expect_error(worldclim_region("tmin", "Chile", tempfile()), "region")
  expect_error(worldclim_region("tmin", c(10, 5, 0, 1), tempfile()),
               "valid")
})

test_that("worldclim_region reads a window remotely and caches it", {
  skip_on_cran()
  skip_if_not_installed("terra")
  skip_if_not(identical(Sys.getenv("THERMIFY_ONLINE_TESTS"), "true"),
              "set THERMIFY_ONLINE_TESTS=true to run network tests")
  dir <- tempfile()
  e <- c(-72.36, -72.30, -36.00, -35.94)
  r <- worldclim_region("tmin", e, dir)
  expect_equal(terra::nlyr(r), 12)
  expect_equal(names(r), sprintf("m%02d", 1:12))
  expect_true(all(terra::res(r) - 1 / 120 < 1e-9))
  expect_length(list.files(dir, "\\.tif$"), 1)
  again <- worldclim_region("tmin", e, dir)
  expect_identical(attr(again, "source"), "cache")
  expect_equal(terra::values(again), terra::values(r))
  p <- terra::buffer(terra::vect(cbind(-72.33, -35.97), crs = "EPSG:4326"),
                     2000)
  m <- worldclim_region("tmax", p, dir, mask = TRUE)
  expect_true(anyNA(terra::values(m[[1]])))
})

test_that("the packaged DPA 2023 boundaries of Cauquenes are valid", {
  skip_if_not_installed("terra")
  f <- system.file("extdata", "cauquenes.gpkg", package = "thermify")
  expect_true(nzchar(f))
  expect_setequal(terra::vector_layers(f), c("comuna", "provincia"))
  comuna <- terra::vect(f, layer = "comuna")
  provincia <- terra::vect(f, layer = "provincia")
  expect_equal(nrow(comuna), 1)
  expect_equal(comuna$CUT_COM, "07201")
  expect_equal(provincia$CUT_PROV, "072")
  expect_equal(terra::crs(comuna, describe = TRUE)$code, "5360")
  expect_true(all(terra::is.valid(comuna)))
  # Computed area matches the DPA SUPERFICIE attribute (km2).
  expect_equal(terra::expanse(comuna, unit = "km"), comuna$SUPERFICIE,
               tolerance = 1e-3)
  expect_equal(terra::expanse(provincia, unit = "km"), provincia$SUPERFICIE,
               tolerance = 1e-3)
})

test_that("worldclim_region masks WorldClim with the commune polygon", {
  skip_on_cran()
  skip_if_not_installed("terra")
  skip_if_not(identical(Sys.getenv("THERMIFY_ONLINE_TESTS"), "true"),
              "set THERMIFY_ONLINE_TESTS=true to run network tests")
  f <- system.file("extdata", "cauquenes.gpkg", package = "thermify")
  comuna <- terra::vect(f, layer = "comuna")
  r <- worldclim_region("tmin", comuna, tempfile(), mask = TRUE)
  inside <- sum(!is.na(terra::values(r[[1]], mat = FALSE)))
  # 30 arc-second cells are about 0.68 km2 at this latitude.
  expect_equal(inside * 0.68, 2124.5, tolerance = 0.1)
  expect_lt(inside, terra::ncell(r))
})
