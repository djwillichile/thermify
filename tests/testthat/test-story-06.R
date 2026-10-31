# US-06 Reproducible and traceable results (docs/USER_STORIES.md)

tmin_m <- c(11.8, 11.1, 9.6, 7.9, 6.6, 5.5, 4.8, 4.9, 5.9, 7.5, 9.2, 11.1)
tmax_m <- c(27.4, 26.5, 23.5, 19.3, 15.5, 12.9, 12.6, 13.9, 16.1, 18.8, 21.9,
            25.2)

test_that("single-site results carry provenance", {
  res <- thermify(tmin_m, tmax_m, temporal = "native", indices = "gdd")
  p <- res$provenance
  expect_identical(p$input, "monthly")
  expect_identical(p$thermify, as.character(utils::packageVersion("thermify")))
  d <- p$densification
  expect_identical(d$engine, "native")
  expect_identical(d$method, "pchip_mp")
  expect_equal(d$year, 2023)
  expect_identical(d$consistency, "check")
  expect_lt(d$max_abs_mean_error, 1e-8)
  expect_identical(res$config$base, c(5, 10))
})

test_that("raster runs write a complete provenance file", {
  skip_if_not_installed("terra")
  skip_if_not_installed("jsonlite")
  r <- terra::rast(nrows = 3, ncols = 3, nlyrs = 12, xmin = -72.4,
                   xmax = -72.3, ymin = -36, ymax = -35.9, crs = "EPSG:4326")
  tmin <- terra::setValues(r, rep(tmin_m, each = 9))
  tmax <- terra::setValues(r, rep(tmax_m, each = 9))
  dir <- tempfile()
  thermify_rast(tmin, tmax, output_dir = dir, temporal = "native",
                indices = "gdd", gdd_methods = "average", base = 10)
  p <- jsonlite::read_json(file.path(dir, "provenance.json"))
  for (f in c("thermify", "terra", "year", "engine", "interpolation",
              "consistency", "config", "crs", "resolution", "extent",
              "n_valid_cells", "outputs")) {
    expect_true(f %in% names(p), info = f)
  }
  expect_equal(p$n_valid_cells, 9)
  expect_equal(p$crs, "4326")
})

test_that("tempify version and commit are recorded when it is used", {
  skip_if_not(tempify_available(), "tempify not available")
  res <- thermify(tmin_m, tmax_m, temporal = "tempify", indices = "gdd")
  tv <- res$provenance$densification$tempify
  expect_true(nzchar(tv$tempify))
  expect_true("commit" %in% names(tv))
})

test_that("identical inputs give identical outputs", {
  a <- thermify(tmin_m, tmax_m, latitude = -35.97, temporal = "native")
  b <- thermify(tmin_m, tmax_m, latitude = -35.97, temporal = "native")
  expect_identical(a$daily, b$daily)
  expect_identical(a$summary, b$summary)
})
