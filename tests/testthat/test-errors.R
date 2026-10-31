# Error paths: every public entry point rejects invalid input with an
# informative message instead of returning numbers.

test_that("scalar and vector validators", {
  expect_error(degree_days(1, 5, base = c(1, 2)), "single finite number")
  expect_error(degree_days("a", 5), "numeric")
  expect_error(daylength(NA_real_, 1), "missing values")
  expect_error(daylength(95, 1), "within")
  expect_error(degree_hours(1:3, base = 10, upper = 5), "greater")
})

test_that("hourly reconstruction arguments", {
  m <- matrix(1:6, 2)
  expect_error(hourly_temperatures(m, matrix(1:4, 2), "sine"), "same dim")
  expect_error(hourly_temperatures(1:2, 3:4, latitude = -35, doy = 1),
               "one value per day")
  expect_error(hourly_temperatures(m, m + 5, latitude = c(1, 2, 3),
                                   doy = 1:3), "one value per series")
  expect_error(hourly_temperatures(1, 5, "sine", hour_tmin = 16,
                                   hour_tmax = 15), "hour_tmin")
})

test_that("workflow configuration", {
  tmin <- rep(5, 12); tmax <- rep(15, 12)
  expect_error(thermify(tmin, tmax, temporal = "native", base = c(5, 5)),
               "unique")
  expect_error(thermify(tmin, tmax, temporal = "native",
                        chill_period = "05-01"), "MM-DD")
  expect_error(thermify(tmin, tmax, temporal = "native", indices = "foo"))
  expect_error(threshold_date(1:3, as.Date("2023-01-01") + 0:1, 2),
               "same length")
})

test_that("raster inputs are checked before processing", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 12, crs = "EPSG:4326")
  r <- terra::setValues(r, 1)
  other <- terra::rast(nrows = 3, ncols = 2, nlyrs = 12, crs = "EPSG:4326")
  other <- terra::setValues(other, 2)
  expect_error(thermify_rast(matrix(1, 2, 12), r, tempfile()), "SpatRaster")
  expect_error(thermify_rast(r, other, tempfile()), "share CRS")
  expect_error(worldclim_monthly("tmin", res = 1, path = tempfile()),
               "one of")
  expect_error(worldclim_monthly("tmin", res = 0.5, path = tempfile()),
               "country")
})
