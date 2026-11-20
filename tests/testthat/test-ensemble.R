# All data in these tests are synthetic and only check the computations.

make_cases <- function(observed_fun, n_station = 3, n_season = 4,
                       methods = c("average", "single_sine",
                                   "single_triangle")) {
  set.seed(42)
  grid <- expand.grid(season = seq_len(n_season),
                      station = LETTERS[seq_len(n_station)])
  base <- 1000 + 200 * stats::runif(nrow(grid))
  noise <- function() stats::rnorm(nrow(grid), 0, 15)
  est <- cbind(average = 0.96 * base + noise(),
               single_sine = 1.03 * base + noise(),
               single_triangle = base + noise())[, methods, drop = FALSE]
  obs <- observed_fun(est)
  do.call(rbind, lapply(methods, function(m) {
    data.frame(station = grid$station, season = grid$season, method = m,
               estimate = est[, m], observed = obs)
  }))
}

test_that("stacking recovers an exact convex combination", {
  cases <- make_cases(function(e) 0.4 * e[, "average"] +
                        0.6 * e[, "single_sine"])
  w <- gdd_ensemble_weights(cases)
  expect_s3_class(w, "gdd_ensemble_weights")
  expect_equal(sum(w$weights), 1)
  expect_true(all(w$weights >= 0))
  expect_equal(unname(w$weights[c("average", "single_sine")]), c(0.4, 0.6),
               tolerance = 1e-6)
  expect_lt(w$fit$rmse[w$fit$method == "ensemble"], 1e-3)
  expect_equal(w$n_cases, 12)
  expect_equal(w$group_by, "station")
  expect_false(is.null(w$cv))
})

test_that("a method that matches the observations gets all the weight", {
  cases <- make_cases(function(e) e[, "single_triangle"])
  for (sc in c("stacking", "bma", "akaike")) {
    w <- gdd_ensemble_weights(cases, scheme = sc)
    expect_equal(unname(w$weights["single_triangle"]), 1, tolerance = 1e-6,
                 info = sc)
  }
})

test_that("Akaike weights follow the relative likelihood", {
  cases <- make_cases(function(e) e[, "single_triangle"] +
                        stats::rnorm(nrow(e), 0, 8))
  w <- gdd_ensemble_weights(cases, scheme = "akaike")
  aic <- w$aic
  expect_equal(sort(aic$method), sort(names(w$weights)))
  expect_equal(min(aic$delta), 0)
  expect_equal(aic$weight, unname(exp(-aic$delta / 2) /
                                    sum(exp(-aic$delta / 2))))
  expect_equal(unname(w$weights[aic$method]), aic$weight)
  n <- w$n_cases
  expect_equal(diff(aic$aic[1:2]), n * log(
    mean((cases$estimate[cases$method == aic$method[2]] -
            cases$observed[cases$method == aic$method[2]])^2) /
      mean((cases$estimate[cases$method == aic$method[1]] -
              cases$observed[cases$method == aic$method[1]])^2)))
})

test_that("BMA returns weights and an error standard deviation", {
  cases <- make_cases(function(e) e[, "single_triangle"] +
                        stats::rnorm(nrow(e), 0, 5))
  w <- gdd_ensemble_weights(cases, scheme = "bma")
  expect_equal(sum(w$weights), 1)
  expect_true(w$sigma > 0)
  expect_identical(names(which.max(w$weights)), "single_triangle")
})

test_that("degree_days ensemble is the weighted mean of its members", {
  tmin <- c(2, 6, 9, 14); tmax <- c(15, 22, 28, 33)
  w <- c(average = 1, single_triangle = 3)
  members <- cbind(degree_days(tmin, tmax, method = "average", base = 10),
                   degree_days(tmin, tmax, method = "single_triangle",
                               base = 10))
  expected <- as.vector(members %*% c(0.25, 0.75))
  expect_equal(degree_days(tmin, tmax, method = "ensemble", weights = w,
                           base = 10), expected)
  g <- gdd_ensemble(tmin, tmax, weights = w, base = 10)
  expect_equal(g$ensemble, expected)
  expect_equal(g$min, pmin(members[, 1], members[, 2]))
  expect_equal(g$max, pmax(members[, 1], members[, 2]))
  expect_equal(g$sd, sqrt(0.25 * (members[, 1] - expected)^2 +
                            0.75 * (members[, 2] - expected)^2))
  expect_named(g, c("ensemble", "sd", "min", "max", "average",
                    "single_triangle"))
})

test_that("ensemble weights must be explicit and valid", {
  expect_error(degree_days(5, 25, method = "ensemble"), "no default weights")
  expect_error(degree_days(5, 25, method = "ensemble",
                           weights = c(average = -1, single_sine = 2)),
               "non-negative")
  expect_error(degree_days(5, 25, method = "ensemble",
                           weights = c(average = 1, hourly = 1)),
               "Unknown ensemble member")
  expect_error(degree_days(5, 25, method = "ensemble", weights = c(1, 2)),
               "named numeric")
  expect_error(gdd_ensemble_weights(make_cases(function(e) e[, 1]),
                                    methods = "average"),
               "at least two")
  expect_error(gdd_ensemble_weights(make_cases(function(e) e[, 1]),
                                    methods = c("average", "ensemble")),
               "not found|itself")
  dup <- make_cases(function(e) e[, 1])
  dup$season <- NULL
  expect_error(gdd_ensemble_weights(dup), "add a `season`")
})

test_that("weights from validation results enforce the same thresholds", {
  # Synthetic hourly record: two years with a seasonal and a daily cycle.
  times <- seq(as.POSIXct("2019-01-01 00:00", tz = "UTC"),
               as.POSIXct("2020-12-31 23:00", tz = "UTC"), by = "hour")
  doy <- as.integer(format(times, "%j"))
  hour <- as.integer(format(times, "%H"))
  set.seed(1)
  temp <- 14 + 6 * cos(2 * pi * (doy - 15) / 365) +
    7 * sin(2 * pi * (hour - 9) / 24) + stats::rnorm(length(times), 0, 0.5)
  st <- prepare_station_hourly(times, temp)
  v <- validate_station(st, latitude = -36, indices = "gdd", base = 10,
                        gdd_methods = c("average", "single_sine",
                                        "single_triangle"))
  w <- gdd_ensemble_weights(list(a = v, b = v), cv = FALSE)
  expect_equal(w$base, 10)
  expect_null(w$upper)
  expect_equal(w$group_by, "station")
  expect_output(print(w), "GDD ensemble weights")
  expect_silent(degree_days(5, 25, method = "ensemble", weights = w,
                            base = 10))
  expect_error(degree_days(5, 25, method = "ensemble", weights = w, base = 5),
               "base 10")
  expect_error(degree_days(5, 25, method = "ensemble", weights = w,
                           base = 10, upper = 30), "upper")
  expect_error(gdd_ensemble_weights(v, level = "nonexistent"),
               "No GDD cases")
  # Hourly-reconstruction estimates are reported but are not members.
  expect_true("hourly_linvill" %in% v$seasons$method)
  expect_false(any(startsWith(names(w$weights), "hourly_")))
  expect_error(gdd_ensemble_weights(v, methods = c("average",
                                                   "hourly_linvill")),
               "daily degree_days")
})

test_that("thermify() and thermify_rast() accept the ensemble", {
  w <- c(average = 0.5, single_triangle = 0.5)
  tmin <- c(12, 12, 10, 8, 6, 4, 3, 4, 5, 7, 9, 11)
  tmax <- c(30, 29, 27, 23, 18, 15, 14, 16, 19, 23, 26, 29)
  r <- thermify(tmin, tmax, input = "monthly", latitude = -36,
                temporal = "native", indices = "gdd",
                gdd_methods = c("average", "single_triangle", "ensemble"),
                base = 10, gdd_weights = w)
  s <- r$summary[r$summary$aggregation == "season", ]
  v <- stats::setNames(s$value, s$key)
  expect_equal(unname(v["gdd_ensemble_b10"]),
               unname(0.5 * v["gdd_average_b10"] +
                        0.5 * v["gdd_single_triangle_b10"]))
  expect_error(thermify(tmin, tmax, input = "monthly", latitude = -36,
                        temporal = "native", indices = "gdd",
                        gdd_methods = "ensemble", base = 10),
               "no default weights")

  r_min <- terra::rast(nrows = 2, ncols = 2, nlyrs = 12,
                       xmin = -72.4, xmax = -72.3, ymin = -36, ymax = -35.9,
                       crs = "EPSG:4326", vals = rep(tmin, each = 4))
  r_max <- terra::rast(r_min, vals = rep(tmax, each = 4))
  out <- thermify_rast(r_min, r_max, output_dir = tempfile(),
                       temporal = "native", indices = "gdd",
                       gdd_methods = "ensemble", base = 10, gdd_weights = w,
                       progress = FALSE)
  expect_true("gdd_ensemble_b10" %in% names(out))
  expect_equal(unique(terra::values(out$gdd_ensemble_b10$season,
                                    mat = FALSE)),
               unname(v["gdd_ensemble_b10"]), tolerance = 1e-6)
})
