# Independent transcription of the Dynamic model equations (Fishman et al.
# 1987; Erez et al. 1990), written as a plain scalar loop.
dynamic_reference <- function(temp) {
  e0 <- 4153.5; e1 <- 12888.8; a0 <- 139500; a1 <- 2.567e18
  slp <- 1.6; tetmlt <- 277
  inter_s <- 0; total <- 0; out <- numeric(length(temp))
  for (i in seq_along(temp)) {
    tk <- temp[i] + 273
    ftmprt <- slp * tetmlt * (tk - tetmlt) / tk
    sr <- exp(ftmprt)
    xi <- sr / (1 + sr)
    xs <- a0 / a1 * exp((e1 - e0) / tk)
    ak1 <- a1 * exp(-e1 / tk)
    inter_e <- xs - (xs - inter_s) * exp(-ak1)
    if (inter_e >= 1) {
      delt <- xi * inter_e
      inter_s <- inter_e - delt
    } else {
      delt <- 0
      inter_s <- inter_e
    }
    total <- total + delt
    out[i] <- total
  }
  out
}

hourly_fixture <- function(days = 60, seed = 1) {
  set.seed(seed)
  doy <- seq_len(days) + 120
  tmin <- 3 + rnorm(days)
  tmax <- tmin + 11 + rnorm(days)
  hourly_temperatures(tmin, tmax, "linvill", latitude = -35.97, doy = doy)
}

test_that("implementation matches the original equations", {
  temp <- hourly_fixture()
  expect_equal(as.vector(chill_portions(temp)), dynamic_reference(temp),
               tolerance = 1e-12)
})

test_that("known behaviour: optimal temperatures accumulate, warm do not", {
  expect_equal(as.vector(chill_portions(rep(25, 1000), output = "total")), 0)
  cp6 <- as.vector(chill_portions(rep(6, 24 * 30), output = "total"))
  cp15 <- as.vector(chill_portions(rep(15, 24 * 30), output = "total"))
  expect_gt(cp6, cp15)
  # About 0.9-1 portion per day at a constant 6 degrees C.
  expect_gt(cp6 / 30, 0.8)
  expect_lt(cp6 / 30, 1.1)
  # Portions are irreversible: the cumulative series never decreases.
  cp <- chill_portions(c(rep(6, 200), rep(25, 200), rep(6, 200)))
  expect_true(all(diff(as.vector(cp)) >= 0))
})

test_that("block processing equals full processing", {
  temp <- hourly_fixture(90)
  full <- chill_portions(temp)
  cut <- c(0, 517, 1201, 2000, length(temp))
  state <- NULL
  pieces <- list()
  for (i in seq_len(length(cut) - 1)) {
    blk <- chill_portions(temp[(cut[i] + 1):cut[i + 1]], state = state)
    state <- attr(blk, "state")
    pieces[[i]] <- as.vector(blk)
  }
  expect_equal(unlist(pieces), as.vector(full), tolerance = 1e-12)
  expect_equal(state$portions, attr(full, "state")$portions)
})

test_that("matrix rows are independent series", {
  a <- hourly_fixture(30, 1)
  b <- hourly_fixture(30, 2)
  m <- chill_portions(rbind(a, b), output = "total")
  expect_equal(as.vector(m), c(as.vector(chill_portions(a, output = "total")),
                               as.vector(chill_portions(b, output = "total"))))
})

test_that("missing values propagate or are held", {
  temp <- hourly_fixture(10)
  temp[100] <- NA
  expect_true(is.na(as.vector(chill_portions(temp, output = "total"))))
  held <- chill_portions(temp, na_action = "hold")
  expect_false(anyNA(held))
  expect_equal(attr(held, "n_missing"), 1)
})

test_that("numerical stability over long and extreme series", {
  temp <- rep(c(-30, 0, 6, 45), length.out = 24 * 365)
  cp <- chill_portions(temp, output = "total")
  expect_true(is.finite(cp))
  expect_gte(cp, 0)
  expect_error(chill_portions(1:10, state = list(a = 1)), "state")
})
