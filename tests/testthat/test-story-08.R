# US-08 Working without Python (docs/USER_STORIES.md)

tmin_m <- c(11.8, 11.1, 9.6, 7.9, 6.6, 5.5, 4.8, 4.9, 5.9, 7.5, 9.2, 11.1)
tmax_m <- c(27.4, 26.5, 23.5, 19.3, 15.5, 12.9, 12.6, 13.9, 16.1, 18.8, 21.9,
            25.2)

test_that("auto falls back to the native engine", {
  local_mocked_bindings(tempify_available = function() FALSE)
  res <- thermify(tmin_m, tmax_m, latitude = -35.97, temporal = "auto")
  expect_identical(res$provenance$densification$engine, "native")
  expect_null(res$provenance$densification$tempify)
  expect_gt(nrow(res$summary), 0)
})

test_that("an explicit tempify request explains the alternative", {
  local_mocked_bindings(tempify_available = function() FALSE)
  expect_error(densify_monthly(tmin_m, tmax_m, engine = "tempify"),
               "engine = \"native\"")
  expect_null(tempify_version())
})

test_that("tempify-only methods are reported under the native engine", {
  expect_error(densify_monthly(tmin_m, tmax_m, engine = "native",
                               method = "fourier"), "tempify")
})
