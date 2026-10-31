# US-07 Large regions on modest hardware (docs/USER_STORIES.md)

skip_if_not_installed("terra")

stack <- function(nrow = 10, ncol = 8) {
  set.seed(7)
  r <- terra::rast(nrows = nrow, ncols = ncol, nlyrs = 12, xmin = -73,
                   xmax = -72, ymin = -37, ymax = -36, crs = "EPSG:4326")
  bmin <- c(11.8, 11.1, 9.6, 7.9, 6.6, 5.5, 4.8, 4.9, 5.9, 7.5, 9.2, 11.1)
  off <- stats::rnorm(nrow * ncol, 0, 1.5)
  list(tmin = terra::setValues(r, outer(off, bmin, "+")),
       tmax = terra::setValues(r, outer(off, bmin + 14, "+")))
}

run <- function(s, max_cells, ...) {
  thermify_rast(s$tmin, s$tmax, output_dir = tempfile(), temporal = "native",
                indices = c("gdd", "cu", "cp"), gdd_methods = "single_sine",
                base = 10, max_cells = max_cells, ...)
}

test_that("block size sets the number of blocks and is recorded", {
  s <- stack()
  small <- run(s, max_cells = 16)   # 2 rows of 8 cells per block
  big <- run(s, max_cells = 1e6)
  expect_equal(attr(small, "provenance")$n_blocks, 5)
  expect_equal(attr(big, "provenance")$n_blocks, 1)
  expect_equal(attr(small, "provenance")$max_cells_per_block, 16)
})

test_that("results do not depend on the block size", {
  s <- stack()
  a <- run(s, max_cells = 8)
  b <- run(s, max_cells = 24)
  c <- run(s, max_cells = 1e6)
  for (k in names(a)) {
    expect_equal(terra::values(a[[k]]), terra::values(c[[k]]), info = k)
    expect_equal(terra::values(b[[k]]), terra::values(c[[k]]), info = k)
  }
})

test_that("daily rasters are written only on request", {
  s <- stack(4, 4)
  dir <- tempfile()
  thermify_rast(s$tmin, s$tmax, output_dir = dir, temporal = "native",
                indices = "gdd", gdd_methods = "average", base = 10)
  expect_false(any(grepl("^daily_", list.files(dir))))
  dir2 <- tempfile()
  thermify_rast(s$tmin, s$tmax, output_dir = dir2, temporal = "native",
                indices = "gdd", gdd_methods = "average", base = 10,
                keep_daily = TRUE)
  d <- terra::rast(file.path(dir2, "daily_tmin.tif"))
  expect_equal(terra::nlyr(d), 365)
  expect_equal(names(d)[c(1, 365)], c("2023-01-01", "2023-12-31"))
})
