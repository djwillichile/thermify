# End-to-end checks of the whole workflow: monthly rasters -> daily ->
# hourly -> indices -> temporal aggregation -> files on disk -> read back.
# These complement the unit tests by checking that the stages fit together.

tmin_m <- c(11.8, 11.1, 9.6, 7.9, 6.6, 5.5, 4.8, 4.9, 5.9, 7.5, 9.2, 11.1)
tmax_m <- c(27.4, 26.5, 23.5, 19.3, 15.5, 12.9, 12.6, 13.9, 16.1, 18.8, 21.9,
            25.2)

monthly_stack <- function() {
  set.seed(11)
  r <- terra::rast(nrows = 5, ncols = 4, nlyrs = 12, xmin = -72.45,
                   xmax = -72.2, ymin = -36.06, ymax = -35.87,
                   crs = "EPSG:4326")
  off <- stats::rnorm(20, 0, 1)
  tmin <- terra::setValues(r, outer(off, tmin_m, "+"))
  tmax <- terra::setValues(r, outer(off * 0.7, tmax_m, "+"))
  tmin[7] <- NA
  tmax[7] <- NA
  list(tmin = tmin, tmax = tmax)
}

test_that("written layers are mutually consistent", {
  skip_if_not_installed("terra")
  s <- monthly_stack()
  out <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                       temporal = "native", latitude = -35.97,
                       gdd_methods = c("average", "double_sine"),
                       ch_methods = c("sine", "hourly"))
  months <- sprintf("m%02d", 1:12)
  for (k in names(out)) {
    v <- terra::values(out[[k]])
    ok <- !is.na(v[, "season"])
    monthly_sum <- rowSums(v[ok, months], na.rm = TRUE)
    if (startsWith(k, "gdd_") || startsWith(k, "ch_")) {
      # All months add up to the calendar year.
      expect_equal(monthly_sum, v[ok, "annual"], tolerance = 1e-5, info = k)
    }
    if (k %in% c("cu_utah", "cp_dynamic", "ch_sine", "ch_hourly")) {
      # Chill period 1 May - 31 Aug: May to August add up to the season.
      expect_equal(rowSums(v[ok, sprintf("m%02d", 5:8)]), v[ok, "season"],
                   tolerance = 1e-5, info = k)
    }
    if (k %in% c("cu_utah", "cp_dynamic")) {
      expect_true(all(is.na(v[, sprintf("m%02d", c(1:4, 9:12))])), info = k)
    }
  }
  # Heat period 1 Sep - 30 Apr: September to April add up to the season.
  g <- terra::values(out$gdd_average_b10)
  ok <- !is.na(g[, "season"])
  expect_equal(rowSums(g[ok, sprintf("m%02d", c(9:12, 1:4))]),
               g[ok, "season"], tolerance = 1e-4)
})

test_that("NetCDF output holds the same values as GeoTIFF", {
  skip_if_not_installed("terra")
  skip_if_not_installed("ncdf4")
  s <- monthly_stack()
  dir <- tempfile()
  out <- thermify_rast(s$tmin, s$tmax, output_dir = dir, temporal = "native",
                       indices = c("gdd", "cp"), gdd_methods = "single_sine",
                       base = 10, latitude = -35.97,
                       format = c("GTiff", "netCDF"))
  for (k in names(out)) {
    nc <- terra::rast(file.path(dir, paste0(k, ".nc")))
    expect_equal(terra::nlyr(nc), terra::nlyr(out[[k]]))
    expect_equal(unname(terra::values(nc)), unname(terra::values(out[[k]])),
                 tolerance = 1e-5, info = k)
  }
})

test_that("a fixed latitude and per-cell latitudes are both supported", {
  skip_if_not_installed("terra")
  s <- monthly_stack()
  fixed <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                         temporal = "native", indices = "cp",
                         latitude = -35.97)
  per_cell <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                            temporal = "native", indices = "cp")
  a <- terra::values(fixed$cp_dynamic$season)
  b <- terra::values(per_cell$cp_dynamic$season)
  # Same order of magnitude, but day length differs slightly by latitude.
  expect_equal(a, b, tolerance = 0.05)
  expect_false(isTRUE(all.equal(a, b, tolerance = 1e-10)))
})

test_that("blocks without valid cells are written as NA", {
  skip_if_not_installed("terra")
  s <- monthly_stack()
  s$tmin[1:4] <- NA   # first row entirely missing
  s$tmax[1:4] <- NA
  out <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                       temporal = "native", indices = "gdd",
                       gdd_methods = "average", base = 10, max_cells = 4,
                       keep_daily = TRUE)
  v <- terra::values(out$gdd_average_b10$season, mat = FALSE)
  expect_true(all(is.na(v[1:4])))
  expect_false(anyNA(v[-c(1:4, 7)]))
})

test_that("raster runs with the tempify engine equal the native engine", {
  skip_if_not_installed("terra")
  skip_if_not(tempify_available(), "tempify not available")
  s <- monthly_stack()
  a <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                     temporal = "tempify", latitude = -35.97)
  b <- thermify_rast(s$tmin, s$tmax, output_dir = tempfile(),
                     temporal = "native", latitude = -35.97)
  for (k in names(a)) {
    expect_equal(terra::values(a[[k]]), terra::values(b[[k]]),
                 tolerance = 1e-6, info = k)
  }
  expect_identical(attr(a, "provenance")$engine, "tempify")
  expect_false(is.null(attr(a, "provenance")$tempify))
})

test_that("observed multi-season series restart the Dynamic model per season", {
  dates <- seq(as.Date("2021-01-01"), as.Date("2022-12-31"), by = "day")
  doy <- as.integer(format(dates, "%j"))
  tmin <- 6 + 4 * cos(2 * pi * (doy - 15) / 365)
  tmax <- tmin + 12
  res <- thermify(tmin, tmax, input = "daily", dates = dates,
                  latitude = -35.97, indices = c("gdd", "cp"),
                  gdd_methods = "average", base = 10)
  s <- res$summary
  cp <- s[s$key == "cp_dynamic" & startsWith(s$aggregation, "season"), ]
  expect_setequal(cp$aggregation, c("season_2021", "season_2022"))
  # Identical weather in both winters: identical totals, so no carry-over.
  expect_equal(cp$value[1], cp$value[2], tolerance = 1e-8)
  # The heat season crossing the year end is labelled by its start year.
  gdd <- s[s$key == "gdd_average_b10" & startsWith(s$aggregation, "season"), ]
  expect_true(all(c("season_2020", "season_2021", "season_2022") %in%
                    gdd$aggregation))
})

test_that("hourly degree-days equal summed degree-hours divided by 24", {
  dates <- seq(as.Date("2023-01-01"), by = "day", length.out = 10)
  temp <- rep(12 + 9 * sin(2 * pi * (0:23 - 9) / 24), 10)
  res <- thermify(temperature = temp, input = "hourly", dates = dates,
                  indices = "gdd", gdd_methods = "hourly", base = 10,
                  heat_period = c("01-01", "12-31"))
  expect_equal(res$daily$gdd_hourly_b10,
               degree_hours(temp, base = 10, by_day = TRUE))
})

test_that("joint mean/range densification propagates through thermify()", {
  res <- thermify(tmin_m, tmax_m, temporal = "native", indices = "gdd",
                  consistency = "mean_range")
  expect_identical(res$provenance$densification$consistency, "mean_range")
  month <- res$daily$month
  expect_equal(as.vector(tapply(res$daily$tmin, month, mean)), tmin_m,
               tolerance = 1e-8)
})

test_that("the study window is a square of the requested size", {
  skip_if_not_installed("terra")
  win <- study_window(-72.3225, -35.9671, size_km = 20)
  expect_identical(attr(win, "utm"), "EPSG:32718")
  poly <- terra::as.polygons(win, crs = "EPSG:4326")
  utm <- terra::ext(terra::project(poly, "EPSG:32718"))
  # The lon/lat envelope of the UTM square contains it, so it is at least
  # 20 km; meridian convergence makes it slightly wider (here ~21 km).
  expect_gte(terra::xmax(utm) - terra::xmin(utm), 20000 - 1)
  expect_lt(terra::xmax(utm) - terra::xmin(utm), 21500)
  expect_gte(terra::ymax(utm) - terra::ymin(utm), 20000 - 1)
  north <- study_window(-70, 10, 5)
  expect_identical(attr(north, "utm"), "EPSG:32619")
})

test_that("results agree with chillR and degday reference implementations", {
  src <- c(Sys.getenv("CHILLR_SRC"), Sys.getenv("DEGDAY_SRC"))
  skip_if(any(!nzchar(src)) || !all(dir.exists(src)),
          "set CHILLR_SRC and DEGDAY_SRC to source checkouts")
  script <- system.file("verification", "verify_references.R",
                        package = "thermify")
  if (!nzchar(script)) {
    script <- testthat::test_path("..", "..", "inst", "verification",
                                  "verify_references.R")
  }
  env <- new.env()
  withr::with_envvar(c(CHILLR_SRC = src[1], DEGDAY_SRC = src[2]), {
    utils::capture.output(suppressMessages(
      sys.source(script, envir = env)))
  })
  res <- env$res
  documented <- grepl("pre-dawn, night = 'continuous'", res$check)
  expect_true(all(res$max_abs_diff[!documented] < 1e-10))
  expect_gt(nrow(res), 10)
})

test_that("the Cauquenes script runs end to end (synthetic smoke test)", {
  skip_on_cran()
  skip_if_not(identical(Sys.getenv("THERMIFY_SLOW_TESTS"), "true"),
              "set THERMIFY_SLOW_TESTS=true to run the case-study script")
  root <- testthat::test_path("..", "..")
  skip_if_not(file.exists(file.path(root, "examples", "cauquenes", "run.R")))
  out <- tempfile()
  status <- withr::with_dir(root, system2(
    file.path(R.home("bin"), "Rscript"),
    "examples/cauquenes/run.R", stdout = FALSE, stderr = FALSE,
    env = c("THERMIFY_DEV=1", "THERMIFY_SMOKE_TEST=1", "THERMIFY_SKIP_BENCH=1",
            "THERMIFY_ENGINE=native", paste0("THERMIFY_SMOKE_DIR=", out))))
  expect_equal(status, 0L)
  val <- utils::read.csv(file.path(out, "output", "tables",
                                   "input_validation.csv"))
  expect_true(all(val$ok))
  expect_true(all(val$product == "SYNTHETIC TEST FIELD"))
  expect_true(file.exists(file.path(out, "output", "reports",
                                    "report.html")))
  expect_length(list.files(file.path(out, "output", "figures"), "png$"), 8)
})
