test_that("day length is symmetric around noon and seasonal", {
  d <- daylength(-35.97, c(172, 355))
  expect_equal(d$sunrise + d$sunset, c(24, 24))
  expect_lt(d$daylength[1], 10.5)  # southern winter solstice
  expect_gt(d$daylength[2], 14)    # southern summer solstice
  expect_equal(daylength(0, 80)$daylength, 12, tolerance = 0.15)
  expect_equal(daylength(80, 172)$daylength, 24)
  expect_equal(daylength(80, 355)$daylength, 0)
})

test_that("sine reconstruction honours extremes and continuity", {
  tmin <- c(2, 4, 3); tmax <- c(14, 16, 18)
  h <- hourly_temperatures(tmin, tmax, "sine", hour_tmin = 6, hour_tmax = 15)
  m <- matrix(h, nrow = 24)
  expect_equal(m[7, ], tmin)
  expect_equal(m[16, ], tmax)
  expect_length(h, 72)
  # No jump between 23 h and 0 h larger than the typical hourly change.
  expect_lt(abs(m[1, 2] - m[24, 1]), 2)
  expect_true(all(h >= min(tmin) - 1e-12 & h <= max(tmax) + 1e-12))
})

test_that("Linvill reconstruction reaches the minimum at sunrise", {
  tmin <- c(2, 4, 3); tmax <- c(14, 16, 18); doy <- 180:182
  h <- matrix(hourly_temperatures(tmin, tmax, latitude = -35.97, doy = doy),
              nrow = 24)
  expect_true(all(h[, 2] >= tmin[2] - 1e-9))
  expect_true(all(h[, 2] <= tmax[2] + 1e-9))
  expect_error(hourly_temperatures(tmin, tmax), "latitude")
})

test_that("cyclic boundaries and matrix input", {
  tmin <- rbind(c(2, 4, 3), c(5, 6, 7)); tmax <- tmin + 10
  h <- hourly_temperatures(tmin, tmax, "sine", cyclic = TRUE)
  expect_equal(dim(h), c(2, 72))
  expect_equal(h[1, ], hourly_temperatures(tmin[1, ], tmax[1, ], "sine",
                                           cyclic = TRUE))
  hl <- hourly_temperatures(tmin, tmax, latitude = c(-35, -40), doy = 1:3)
  expect_equal(hl[2, ], hourly_temperatures(tmin[2, ], tmax[2, ],
                                            latitude = -40, doy = 1:3))
})
