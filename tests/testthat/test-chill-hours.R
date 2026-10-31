test_that("chill hours cover 0 and 24 hour extremes", {
  expect_equal(chill_hours(1, 6), 24)
  expect_equal(chill_hours(10, 20), 0)
  expect_equal(chill_hours(-10, -2), 0)
  expect_equal(chill_hours(5, 5), 24)
  expect_equal(chill_hours(7.2, 7.2), 24)
  expect_equal(chill_hours(10, 10), 0)
})

test_that("intermediate values match the arcsine law", {
  # Interval [0, 7.2] symmetric around the mean of a sine with A = 7.2.
  expect_equal(chill_hours(-3.6, 10.8, lower = 0, upper = 7.2),
               24 * (2 * asin(0.5) / pi))
  # Half the day above the mean.
  expect_equal(chill_hours(0, 20, lower = 10, upper = 100), 12)
  expect_equal(chill_hours(0, 20, method = "triangle", lower = 0,
                           upper = 5), 6)
})

test_that("analytical sine agrees with numerical integration", {
  set.seed(7)
  tmin <- runif(300, -8, 12)
  tmax <- tmin + runif(300, 0, 20)
  expect_equal(chill_hours(tmin, tmax),
               chill_hours(tmin, tmax, method = "numerical", n_steps = 20000L),
               tolerance = 1e-3)
  expect_equal(chill_hours(tmin, tmax, lower = 2, upper = 12),
               chill_hours(tmin, tmax, method = "numerical", lower = 2,
                           upper = 12, n_steps = 20000L), tolerance = 1e-3)
})

test_that("alternative thresholds and bounds checks", {
  x <- chill_hours(c(-5, 0, 5), c(10, 15, 20), lower = -Inf, upper = 7.2)
  expect_true(all(x >= chill_hours(c(-5, 0, 5), c(10, 15, 20))))
  expect_true(all(x >= 0 & x <= 24))
  expect_error(chill_hours(0, 10, lower = 5, upper = 5), "lower < upper")
  expect_true(is.na(chill_hours(NA_real_, 10)))
})

test_that("hourly chill hours count the closed interval", {
  temp <- c(-1, 0, 3, 7.2, 7.3, NA, 4)
  expect_equal(chill_hours_hourly(temp, output = "hourly"),
               c(0, 1, 1, 1, 0, NA, 1))
  expect_true(is.na(chill_hours_hourly(temp, output = "total")))
  skip <- chill_hours_hourly(temp, output = "total", na_action = "skip")
  expect_equal(as.vector(skip), 4)
  expect_equal(attr(skip, "n_missing"), 1)
})
