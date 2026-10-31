d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "day")

test_that("non-wrapping windows", {
  idx <- season_days(d, "05-01", "08-31")
  expect_equal(length(idx), 123)
  expect_equal(d[idx[1]], as.Date("2023-05-01"))
})

test_that("wrapping windows in a climatological year are reordered", {
  idx <- season_days(d, "09-01", "04-30", cyclic = TRUE)
  expect_equal(length(idx), 365 - 123 + 0)
  expect_equal(d[idx[1]], as.Date("2023-09-01"))
  expect_equal(d[idx[length(idx)]], as.Date("2023-04-30"))
})

test_that("wrapping windows in observed series are labelled by season", {
  dd <- seq(as.Date("2021-07-01"), as.Date("2023-06-30"), by = "day")
  idx <- season_days(dd, "09-01", "04-30")
  expect_setequal(unique(attr(idx, "season")), c(2021L, 2022L))
  expect_error(season_days(dd, "13-01", "04-30"), "valid date")
  expect_error(season_days(dd, "9-1", "04-30"), "MM-DD")
})
