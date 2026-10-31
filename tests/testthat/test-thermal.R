test_that("degree days are nonnegative and threshold aware", {
  expect_equal(degree_days(c(5, 10), c(15, 20), base = 10), c(0, 5))
})

test_that("constant-temperature chill duration is correct", {
  expect_equal(chill_hours(5, 5), 24)
  expect_equal(chill_hours(10, 10), 0)
})

test_that("chilling estimates stay within one day", {
  x <- chill_hours(c(-5, 0, 5), c(10, 15, 20))
  expect_true(all(x >= 0 & x <= 24))
})
