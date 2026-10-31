# Figures for the Cauquenes case study. Sourced by run.R.

make_figures <- function(ref, monthly_domain, ref_tmin, ref_tmax, hr_chill,
                         season, diffs, bench_tab, cfg, dirs, smoke_test) {
  fig <- function(name, width = 2000, height = 1300, expr) {
    grDevices::png(file.path(dirs[["figures"]], name), width = width,
                   height = height, res = 220)
    on.exit(grDevices::dev.off())
    graphics::par(mar = c(4.2, 4.5, 3.2, 1), cex.main = 0.95)
    expr
    if (smoke_test) {
      graphics::mtext("SYNTHETIC TEST DATA - NOT WORLDCLIM", side = 3,
                      line = -1.5, col = "red", font = 2, outer = TRUE)
    }
  }
  source_note <- paste0("WorldClim 2.1 normals 1970-2000; reference ",
                        "calendar ", cfg$year,
                        " (climatological estimate, not observations)")
  pal <- c("#0B5563", "#E07A1F", "#5DA9C9", "#9C2F2F", "#6B8E23", "#7A5195")
  d <- ref$daily
  mid <- as.Date(sprintf("%d-%02d-15", cfg$year, 1:12))

  # 1. Monthly normals and daily reconstruction
  fig("01_monthly_daily_reconstruction.png", expr = {
    yl <- range(c(d$tmin, d$tmax, ref_tmin, ref_tmax))
    plot(d$date, d$tmax, type = "l", col = pal[2], lwd = 1.6, ylim = yl,
         xlab = "", ylab = "Temperature (degC)",
         main = paste0("Reference cell: monthly normals and daily ",
                       "reconstruction (", cfg$interpolation, ")"))
    graphics::lines(d$date, d$tmin, col = pal[1], lwd = 1.6)
    starts <- as.Date(sprintf("%d-%02d-01", cfg$year, 1:12))
    ends <- c(starts[-1], as.Date(sprintf("%d-01-01", cfg$year + 1))) - 1
    graphics::segments(starts, ref_tmax, ends, ref_tmax, col = pal[2],
                       lty = 2)
    graphics::segments(starts, ref_tmin, ends, ref_tmin, col = pal[1],
                       lty = 2)
    graphics::points(mid, ref_tmax, pch = 19, col = pal[2], cex = 0.7)
    graphics::points(mid, ref_tmin, pch = 19, col = pal[1], cex = 0.7)
    graphics::legend("bottomleft", bty = "n", cex = 0.75,
                     legend = c("Daily Tmax", "Daily Tmin",
                                "Monthly normal (mean preserved)"),
                     col = c(pal[2], pal[1], "grey30"), lty = c(1, 1, 2))
    graphics::mtext(source_note, side = 1, line = 3, cex = 0.6)
  })

  # 2. Hourly reconstruction: one summer and one winter week
  fig("02_hourly_reconstruction.png", expr = {
    hr <- ref$hourly
    graphics::par(mfrow = c(1, 2))
    for (w in list(c("01-10", "January"), c("07-10", "July"))) {
      start <- as.Date(sprintf("%d-%s", cfg$year, w[1]))
      sel <- hr$date >= start & hr$date < start + 7
      x <- seq_len(sum(sel)) - 1
      plot(x / 24, hr$temperature[sel], type = "l", col = pal[1], lwd = 1.5,
           xlab = sprintf("Days from %s", format(start, "%d %b")),
           ylab = "Temperature (degC)",
           main = sprintf("Hourly (%s), %s", cfg$hourly_method, w[2]))
      dd <- d[d$date >= start & d$date < start + 7, ]
      graphics::points(seq_len(nrow(dd)) - 0.5, dd$tmax, pch = 2,
                       col = pal[2])
      graphics::points(seq_len(nrow(dd)) - 0.5, dd$tmin, pch = 6,
                       col = pal[3])
      if (w[2] == "July") {
        graphics::abline(h = c(0, 7.2), lty = 3, col = "grey40")
      }
    }
    graphics::legend("topright", bty = "n", cex = 0.7, pch = c(2, 6),
                     col = pal[2:3], legend = c("Daily Tmax", "Daily Tmin"))
  })

  # 3. GDD methods: cumulative over the heat period
  fig("03_gdd_methods.png", expr = {
    idx <- season_days(d$date, cfg$heat_period[1], cfg$heat_period[2],
                       cyclic = TRUE)
    graphics::par(mfrow = c(1, 2))
    for (b in cfg$base) {
      keys <- sprintf("gdd_%s_b%s", cfg$gdd_methods, b)
      cum <- sapply(keys, function(k) cumsum(d[[k]][idx]))
      graphics::matplot(seq_along(idx), cum, type = "l", lty = 1, lwd = 1.4,
                        col = pal[seq_along(keys)],
                        xlab = sprintf("Days since %s", cfg$heat_period[1]),
                        ylab = "Cumulative GDD (degC day)",
                        main = sprintf("GDD base %s degC, %s to %s", b,
                                       cfg$heat_period[1],
                                       cfg$heat_period[2]))
      graphics::legend("topleft", bty = "n", cex = 0.6, lty = 1,
                       col = pal[seq_along(keys)],
                       legend = sprintf("%s: %.0f", cfg$gdd_methods,
                                        cum[nrow(cum), ]))
    }
  })

  # 4-6. Chill accumulation over the chill period
  x <- seq_len(nrow(hr_chill)) / 24
  xl <- sprintf("Days since %s", cfg$chill_period[1])
  fig("04_chill_hours_accumulation.png", expr = {
    idx <- season_days(d$date, cfg$chill_period[1], cfg$chill_period[2],
                       cyclic = TRUE)
    plot(x, hr_chill$ch_cumulative, type = "l", col = pal[1], lwd = 1.6,
         xlab = xl, ylab = "Cumulative chilling hours (h)",
         main = "Chilling hours 0-7.2 degC")
    graphics::lines(seq_along(idx), cumsum(d$ch_sine[idx]), col = pal[2],
                    lwd = 1.6, lty = 2)
    graphics::legend("topleft", bty = "n", cex = 0.75, lty = c(1, 2),
                     col = pal[1:2],
                     legend = c("Counted on Linvill hourly series",
                                "Analytical sine (daily extremes)"))
  })
  fig("05_utah_accumulation.png", expr = {
    plot(x, hr_chill$cu_cumulative, type = "l", col = pal[1], lwd = 1.6,
         xlab = xl, ylab = "Cumulative chill units (CU)",
         main = "Utah model (Richardson et al. 1974)")
    graphics::abline(h = 0, col = "grey60")
  })
  fig("06_dynamic_accumulation.png", expr = {
    plot(x, hr_chill$cp_cumulative, type = "l", col = pal[1], lwd = 1.6,
         xlab = xl, ylab = "Cumulative chill portions (CP)",
         main = "Dynamic model (Fishman et al. 1987; Erez et al. 1990)")
  })

  # 7. Maps
  fig("07_maps.png", width = 2400, height = 1700, expr = {
    keys <- c("gdd_single_sine_b5", "gdd_single_sine_b10", "ch_sine",
              "ch_hourly", "cu_utah", "cp_dynamic")
    titles <- c("GDD single sine, base 5 (degC day)",
                "GDD single sine, base 10 (degC day)",
                "Chilling hours, sine (h)", "Chilling hours, hourly (h)",
                "Utah chill units (CU)", "Dynamic chill portions (CP)")
    graphics::par(mfrow = c(2, 3), mar = c(2, 2, 2.5, 4))
    for (i in seq_along(keys)) {
      terra::plot(season[[keys[i]]], main = titles[i], cex.main = 0.85,
                  col = grDevices::hcl.colors(50, if (startsWith(keys[i],
                    "gdd")) "YlOrRd" else "Blues", rev = TRUE))
      graphics::points(cfg$centre[["lon"]], cfg$centre[["lat"]], pch = 3)
    }
  })

  # 8. Differences between methods
  fig("08_method_differences.png", width = 2400, height = 1700, expr = {
    graphics::par(mfrow = c(2, 3), mar = c(2, 2, 2.5, 4))
    for (k in names(diffs)) {
      v <- terra::values(diffs[[k]])
      lim <- max(abs(v), na.rm = TRUE)
      terra::plot(diffs[[k]], main = gsub("_", " ", k), cex.main = 0.8,
                  col = grDevices::hcl.colors(50, "Blue-Red 3"),
                  range = c(-lim, lim))
    }
  })

  # 9. Performance
  if (nrow(bench_tab)) {
    fig("09_performance.png", width = 2200, height = 1500, expr = {
      graphics::par(mar = c(4.2, 17, 3, 1))
      lab <- paste(bench_tab$stage, "-", bench_tab$variant)
      graphics::barplot(rev(bench_tab$per_cell_ms), names.arg = rev(lab),
                        horiz = TRUE, las = 1, cex.names = 0.55, log = "x",
                        col = pal[1], xlab = "Median time per cell (ms, log)",
                        main = "Computational cost per cell")
    })
  }
  invisible(TRUE)
}
