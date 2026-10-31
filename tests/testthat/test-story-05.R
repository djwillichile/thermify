# US-05 Comparing methods on the same data (docs/USER_STORIES.md)

methods <- c("average", "single_sine", "single_triangle", "double_sine",
             "double_triangle")
tmin_m <- c(11.8, 11.1, 9.6, 7.9, 6.6, 5.5, 4.8, 4.9, 5.9, 7.5, 9.2, 11.1)
tmax_m <- c(27.4, 26.5, 23.5, 19.3, 15.5, 12.9, 12.6, 13.9, 16.1, 18.8, 21.9,
            25.2)

test_that("one tidy table covers every method and base", {
  res <- thermify(tmin_m, tmax_m, temporal = "native", indices = "gdd",
                  gdd_methods = methods, base = c(5, 10))
  s <- res$summary
  expected <- as.vector(outer(methods, c(5, 10), function(m, b)
    sprintf("gdd_%s_b%s", m, b)))
  expect_setequal(unique(s$key), expected)
  expect_true(all(c("index", "key", "aggregation", "value", "units") %in%
                    names(s)))
  expect_true(all(s$units == "degC day"))
  expect_setequal(unique(s$aggregation),
                  c("season", "annual", sprintf("m%02d", 1:12)))
})

test_that("results respect Jensen's inequality and agree away from the base", {
  set.seed(5)
  tmin <- stats::runif(500, -5, 20)
  tmax <- tmin + stats::runif(500, 0, 20)
  avg <- degree_days(tmin, tmax, method = "average", base = 10)
  for (m in c("single_sine", "single_triangle")) {
    expect_true(all(degree_days(tmin, tmax, method = m, base = 10) >=
                      avg - 1e-12), info = m)
  }
  warm <- tmin > 10
  for (m in methods[-1]) {
    v <- degree_days(tmin[warm], tmax[warm], method = m, base = 10,
                     tmin_next = tmin[warm])
    expect_equal(v, avg[warm], info = m)
  }
})

test_that("adding methods does not change any single result", {
  one <- thermify(tmin_m, tmax_m, temporal = "native", indices = "gdd",
                  gdd_methods = "single_sine", base = 10)
  all_m <- thermify(tmin_m, tmax_m, temporal = "native", indices = "gdd",
                    gdd_methods = methods, base = c(5, 10))
  key <- "gdd_single_sine_b10"
  expect_equal(all_m$daily[[key]], one$daily[[key]])
})
