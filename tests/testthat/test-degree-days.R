test_that("average method matches the textbook formula", {
  expect_equal(degree_days(c(5, 10), c(15, 20), method = "average",
                           base = 10), c(0, 5))
  expect_equal(degree_days(20, 30, method = "average", base = 10,
                           upper = 22), 12)
  expect_equal(degree_days(20, 30, method = "average", base = 10, upper = 22,
                           cutoff = "vertical"), 0)
  expect_equal(degree_days(20, 30, method = "average", base = 10, upper = 22,
                           cutoff = "intermediate"), 12 - 3)
})

test_that("single sine reproduces known closed-form values", {
  # Entirely above the base: mean minus base.
  expect_equal(degree_days(12, 20, base = 10), 6)
  # Entirely below: zero.
  expect_equal(degree_days(0, 8, base = 10), 0)
  # Base at the daily mean: amplitude / pi.
  expect_equal(degree_days(0, 20, base = 10), 10 / pi)
  # Intercepted by the base (Baskerville & Emin 1969).
  m <- 12; a <- 8; th <- asin((10 - m) / a)
  expect_equal(degree_days(4, 20, base = 10),
               ((m - 10) * (pi / 2 - th) + a * cos(th)) / pi)
})

test_that("single triangle reproduces known closed-form values", {
  expect_equal(degree_days(12, 20, method = "single_triangle", base = 10), 6)
  expect_equal(degree_days(0, 20, method = "single_triangle", base = 10),
               10^2 / (2 * 20))
  expect_equal(degree_days(4, 20, method = "single_triangle", base = 10),
               (20 - 10)^2 / (2 * 16))
})

test_that("constant temperatures give the trivial answer for all methods", {
  for (m in c("average", "single_sine", "single_triangle", "double_sine",
              "double_triangle")) {
    expect_equal(degree_days(c(15, 15), c(15, 15), method = m, base = 10,
                             tmin_next = c(15, 15)), c(5, 5))
    expect_equal(degree_days(8, 8, method = m, base = 10, tmin_next = 8), 0)
  }
})

test_that("analytical methods agree with numerical integration", {
  set.seed(42)
  tmin <- runif(200, -5, 20)
  tmax <- tmin + runif(200, 0, 25)
  for (shape in c("sine", "triangle")) {
    vals <- thermify:::profile_values(tmin, tmax, n = 20000L, shape = shape)
    for (cut in c("horizontal", "vertical", "intermediate")) {
      rate <- switch(cut,
        horizontal = pmax(0, pmin(vals, 30) - 10),
        vertical = ifelse(vals > 30, 0, pmax(0, vals - 10)),
        intermediate = ifelse(vals > 30, pmax(0, 20 - (vals - 30)),
                              pmax(0, vals - 10)))
      expect_equal(
        degree_days(tmin, tmax, method = paste0("single_", shape), base = 10,
                    upper = 30, cutoff = cut),
        rowMeans(matrix(rate, nrow = nrow(vals))),
        # The vertical cutoff integrand is discontinuous, so the midpoint
        # rule converges only at O(1/n).
        tolerance = if (cut == "vertical") 5e-4 else 1e-6)
    }
  }
})

test_that("cutoffs are distinct when the upper threshold is exceeded", {
  args <- list(tmin = 15, tmax = 38, base = 10, upper = 30)
  h <- do.call(degree_days, c(args, cutoff = "horizontal"))
  v <- do.call(degree_days, c(args, cutoff = "vertical"))
  i <- do.call(degree_days, c(args, cutoff = "intermediate"))
  expect_true(h > i && i > v)
  # Below the upper threshold all cutoffs coincide.
  below <- vapply(c("horizontal", "vertical", "intermediate"), function(cut)
    degree_days(5, 25, base = 10, upper = 30, cutoff = cut), numeric(1))
  expect_equal(unname(below), rep(below[[1]], 3))
  # Entirely above the upper threshold.
  expect_equal(degree_days(32, 40, base = 10, upper = 30), 20)
  expect_equal(degree_days(32, 40, base = 10, upper = 30,
                           cutoff = "vertical"), 0)
})

test_that("double methods average two half days", {
  tmin <- c(5, 9); tmax <- c(25, 27)
  ss <- degree_days(c(5, 9), c(25, 25), base = 10)
  expect_equal(degree_days(tmin, tmax, method = "double_sine", base = 10)[1],
               mean(ss))
  # With identical consecutive minima double equals single.
  expect_equal(degree_days(c(5, 5), c(25, 25), method = "double_sine",
                           base = 10, tmin_next = c(5, 5)),
               degree_days(c(5, 5), c(25, 25), base = 10))
  # Last day is NA without an explicit next minimum.
  expect_true(is.na(degree_days(tmin, tmax, method = "double_triangle",
                                base = 10)[2]))
  # Next minimum above the current maximum is handled symmetrically.
  expect_equal(degree_days(5, 15, method = "double_sine", base = 10,
                           tmin_next = 20),
               (degree_days(5, 15, base = 10) +
                  degree_days(15, 20, base = 10)) / 2)
})

test_that("missing values propagate per day", {
  out <- degree_days(c(5, NA, 8), c(15, 20, NA), base = 10)
  expect_false(is.na(out[1]))
  expect_true(all(is.na(out[2:3])))
})

test_that("invalid input gives informative errors", {
  expect_error(degree_days(20, 10), "exceeds")
  expect_error(degree_days(1:2, 1:3), "same length")
  expect_error(degree_days(5, 20, base = 10, upper = 5), "greater")
  expect_error(degree_days(5, 20, method = "double_sine", tmin_next = 1:2),
               "same length")
  expect_error(degree_days(5, 20, method = "foo"))
})

test_that("degree hours convert to degree days with 24 hours per day", {
  temp <- c(rep(15, 24), rep(5, 24))
  expect_equal(degree_hours(temp, base = 10, by_day = TRUE), c(5, 0))
  expect_equal(sum(degree_hours(temp, base = 10)), 120)
  expect_equal(degree_hours(c(35, 25), base = 10, upper = 30,
                            cutoff = "vertical"), c(0, 15))
  expect_equal(degree_hours(35, base = 10, upper = 30,
                            cutoff = "intermediate"), 15)
  expect_error(degree_hours(1:25, by_day = TRUE), "multiple of 24")
  m <- matrix(c(temp, temp + 1), nrow = 2, byrow = TRUE)
  expect_equal(degree_hours(m, base = 10, by_day = TRUE),
               rbind(c(5, 0), c(6, 0)))
})
