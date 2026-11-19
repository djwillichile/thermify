# Synthetic experiment: how much error does each growing degree-day method
# add when hourly temperature is not available?
#
# THE TEMPERATURE SERIES ARE SYNTHETIC. They are generated from real monthly
# normals (WorldClim 2.1, 30 arc-seconds, 1970-2000) at four sites in the
# Maule Region, Chile, but the daily and hourly values are simulated. The
# experiment quantifies method error under controlled, known conditions; it
# does not replace validation against observed station data (issue #3,
# vignette("validation")).
#
# Design
#   1. Daily extremes: WorldClim monthly normals densified with pchip_mp
#      plus day-to-day anomalies (bivariate AR(1), lag-1 0.7, correlated
#      tmin/tmax shocks) and a yearly anomaly shared by tmin and tmax.
#   2. Hourly temperature ("truth"): Parton & Logan (1981) diurnal model
#      (sine by day with the maximum lagging solar noon, exponential decay
#      at night towards the next minimum) plus AR(1) hourly noise. This is
#      deliberately NOT the sine, triangle or Linvill shape used by the
#      methods under test, so no method matches the generator by
#      construction.
#   3. Reference GDD: degree-hours / 24 from the hourly series.
#   4. Estimates at three levels, as in vignette("validation"):
#        daily     : daily min/max of the hourly series + each daily method,
#                    and hourly reconstruction (Linvill) + degree-hours;
#        monthly   : each year's monthly means of the daily extremes,
#                    densified with pchip_mp, + each daily method;
#        climatology: the 30-year mean monthly extremes densified once,
#                    compared with every year (adds interannual variability).
#   5. Metrics per site, level, method, base and upper threshold for the
#      heat season (1 September - 30 April) and by calendar month.
#
# Run from the package root:  Rscript data-raw/gdd-synthetic/run.R
# Output: vignettes/articles/data/gdd-synthetic-*.csv

library(thermify)
set.seed(20261119)

out_dir <- "vignettes/articles/data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Monthly normals (degrees C), WorldClim 2.1 30" cell at each site,
# extracted with worldclim_region() on 2026-11-19.
sites <- list(
  coast = list(lat = -35.73, lon = -72.53, elev = 69,
    tmin = c(10.5, 10.0, 9.2, 8.1, 7.0, 6.4, 5.9, 5.9, 6.3, 7.4, 8.6, 10.1),
    tmax = c(24.6, 24.1, 22.0, 18.8, 15.5, 13.9, 13.7, 14.7, 16.1, 17.9,
             20.3, 22.8)),
  dryland = list(lat = -35.97, lon = -72.32, elev = 157,
    tmin = c(12.1, 11.3, 9.8, 8.0, 6.7, 5.6, 4.9, 5.1, 6.0, 7.7, 9.4, 11.3),
    tmax = c(27.9, 27.1, 23.9, 19.7, 15.8, 13.2, 12.9, 14.2, 16.5, 19.2,
             22.4, 25.7)),
  valley = list(lat = -35.43, lon = -71.67, elev = 98,
    tmin = c(12.7, 11.7, 9.8, 7.4, 6.1, 4.9, 4.0, 4.1, 5.7, 7.9, 9.8, 12.0),
    tmax = c(29.1, 28.1, 24.8, 20.1, 15.8, 13.0, 12.5, 14.0, 16.9, 20.1,
             23.5, 27.0)),
  foothills = list(lat = -35.70, lon = -71.30, elev = 480,
    tmin = c(11.4, 10.5, 8.4, 5.9, 4.5, 2.9, 2.2, 2.3, 3.8, 6.2, 8.1, 10.5),
    tmax = c(27.3, 26.4, 23.3, 18.6, 14.4, 11.1, 10.8, 12.3, 14.9, 18.1,
             21.5, 25.1))
)

# Generator parameters -------------------------------------------------------
n_years   <- 30       # evaluated years (plus one extra for the last season)
phi_day   <- 0.7      # lag-1 autocorrelation of daily anomalies
sd_tmax   <- 2.8      # stationary sd of daily tmax anomalies (degrees C)
sd_tmin   <- 2.0      # stationary sd of daily tmin anomalies
rho       <- 0.5      # correlation of tmin and tmax shocks
sd_year   <- 0.6      # sd of the yearly anomaly
min_range <- 2        # minimum diurnal range (degrees C)
pl_a <- 1.86; pl_b <- 2.20; pl_c <- -0.17   # Parton & Logan (1981), 1.5 m
phi_hour  <- 0.8      # lag-1 autocorrelation of hourly noise
sd_hour   <- 0.4      # stationary sd of hourly noise

bases   <- c(5, 10)
uppers  <- list(none = NULL, u30 = 30)
daily_methods <- c("average", "modified_average", "single_sine",
                   "single_triangle", "double_sine", "double_triangle")
months_in_year <- as.integer(format(seq(as.Date("2023-01-01"),
                                        by = "day", length.out = 365), "%m"))

ar1 <- function(n, phi, sd, shocks = stats::rnorm(n)) {
  e <- shocks * sd * sqrt(1 - phi^2)
  x <- numeric(n)
  x[1] <- shocks[1] * sd
  for (i in 2:n) x[i] <- phi * x[i - 1] + e[i]
  x
}

simulate_site <- function(s) {
  n_y <- n_years + 1
  n <- 365 * n_y
  clim <- densify_monthly(s$tmin, s$tmax, engine = "native")
  z1 <- stats::rnorm(n)
  z2 <- rho * z1 + sqrt(1 - rho^2) * stats::rnorm(n)
  yearly <- rep(stats::rnorm(n_y, 0, sd_year), each = 365)
  tmax <- rep(clim$tmax, n_y) + ar1(n, phi_day, sd_tmax, z1) + yearly
  tmin <- rep(clim$tmin, n_y) + ar1(n, phi_day, sd_tmin, z2) + yearly
  tmin <- pmin(tmin, tmax - min_range)

  # Parton & Logan hourly profile, sampled at mid-hour (h + 0.5).
  doy <- rep(1:365, n_y)
  sun <- daylength(s$lat, doy)
  dl <- sun$daylength; sr <- 12 - dl / 2; ss <- 12 + dl / 2
  day_temp <- function(t, d) {
    tmin[d] + (tmax[d] - tmin[d]) *
      sin(pi * (t - sr[d] - pl_c) / (dl[d] + 2 * pl_a))
  }
  night_temp <- function(n_after, d, target) {
    z <- 24 - dl[d]
    t_ss <- day_temp(ss[d], d)
    (target - t_ss * exp(-pl_b) + (t_ss - target) * exp(-pl_b * n_after / z)) /
      (1 - exp(-pl_b))
  }
  hours <- matrix(NA_real_, n, 24)
  for (h in 0:23) {
    t <- h + 0.5
    d <- seq_len(n)
    val <- numeric(n)
    is_day <- t >= sr & t <= ss
    val[is_day] <- day_temp(t, d[is_day])
    after <- t > ss
    nxt <- c(tmin[-1], tmin[n])
    val[after] <- night_temp(t - ss[after], d[after], nxt[after])
    before <- t < sr
    prev <- c(1L, d[-n])
    val[before] <- night_temp(t + 24 - ss[prev[before]], prev[before],
                              tmin[before])
    hours[, h + 1] <- val
  }
  hourly <- as.vector(t(hours)) + ar1(n * 24, phi_hour, sd_hour)
  hourly_m <- matrix(hourly, ncol = 24, byrow = TRUE)
  list(hourly = hourly,
       tmin_obs = apply(hourly_m, 1, min), tmax_obs = apply(hourly_m, 1, max),
       year = rep(seq_len(n_y), each = 365), month = rep(months_in_year, n_y),
       doy = doy)
}

# Monthly totals per year from a daily vector.
monthly_totals <- function(daily, year, month) {
  stats::aggregate(list(value = daily), list(year = year, month = month), sum)
}

# Heat season (Sep of year y to Apr of year y + 1) from monthly totals.
season_totals <- function(mt) {
  mt$season <- ifelse(mt$month >= 9, mt$year, mt$year - 1)
  mt <- mt[mt$month >= 9 | mt$month <= 4, ]
  st <- stats::aggregate(list(value = mt$value), list(season = mt$season),
                         sum)
  st[st$season >= 1 & st$season <= n_years, ]
}

gdd_daily <- function(tmin, tmax, method, base, upper, tmin_next = NULL) {
  degree_days(tmin, tmax, method = method, base = base, upper = upper,
              tmin_next = tmin_next)
}

monthly_rows <- list(); season_rows <- list()
add <- function(site, level, method, base, upper_name, est_mt, ref_mt) {
  key <- paste(site, level, method, base, upper_name)
  m <- merge(est_mt, ref_mt, by = c("year", "month"),
             suffixes = c("_est", "_ref"))
  monthly_rows[[key]] <<- data.frame(site = site, level = level,
    method = method, base = base, upper = upper_name, year = m$year,
    month = m$month, estimate = m$value_est, reference = m$value_ref)
  se <- season_totals(est_mt); sr <- season_totals(ref_mt)
  s <- merge(se, sr, by = "season", suffixes = c("_est", "_ref"))
  season_rows[[key]] <<- data.frame(site = site, level = level,
    method = method, base = base, upper = upper_name, season = s$season,
    estimate = s$value_est, reference = s$value_ref)
}

for (site in names(sites)) {
  s <- sites[[site]]
  message("Simulating ", site)
  sim <- simulate_site(s)
  n <- length(sim$tmin_obs)

  # Monthly levels: per-year monthly means and 30-year climatology.
  mm <- stats::aggregate(list(tmin = sim$tmin_obs, tmax = sim$tmax_obs),
                         list(year = sim$year, month = sim$month), mean)
  mm <- mm[order(mm$year, mm$month), ]
  per_year <- densify_monthly(
    matrix(mm$tmin, ncol = 12, byrow = TRUE),
    matrix(mm$tmax, ncol = 12, byrow = TRUE),
    engine = "native", consistency = "mean_range")
  clim_m <- stats::aggregate(list(tmin = sim$tmin_obs, tmax = sim$tmax_obs),
                             list(month = sim$month), mean)
  clim <- densify_monthly(clim_m$tmin, clim_m$tmax, engine = "native")
  yr_tmin <- as.vector(t(per_year$tmin)); yr_tmax <- as.vector(t(per_year$tmax))
  cl_tmin <- rep(as.vector(clim$tmin), n / 365)
  cl_tmax <- rep(as.vector(clim$tmax), n / 365)

  # Linvill reconstruction from the observed daily extremes.
  linvill <- hourly_temperatures(sim$tmin_obs, sim$tmax_obs,
                                 method = "linvill", latitude = s$lat,
                                 doy = sim$doy)

  for (b in bases) for (u in names(uppers)) {
    up <- uppers[[u]]
    ref <- degree_hours(sim$hourly, base = b, upper = up, by_day = TRUE)
    ref_mt <- monthly_totals(ref, sim$year, sim$month)
    for (m in daily_methods) {
      nxt <- if (startsWith(m, "double")) c(sim$tmin_obs[-1], NA) else NULL
      est <- gdd_daily(sim$tmin_obs, sim$tmax_obs, m, b, up, nxt)
      add(site, "daily", m, b, u, monthly_totals(est, sim$year, sim$month),
          ref_mt)
      nxt <- if (startsWith(m, "double")) c(yr_tmin[-1], NA) else NULL
      est <- gdd_daily(yr_tmin, yr_tmax, m, b, up, nxt)
      add(site, "monthly", m, b, u, monthly_totals(est, sim$year, sim$month),
          ref_mt)
      nxt <- if (startsWith(m, "double")) c(cl_tmin[-1], cl_tmin[1]) else NULL
      est <- gdd_daily(cl_tmin, cl_tmax, m, b, up, nxt)
      add(site, "climatology", m, b, u,
          monthly_totals(est, sim$year, sim$month), ref_mt)
    }
    est <- degree_hours(as.vector(t(linvill)), base = b, upper = up,
                        by_day = TRUE)
    add(site, "daily", "hourly_linvill", b, u,
        monthly_totals(est, sim$year, sim$month), ref_mt)
  }
}

monthly <- do.call(rbind, monthly_rows)
season <- do.call(rbind, season_rows)
monthly <- monthly[!is.na(monthly$estimate), ]

metrics <- do.call(rbind, lapply(split(season, list(season$site, season$level,
    season$method, season$base, season$upper), drop = TRUE), function(d) {
  e <- d$estimate - d$reference
  data.frame(site = d$site[1], level = d$level[1], method = d$method[1],
             base = d$base[1], upper = d$upper[1], n = nrow(d),
             reference_mean = mean(d$reference), bias = mean(e),
             mae = mean(abs(e)), rmse = sqrt(mean(e^2)),
             rel_bias_pct = 100 * mean(e) / mean(d$reference),
             r = if (stats::sd(d$estimate) > 0) stats::cor(d$estimate,
                                                     d$reference) else NA)
}))
monthly_bias <- stats::aggregate(
  list(bias = monthly$estimate - monthly$reference,
       reference = monthly$reference),
  monthly[c("site", "level", "method", "base", "upper", "month")], mean)

num <- vapply(metrics, is.numeric, TRUE)
metrics[num] <- lapply(metrics[num], round, 3)
monthly_bias$bias <- round(monthly_bias$bias, 3)
monthly_bias$reference <- round(monthly_bias$reference, 3)
utils::write.csv(metrics, file.path(out_dir, "gdd-synthetic-season.csv"),
                 row.names = FALSE)
utils::write.csv(monthly_bias, file.path(out_dir, "gdd-synthetic-monthly.csv"),
                 row.names = FALSE)
writeLines(c(paste("thermify", as.character(utils::packageVersion("thermify"))),
             paste("seed 20261119;", n_years, "seasons per site")),
           file.path(out_dir, "gdd-synthetic-provenance.txt"))
message("Done: ", nrow(metrics), " metric rows")
