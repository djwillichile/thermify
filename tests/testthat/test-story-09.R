# US-09 Protection against common input mistakes (docs/USER_STORIES.md)

test_that("swapped extremes are reported, not corrected", {
  expect_error(degree_days(c(5, 20), c(15, 10)), "first at position 2")
  expect_error(chill_hours(c(5, 20), c(15, 10)), "never swaps")
  expect_error(densify_monthly(rep(20, 12), rep(10, 12), engine = "native"),
               "exceeds")
})

test_that("frequency is never inferred from the number of values", {
  daily <- 1:365
  expect_error(thermify(daily, daily + 10, input = "monthly"), "12 values")
  dates <- as.Date("2023-05-01") + c(0:9, 11)
  expect_error(thermify(rep(3, 11), rep(13, 11), input = "daily",
                        dates = dates, indices = "gdd"), "consecutive")
  expect_error(thermify(temperature = rep(5, 30), input = "hourly",
                        dates = as.Date("2023-05-01") + 0:1), "24 values")
})

test_that("scaled or inconsistent monthly rasters are flagged", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 12, crs = "EPSG:4326")
  tmin <- terra::setValues(r, rep(c(50, 60, 70, 80), 12))   # degC x 10
  tmax <- terra::setValues(r, rep(c(150, 160, 170, 180), 12))
  chk <- check_monthly_climate(tmin, tmax)
  expect_false(chk$ok[chk$check == "value range (degC)"])
  tmax_ok <- terra::setValues(r, rep(c(15, 16, 17, 18), 12))
  tmin_na <- terra::setValues(r, rep(c(5, NA, 7, 8), 12))
  chk2 <- check_monthly_climate(tmin_na, tmax_ok)
  expect_false(chk2$ok[chk2$check == "identical NA mask"])
})
