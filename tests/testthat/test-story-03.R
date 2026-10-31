# US-03 Chill models when only daily extremes exist (docs/USER_STORIES.md)

daily_station <- function() {
  set.seed(3)
  dates <- seq(as.Date("2023-05-01"), as.Date("2023-08-31"), by = "day")
  tmin <- 3 + stats::rnorm(length(dates), 0, 2)
  tmax <- tmin + 9 + stats::runif(length(dates), 0, 6)
  data.frame(date = dates, tmin = tmin, tmax = tmax)
}

test_that("reconstructed hours are flagged with their method", {
  d <- daily_station()
  res <- thermify(d$tmin, d$tmax, input = "daily", dates = d$date,
                  latitude = -35.97, indices = c("cu", "cp"))
  expect_true(all(res$hourly$reconstructed))
  expect_identical(res$provenance$hourly, "linvill")
  sine <- thermify(d$tmin, d$tmax, input = "daily", dates = d$date,
                   indices = "cu", hourly_method = "sine")
  expect_identical(sine$provenance$hourly, "sine")
})

test_that("Linvill needs a latitude, sine does not", {
  d <- daily_station()
  expect_error(thermify(d$tmin, d$tmax, input = "daily", dates = d$date,
                        indices = "cp"), "latitude")
  expect_no_error(thermify(d$tmin, d$tmax, input = "daily", dates = d$date,
                           indices = "cp", hourly_method = "sine"))
})

test_that("reconstructed hours stay within neighbouring extremes", {
  d <- daily_station()
  doy <- as.integer(format(d$date, "%j"))
  for (m in c("linvill", "sine")) {
    h <- matrix(hourly_temperatures(d$tmin, d$tmax, m, latitude = -35.97,
                                    doy = doy), nrow = 24)
    n <- nrow(d)
    lo <- pmin(d$tmin, c(d$tmin[1], d$tmin[-n]), c(d$tmin[-1], d$tmin[n]))
    hi <- pmax(d$tmax, c(d$tmax[1], d$tmax[-n]))
    expect_true(all(sweep(h, 2, lo) >= -1e-9), info = m)
    expect_true(all(sweep(h, 2, hi) <= 1e-9), info = m)
  }
})

test_that("analytical and hourly chilling hours are reported side by side", {
  d <- daily_station()
  res <- thermify(d$tmin, d$tmax, input = "daily", dates = d$date,
                  latitude = -35.97, indices = "ch",
                  ch_methods = c("sine", "hourly"))
  expect_true(all(c("ch_sine", "ch_hourly") %in% names(res$daily)))
  expect_true(all(res$daily$ch_sine >= 0 & res$daily$ch_sine <= 24))
  expect_true(all(res$daily$ch_hourly %in% 0:24))
})
