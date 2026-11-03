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
    },
    draw_overall_title = function(...) invisible(NULL))
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
  expect_equal(draw(plot(m, variable = "gdd_average_b10",
                         type = "monthly")), 12L)
  expect_equal(draw(plot(m, variable = c("ch_hourly", "cu"),
                         type = c("m06", "m07"))), 4L)
  draw(expect_invisible(plot(m, variable = "cp")))
})

test_that("plot() really draws with terra", {
  m <- plot_maps(c("gdd", "cp"))
  f <- tempfile(fileext = ".png")
  grDevices::png(f, width = 1400, height = 1400)
  # The months of the Dynamic model outside the chill period are left out.
  expect_message(plot(m, type = "monthly", nrow = 4, ncol = 7,
                      boundary = terra::as.polygons(terra::ext(m[[1]]),
                                                    crs = "EPSG:4326")),
                 "No data outside the accumulation period")
  plot(m, range = "panel", col = grDevices::terrain.colors)
  # Tiny panels do not fail.
  grDevices::png(tempfile(fileext = ".png"))
  expect_no_error(suppressMessages(plot(m, type = "monthly", nrow = 6,
                                        ncol = 6)))
  grDevices::dev.off()
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

test_that("long titles are wrapped to the panel width", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 7, height = 7)
  on.exit(grDevices::dev.off())
  title <- "GDD single sine, base 10, 1 Sep - 30 Apr [degC day]"
  # Wide enough: unchanged.
  expect_identical(wrap_title(title, 10), title)
  # Narrow: broken at the commas first, every line fits.
  w <- graphics::strwidth("GDD single sine, base 10,", units = "inches",
                          cex = 1.2, font = 2) + 0.05
  wrapped <- wrap_title(title, w)
  lines <- strsplit(wrapped, "\n")[[1]]
  expect_identical(lines[1], "GDD single sine, base 10,")
  expect_true(all(graphics::strwidth(lines, units = "inches", cex = 1.2,
                                     font = 2) <= w))
  expect_identical(gsub("\n", " ", wrapped), title)
  # Very narrow: long parts are also split at spaces.
  tiny <- strsplit(wrap_title(title, 0.8), "\n")[[1]]
  expect_gt(length(tiny), 3)
  expect_identical(paste(tiny, collapse = " "), title)
})

test_that("wrapped titles enlarge the top margin; user titles are kept", {
  m <- plot_maps()
  seen <- list()
  local_mocked_bindings(draw_panel = function(..., main, mar = NULL) {
    seen[[length(seen) + 1L]] <<- list(main = main, mar = mar)
    invisible(NULL)
  })
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 4, height = 4)
  on.exit(grDevices::dev.off())
  plot(m, variable = "gdd_single_sine_b10")
  expect_match(seen[[1]]$main, "\n")
  n <- length(strsplit(seen[[1]]$main, "\n")[[1]])
  expect_equal(seen[[1]]$mar[3], 2 + 1.1 * (n - 1))
  seen <- list()
  plot(m, variable = "gdd", main = c("A", "B"))
  expect_identical(vapply(seen, `[[`, "", "main"), c("A", "B"))
  expect_null(seen[[1]]$mar)
})

test_that("one index month by month gets short titles and an overall title", {
  m <- plot_maps()
  seen <- character()
  local_mocked_bindings(draw_panel = function(..., main) {
    seen <<- c(seen, main)
    invisible(NULL)
  })
  outer <- NULL
  local_mocked_bindings(draw_overall_title = function(text) outer <<- text)
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 12, height = 9)
  on.exit(grDevices::dev.off())
  plot(m, variable = "gdd_single_sine_b10", type = "monthly")
  expect_identical(seen, paste(month.abb, "[degC day]"))
  expect_identical(outer, "GDD single sine, base 10")
  # Several indices keep the index name in every panel.
  seen <- character()
  outer <- NULL
  plot(m, variable = c("ch_hourly", "cp_dynamic"), type = "m07")
  expect_identical(gsub("\n", " ", seen),
                   c("Chilling hours (hourly), Jul [h]",
                     "Chill portions (Dynamic), Jul [portions]"))
  expect_null(outer)
  # titles = "full" keeps the index and method in every monthly panel.
  seen <- character()
  plot(m, variable = "gdd_average_b10", type = c("m01", "m02"),
       titles = "full")
  expect_identical(gsub("\n", " ", seen),
                   paste0("GDD average, base 10, ", c("Jan", "Feb"),
                          " [degC day]"))
  expect_null(outer)
  # titles = "short" also for seasons, with the index name above.
  seen <- character()
  plot(m, variable = "cp_dynamic", type = c("season", "m07"),
       titles = "short")
  expect_identical(seen, c("1 May - 31 Aug [portions]", "Jul [portions]"))
  expect_identical(outer, "Chill portions (Dynamic)")
  expect_error(plot(m, titles = "none"), "should be one of")
})

test_that("monthly layers without data are left out", {
  m <- plot_maps()
  expect_message(n <- draw(plot(m, variable = "cu_utah", type = "monthly")),
                 "cu_utah \\(Jan, Feb, Mar, Apr, Sep, Oct, Nov, Dec\\)")
  expect_equal(n, 4L)
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
