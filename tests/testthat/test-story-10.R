# US-10 Feedback during long processes (docs/USER_STORIES.md)

skip_if_not_installed("terra")

small_stack <- function() {
  r <- terra::rast(nrows = 6, ncols = 4, nlyrs = 12, xmin = -73, xmax = -72,
                   ymin = -37, ymax = -36, crs = "EPSG:4326")
  bmin <- c(11.8, 11.1, 9.6, 7.9, 6.6, 5.5, 4.8, 4.9, 5.9, 7.5, 9.2, 11.1)
  list(tmin = terra::setValues(r, rep(bmin, each = 24)),
       tmax = terra::setValues(r, rep(bmin + 14, each = 24)))
}

run <- function(...) {
  s <- small_stack()
  thermify_rast(s$tmin, s$tmax, output_dir = tempfile(), temporal = "native",
                indices = "gdd", gdd_methods = "average", base = 10,
                max_cells = 4, ...)
}

test_that("progress reports blocks, percentage, elapsed time and ETA", {
  msgs <- testthat::capture_messages(run(progress = TRUE))
  expect_gte(length(msgs), 2)
  expect_match(msgs[1], "thermify_rast .* 1/6 \\| elapsed .* \\| ETA ")
  last <- msgs[length(msgs)]
  expect_match(last, "100% 6/6")
  expect_match(last, "ETA 0:00")
  expect_match(last, "24 valid cells")
})

test_that("non-interactive logs are throttled to first and last lines", {
  # Six fast blocks: only the first and the final line are written.
  msgs <- testthat::capture_messages(run(progress = TRUE))
  expect_length(msgs, 2)
})

test_that("progress can be switched off globally or per call", {
  expect_silent(run(progress = FALSE))
  withr::local_options(thermify.progress = FALSE)
  expect_silent(run())
})

test_that("elapsed and remaining times are human readable", {
  fmt <- thermify:::format_seconds
  expect_equal(fmt(5), "0:05")
  expect_equal(fmt(125), "2:05")
  expect_equal(fmt(3725), "1:02:05")
  expect_equal(fmt(NA), "--:--")
})
