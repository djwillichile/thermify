tmin_m <- c(11.4, 11.1, 9.2, 6.8, 5.3, 3.9, 3.1, 3.6, 4.6, 6.3, 8.4, 10.3)
tmax_m <- c(29.6, 29.2, 26.5, 21.9, 17.2, 13.9, 13.6, 15.3, 17.9, 21.2,
            24.9, 28.2)

test_that("monthly workflow returns consistent tables", {
  res <- thermify(tmin_m, tmax_m, input = "monthly", latitude = -35.97,
                  temporal = "native", ch_methods = c("sine", "hourly"))
  expect_s3_class(res, "thermify")
  expect_equal(nrow(res$daily), 365)
  expect_equal(nrow(res$hourly), 365 * 24)
  s <- res$summary
  gdd <- s$value[s$key == "gdd_single_sine_b10" & s$aggregation == "annual"]
  expect_equal(gdd, sum(res$daily$gdd_single_sine_b10))
  cp <- s$value[s$key == "cp_dynamic" & s$aggregation == "season"]
  expect_equal(cp, sum(res$daily$cp_dynamic, na.rm = TRUE))
  # Chill models are evaluated only inside the chill period.
  out <- !res$daily$month %in% 5:8
  expect_true(all(is.na(res$daily$cp_dynamic[out])))
  expect_output(print(res), "climatological cycle")
})

test_that("chill portions run continuously over the period", {
  res <- thermify(tmin_m, tmax_m, latitude = -35.97, temporal = "native",
                  indices = "cp")
  hr <- res$hourly
  sel <- hr$date >= as.Date("2023-05-01") & hr$date <= as.Date("2023-08-31")
  direct <- chill_portions(hr$temperature[sel], output = "total")
  cp <- res$summary$value[res$summary$aggregation == "season"]
  expect_equal(cp, as.vector(direct))
})

test_that("daily and hourly inputs are explicit", {
  dates <- seq(as.Date("2022-05-01"), by = "day", length.out = 20)
  tmin <- rep(3, 20); tmax <- rep(13, 20)
  res <- thermify(tmin, tmax, input = "daily", dates = dates,
                  latitude = -35.97, indices = c("gdd", "cu"))
  expect_equal(nrow(res$daily), 20)
  expect_error(thermify(tmin, tmax, input = "daily"), "dates")
  temp <- rep(c(rep(4, 12), rep(10, 12)), 20)
  hres <- thermify(temperature = temp, input = "hourly", dates = dates,
                   indices = c("ch", "cu"), ch_methods = "hourly")
  ch <- hres$summary$value[hres$summary$key == "ch_hourly" &
                             grepl("^season", hres$summary$aggregation)]
  expect_equal(ch, 12 * 20)
  expect_error(thermify(temperature = temp[-1], input = "hourly",
                        dates = dates), "24 values")
  expect_error(thermify(tmin_m, tmax_m, temporal = "native"), "latitude")
})
