# US-02 Chill requirement from hourly station records (docs/USER_STORIES.md)

hourly_station <- function() {
  dates <- seq(as.Date("2023-04-15"), as.Date("2023-09-15"), by = "day")
  doy <- as.integer(format(dates, "%j"))
  tmin <- 4 + 3 * cos(2 * pi * (doy - 15) / 365)
  tmax <- tmin + 10
  temp <- hourly_temperatures(tmin, tmax, "sine")
  list(dates = dates, temperature = temp)
}

test_that("hourly records are used as observed", {
  st <- hourly_station()
  res <- thermify(temperature = st$temperature, input = "hourly",
                  dates = st$dates, indices = c("ch", "cp"),
                  ch_methods = "hourly")
  expect_identical(res$provenance$hourly, "observed")
  expect_false(any(res$hourly$reconstructed))
  expect_equal(res$hourly$temperature, st$temperature)
})

test_that("chill accumulates only inside the period, without resets", {
  st <- hourly_station()
  res <- thermify(temperature = st$temperature, input = "hourly",
                  dates = st$dates, indices = c("ch", "cp"),
                  ch_methods = "hourly")
  d <- res$daily
  inside <- d$date >= as.Date("2023-05-01") & d$date <= as.Date("2023-08-31")
  expect_true(all(is.na(d$cp_dynamic[!inside])))
  hours <- rep(inside, each = 24)
  direct <- chill_portions(st$temperature[hours], output = "total")
  cp <- res$summary$value[res$summary$key == "cp_dynamic" &
                            grepl("^season", res$summary$aggregation)]
  expect_equal(cp, as.vector(direct))
})

test_that("the date a cultivar requirement is met is available", {
  st <- hourly_station()
  res <- thermify(temperature = st$temperature, input = "hourly",
                  dates = st$dates, indices = "cp")
  d <- res$daily[!is.na(res$daily$cp_dynamic), ]
  when <- threshold_date(d$cp_dynamic, d$date, threshold = 50)
  expect_true(when > as.Date("2023-05-01") && when < as.Date("2023-08-31"))
})

test_that("records split in blocks give the same chill", {
  st <- hourly_station()
  n <- length(st$temperature)
  first <- chill_portions(st$temperature[1:2000])
  second <- chill_portions(st$temperature[2001:n],
                           state = attr(first, "state"))
  expect_equal(as.vector(tail(second, 1)),
               as.vector(chill_portions(st$temperature, output = "total")))
})
