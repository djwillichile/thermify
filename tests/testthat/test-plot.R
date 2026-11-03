plot_maps <- function(indices = c("gdd", "ch", "cu", "cp")) {
  r <- terra::rast(nrows = 3, ncols = 3, nlyrs = 12, xmin = -72.4,
                   xmax = -72.3, ymin = -36, ymax = -35.9, crs = "EPSG:4326")
  base_min <- c(11, 11, 9, 7, 5, 4, 3, 4, 5, 6, 8, 10)
  base_max <- c(29, 29, 26, 22, 17, 14, 13, 15, 18, 21, 25, 28)
  off <- seq(-1, 1, length.out = 9)
  tmin <- terra::setValues(r, outer(off, base_min, "+"))
  tmax <- terra::setValues(r, outer(off, base_max, "+"))
  thermify_rast(tmin, tmax, output_dir = tempfile(), temporal = "native",
                latitude = -35.97, indices = indices,
                gdd_methods = c("average", "single_sine"), base = 10,
                ch_methods = c("sine", "hourly"), progress = FALSE)
}

# Draw on a throw-away device and record how many panels were drawn.
draw <- function(expr) {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f)
  on.exit(grDevices::dev.off())
  n <- 0L
  trace_env <- environment()
  testthat::local_mocked_bindings(
    draw_panel = function(...) {
      assign("n", get("n", trace_env) + 1L, trace_env)
      invisible(NULL)
    })
  force(expr)
  n
}

test_that("thermify_rast() returns a classed list that still subsets", {
  m <- plot_maps()
  expect_s3_class(m, "thermify_rast")
  expect_type(m, "list")
  expect_s4_class(m$cp_dynamic, "SpatRaster")
  expect_named(m, c("gdd_average_b10", "gdd_single_sine_b10", "ch_sine",
                    "ch_hourly", "cu_utah", "cp_dynamic"))
  expect_false(is.null(attr(m, "provenance")))
})

test_that("print() lists indices, units and layers", {
  m <- plot_maps()
  out <- utils::capture.output(print(m))
  expect_match(out[1], "<thermify_rast> 6 indices, 3 x 3 cells, 9 valid")
  expect_true(any(grepl("cp_dynamic +\\[portions\\] +season", out)))
  expect_true(any(grepl("files in:", out)))
})

test_that("plot() draws one panel per index and layer", {
  skip_if_not_installed("terra")
  m <- plot_maps()
  expect_equal(draw(plot(m)), 6L)
  expect_equal(draw(plot(m, variable = "gdd")), 2L)
  expect_equal(draw(plot(m, variable = "cp_dynamic", type = "monthly")), 12L)
  expect_equal(draw(plot(m, variable = c("ch_hourly", "cu"),
                         type = c("m06", "m07"))), 4L)
  draw(expect_invisible(plot(m, variable = "cp")))
})

test_that("plot() really draws with terra", {
  m <- plot_maps(c("gdd", "cp"))
  f <- tempfile(fileext = ".png")
  grDevices::png(f)
  expect_silent(plot(m, type = "monthly", nrow = 6, ncol = 6,
                     boundary = terra::as.polygons(terra::ext(m[[1]]),
                                                   crs = "EPSG:4326")))
  plot(m, range = "panel", col = grDevices::terrain.colors)
  # The graphical parameters are restored.
  expect_identical(graphics::par("mfrow"), c(1L, 1L))
  grDevices::dev.off()
  expect_gt(file.size(f), 1000)
})

test_that("annual layers missing for Utah and Dynamic are reported", {
  m <- plot_maps()
  expect_message(n <- draw(plot(m, type = "annual")),
                 "No annual layer for: cu_utah, cp_dynamic")
  expect_equal(n, 4L)
  expect_error(suppressMessages(plot(m, variable = "cp", type = "annual")),
               "Nothing to plot")
})

test_that("layouts are derived from the number of panels", {
  expect_identical(panel_layout(6, NULL, NULL), c(2L, 3L))
  expect_identical(panel_layout(12, 3, NULL), c(3L, 4L))
  expect_identical(panel_layout(12, NULL, 6), c(2L, 6L))
  expect_identical(panel_layout(1, NULL, NULL), c(1L, 1L))
  expect_warning(panel_layout(12, 2, 2), "do not fit")
  expect_error(panel_layout(4, 0, NULL), "positive")
})

test_that("titles name the index, the period and the units", {
  cfg <- list(heat_period = c("09-01", "04-30"),
              chill_period = c("05-01", "08-31"))
  expect_identical(panel_title("gdd_single_sine_b10", "season", cfg),
                   "GDD single sine, base 10, 1 Sep - 30 Apr [degC day]")
  expect_identical(panel_title("cp_dynamic", "season", cfg),
                   "Chill portions (Dynamic), 1 May - 31 Aug [portions]")
  expect_identical(panel_title("ch_hourly", "m07", cfg),
                   "Chilling hours (hourly), Jul [h]")
  expect_identical(panel_title("gdd_average_b5", "annual"),
                   "GDD average, base 5, annual [degC day]")
})

test_that("invalid arguments give informative errors", {
  m <- plot_maps(c("gdd", "cp"))
  expect_error(plot(m, variable = "cu"), "\"cu\" is not in the object")
  expect_error(plot(m, type = "winter"), "Unknown `type` \"winter\"")
  expect_error(plot(m, variable = 1), "`variable` must be")
  expect_error(plot(m, boundary = "x"), "SpatVector")
  expect_error(plot(m, range = "all"), "should be one of")
})
