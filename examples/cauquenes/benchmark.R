# Benchmarks for the Cauquenes case study. Sourced by run.R.
#
# Times are wall-clock medians from bench::mark(); memory is the memory
# allocated by R during the expression (bench "mem_alloc"). Allocation inside
# Python (tempify) is not visible to R and is reported separately as the R/
# Python overhead of a one-cell call.

run_benchmarks <- function(vmin, vmax, ref, cfg, wc, dirs, iterations = 5) {
  if (!requireNamespace("bench", quietly = TRUE)) {
    warning("bench not installed; skipping benchmarks")
    return(data.frame())
  }
  n <- nrow(vmin)
  dens <- densify_monthly(vmin, vmax, year = cfg$year, engine = "native")
  dates <- dens$dates
  doy <- as.integer(format(dates, "%j"))
  lat <- rep(cfg$centre[["lat"]], n)
  hourly <- hourly_temperatures(dens$tmin, dens$tmax, "linvill",
                                latitude = lat, doy = doy, cyclic = TRUE)
  chill <- thermify::season_days(dates, cfg$chill_period[1],
                                 cfg$chill_period[2], cyclic = TRUE)
  chill_cols <- as.vector(outer(1:24, (chill - 1L) * 24L, `+`))
  hourly_chill <- hourly[, chill_cols, drop = FALSE]
  vtmin <- as.vector(dens$tmin)
  vtmax <- as.vector(dens$tmax)

  row <- function(stage, variant, b, cells = n) {
    data.frame(stage = stage, variant = variant, cells = cells,
               median_s = as.numeric(b$median),
               per_cell_ms = 1000 * as.numeric(b$median) / cells,
               mem_alloc_mb = as.numeric(b$mem_alloc) / 2^20)
  }
  # Quote the expression so that bench times its evaluation, not the
  # forcing of an already evaluated promise.
  mark <- function(expr, n = iterations) {
    bench::mark(exprs = list(substitute(expr)), env = parent.frame(),
                iterations = n, check = FALSE, filter_gc = FALSE)
  }
  out <- list()

  out[[length(out) + 1]] <- row("densify", "native pchip_mp",
    mark(densify_monthly(vmin, vmax, year = cfg$year, engine = "native")))
  if (tempify_available()) {
    out[[length(out) + 1]] <- row("densify", "tempify pchip_mp",
      mark(densify_monthly(vmin, vmax, year = cfg$year, engine = "tempify")))
    out[[length(out) + 1]] <- row("densify", "tempify, 1 cell (overhead)",
      mark(densify_monthly(vmin[1, ], vmax[1, ], year = cfg$year,
                           engine = "tempify")), cells = 1)
    out[[length(out) + 1]] <- row("densify", "native, 1 cell",
      mark(densify_monthly(vmin[1, ], vmax[1, ], year = cfg$year,
                           engine = "native")), cells = 1)
  }
  for (m in c("average", "single_sine", "single_triangle", "double_sine",
              "double_triangle")) {
    out[[length(out) + 1]] <- row("gdd (daily, 365 d)", m,
      mark(degree_days(vtmin, vtmax, method = m, base = 10)))
  }
  out[[length(out) + 1]] <- row("gdd (daily, 365 d)", "hourly (degree-hours)",
    mark(degree_hours(hourly, base = 10, by_day = TRUE)))
  out[[length(out) + 1]] <- row("chill hours (365 d)", "sine, analytical",
    mark(chill_hours(vtmin, vtmax)))
  out[[length(out) + 1]] <- row("chill hours (365 d)",
    "sine, numerical (1440 steps)",
    mark(chill_hours(vtmin, vtmax, method = "numerical")))
  out[[length(out) + 1]] <- row("chill hours (365 d)", "hourly count",
    mark(chill_hours_hourly(hourly, output = "total")))
  out[[length(out) + 1]] <- row("hourly reconstruction (365 d)", "linvill",
    mark(hourly_temperatures(dens$tmin, dens$tmax, "linvill", latitude = lat,
                             doy = doy, cyclic = TRUE)))
  out[[length(out) + 1]] <- row("hourly reconstruction (365 d)", "sine",
    mark(hourly_temperatures(dens$tmin, dens$tmax, "sine", cyclic = TRUE)))
  out[[length(out) + 1]] <- row("chill period models", "utah",
    mark(chill_units(hourly_chill, output = "total")))
  out[[length(out) + 1]] <- row("chill period models", "dynamic",
    mark(chill_portions(hourly_chill, output = "total")))

  # Full workflow: one block versus small blocks (identical results).
  run_rast <- function(max_cells) {
    thermify_rast(wc$tmin, wc$tmax, output_dir = tempfile(),
                  year = cfg$year, temporal = "native",
                  gdd_methods = c("average", "single_sine"), base = 10,
                  max_cells = max_cells)
  }
  big <- run_rast(1e6)
  small <- run_rast(50)
  same <- all(vapply(names(big), function(k)
    isTRUE(all.equal(terra::values(big[[k]]), terra::values(small[[k]]))),
    logical(1)))
  if (!same) warning("Block and full processing differ")
  out[[length(out) + 1]] <- row("thermify_rast (native)", "one block",
    mark(run_rast(1e6), n = 3))
  out[[length(out) + 1]] <- row("thermify_rast (native)",
    "blocks of 50 cells",
    mark(run_rast(50), n = 3))
  res <- do.call(rbind, out)
  res$blocks_equal_full <- same
  res
}
