test_that("cauquenes_boundary() returns the requested level", {
  com <- cauquenes_boundary("comuna")
  expect_s4_class(com, "SpatVector")
  expect_equal(nrow(com), 1)
  expect_identical(com$CUT_COM, "07201")
  prov <- cauquenes_boundary("provincia")
  expect_identical(prov$CUT_PROV, "072")
  expect_identical(prov$nivel, "provincia")
})

test_that("English aliases, case and several levels are accepted", {
  expect_identical(cauquenes_boundary("Commune")$nivel, "comuna")
  expect_identical(cauquenes_boundary("province")$nivel, "provincia")
  both <- cauquenes_boundary(c("provincia", "comuna"))
  expect_identical(both$nivel, c("provincia", "comuna"))
  # Duplicates after aliasing are dropped.
  expect_equal(nrow(cauquenes_boundary(c("comuna", "commune"))), 1)
})

test_that("crs projects the boundary without changing its area", {
  ll <- cauquenes_boundary("comuna", crs = "EPSG:4326")
  expect_true(terra::same.crs(ll, "EPSG:4326"))
  expect_true(terra::same.crs(cauquenes_boundary("comuna"), "EPSG:5360"))
  expect_equal(terra::expanse(ll, unit = "km"), 2124.54, tolerance = 1e-3)
})

test_that("invalid levels give informative errors", {
  expect_error(cauquenes_boundary("region"), "Unknown `level`: \"region\"")
  expect_error(cauquenes_boundary(1), "must be")
  expect_error(cauquenes_boundary(character()), "must be")
  expect_error(cauquenes_boundary(NA_character_), "must be")
})

test_that("terra is declared in Depends so library(thermify) attaches it", {
  deps <- utils::packageDescription("thermify", fields = "Depends")
  expect_match(deps, "terra")
})
