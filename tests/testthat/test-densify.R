tmin_m <- c(11.4, 11.1, 9.2, 6.8, 5.3, 3.9, 3.1, 3.6, 4.6, 6.3, 8.4, 10.3)
tmax_m <- c(29.6, 29.2, 26.5, 21.9, 17.2, 13.9, 13.6, 15.3, 17.9, 21.2,
            24.9, 28.2)

test_that("native pchip_mp preserves monthly means for 365 and 366 days", {
  for (yr in c(2023, 2024)) {
    d <- densify_monthly(tmin_m, tmax_m, year = yr, engine = "native")
    expect_equal(ncol(d$tmin), if (yr == 2024) 366 else 365)
    month <- as.integer(format(d$dates, "%m"))
    expect_equal(as.vector(tapply(d$tmin[1, ], month, mean)), tmin_m,
                 tolerance = 1e-8)
    expect_equal(as.vector(tapply(d$tmax[1, ], month, mean)), tmax_m,
                 tolerance = 1e-8)
    expect_true(all(d$tmin <= d$tmax))
  }
})

test_that("plain pchip does not preserve means but interpolates anchors", {
  d <- densify_monthly(tmin_m, tmax_m, method = "pchip", engine = "native")
  anchors <- thermify:::month_anchor_doy(2023)
  expect_equal(d$tmin[1, anchors], tmin_m)
  expect_gt(d$provenance$max_abs_mean_error, 0.01)
})

test_that("rows with missing months are NA and others unaffected", {
  m <- rbind(tmin_m, replace(tmin_m, 3, NA))
  d <- densify_monthly(m, rbind(tmax_m, tmax_m), engine = "native")
  expect_true(all(is.na(d$tmin[2, ])))
  single <- densify_monthly(tmin_m, tmax_m, engine = "native")
  expect_equal(d$tmin[1, ], single$tmin[1, ])
})

test_that("mean_range consistency preserves means of both extremes", {
  d <- densify_monthly(tmin_m, tmax_m, engine = "native",
                       consistency = "mean_range")
  month <- as.integer(format(d$dates, "%m"))
  expect_equal(as.vector(tapply(d$tmin[1, ], month, mean)), tmin_m,
               tolerance = 1e-8)
  expect_equal(as.vector(tapply(d$tmax[1, ], month, mean)), tmax_m,
               tolerance = 1e-8)
})

test_that("crossings are detected, never silently fixed", {
  # Nearly identical extremes with opposite curvature force crossings.
  lo <- c(10, 0, 10, 0, 10, 0, 10, 0, 10, 0, 10, 0)
  hi <- lo + c(0.01, 3, 0.01, 3, 0.01, 3, 0.01, 3, 0.01, 3, 0.01, 3)
  expect_error(densify_monthly(lo, hi, engine = "native"), "tmin > tmax")
  expect_error(densify_monthly(tmax_m, tmin_m, engine = "native"),
               "exceeds")
})

test_that("diagnostics report boundary steps", {
  d <- densify_monthly(tmin_m, tmax_m, engine = "native")
  diag <- densify_diagnostics(d$tmin, tmin_m, d$dates)
  expect_lt(diag$max_abs_mean_error, 1e-8)
  expect_gt(diag$max_boundary_step, 0)
})

test_that("native engine matches tempify", {
  skip_if_not(tempify_available(), "tempify not available")
  m <- rbind(tmin_m, tmin_m + 1.3, rep(NA, 12))
  for (yr in c(2023, 2024)) for (meth in c("pchip", "pchip_mp")) {
    a <- densify_monthly(m, m + 15, year = yr, method = meth,
                         engine = "native")
    b <- densify_monthly(m, m + 15, year = yr, method = meth,
                         engine = "tempify")
    expect_equal(a$tmin, b$tmin, tolerance = 1e-9)
    expect_equal(a$tmax, b$tmax, tolerance = 1e-9)
  }
  v <- tempify_version()
  expect_true(all(c("tempify", "commit", "python") %in% names(v)))
})

test_that("input validation", {
  expect_error(densify_monthly(1:11, 1:11), "12 monthly")
  expect_error(densify_monthly(tmin_m, tmax_m, engine = "native",
                               method = "akima"), "native engine")
})
