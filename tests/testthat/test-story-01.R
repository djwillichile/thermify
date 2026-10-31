# US-01 Heat accumulation to a phenological threshold (docs/USER_STORIES.md)

station_season <- function() {
  dates <- seq(as.Date("2022-09-01"), as.Date("2023-04-30"), by = "day")
  doy <- as.integer(format(dates, "%j"))
  tmax <- 22 + 8 * cos(2 * pi * (doy - 15) / 365)
  tmin <- tmax - 14
  data.frame(date = dates, tmin = tmin, tmax = tmax)
}

test_that("GDD accumulate over a season that crosses the year end", {
  d <- station_season()
  res <- thermify(d$tmin, d$tmax, input = "daily", dates = d$date,
                  indices = "gdd", gdd_methods = "single_sine", base = 10,
                  upper = 30)
  s <- res$summary
  total <- s$value[s$key == "gdd_single_sine_b10" &
                     grepl("^season", s$aggregation)]
  expect_equal(total, sum(degree_days(d$tmin, d$tmax, base = 10,
                                      upper = 30)))
  expect_equal(s$units[s$key == "gdd_single_sine_b10"][1], "degC day")
})

test_that("the date of a phenological threshold is reported", {
  d <- station_season()
  gdd <- degree_days(d$tmin, d$tmax, base = 10)
  when <- threshold_date(gdd, d$date, threshold = 500)
  i <- attr(when, "index")
  expect_s3_class(when, "Date")
  expect_gte(sum(gdd[seq_len(i)]), 500)
  expect_lt(sum(gdd[seq_len(i - 1)]), 500)
  expect_true(is.na(threshold_date(gdd, d$date, threshold = 1e6)))
})

test_that("missing days are explicit", {
  d <- station_season()
  gdd <- degree_days(d$tmin, d$tmax, base = 10)
  gdd[5] <- NA
  expect_true(is.na(threshold_date(gdd, d$date, threshold = 500)))
  skipped <- threshold_date(gdd, d$date, threshold = 500, na_action = "skip")
  expect_false(is.na(skipped))
  # A gap after the threshold does not matter.
  late <- degree_days(d$tmin, d$tmax, base = 10)
  late[length(late)] <- NA
  expect_false(is.na(threshold_date(late, d$date, threshold = 500)))
  expect_error(threshold_date(gdd, rev(d$date), 500), "increasing")
})
