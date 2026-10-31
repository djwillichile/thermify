test_that("Utah weights follow the published intervals", {
  temp <- c(-5, 1.4, 1.41, 2.4, 2.41, 9.1, 9.11, 12.4, 12.41, 15.9, 15.91,
            18, 18.01, 30)
  expect_equal(utah_weights(temp),
               c(0, 0, 0.5, 0.5, 1, 1, 0.5, 0.5, 0, 0, -0.5, -0.5, -1, -1))
})

test_that("accumulation keeps negative values and is not truncated", {
  temp <- c(5, 5, 20, 20, 20, 20)
  expect_equal(chill_units(temp), c(1, 2, 1, 0, -1, -2))
  expect_equal(as.vector(chill_units(temp, output = "total")), -2)
  expect_equal(chill_units(temp, output = "hourly"), c(1, 1, -1, -1, -1, -1))
})

test_that("missing values are handled explicitly", {
  temp <- c(5, NA, 5)
  expect_equal(chill_units(temp), c(1, NA, NA))
  s <- chill_units(temp, na_action = "skip")
  expect_equal(as.vector(s), c(1, 1, 2))
  expect_equal(attr(s, "n_missing"), 1)
})

test_that("matrix input is processed by row", {
  m <- rbind(c(5, 5, 20), c(0, 10, 17))
  expect_equal(chill_units(m, output = "total"), c(1, 0))
  expect_equal(chill_units(m)[2, ], c(0, 0.5, 0))
})
