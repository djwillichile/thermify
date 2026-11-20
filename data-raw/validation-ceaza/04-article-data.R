# Step 4: compact tables for the pkgdown article
# vignettes/articles/validation-ceaza.Rmd, from the results of 03-validate.R.
#
#   Rscript data-raw/validation-ceaza/04-article-data.R

res <- "data-raw/validation-ceaza/results"
out <- "vignettes/articles/data"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

stations <- utils::read.csv(file.path(res, "ceaza-stations.csv"),
                            encoding = "UTF-8")
stations <- stations[stations$selected,
                     c("station", "name", "lat", "lon", "elevation")]
seasons <- utils::read.csv(file.path(res, "ceaza-seasons.csv"))

# Relative bias and MAE per station, index, level and method.
key <- seasons[c("station", "index", "level", "method")]
groups <- unique(key)
per_station <- do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
  g <- groups[i, ]
  d <- seasons[seasons$station == g$station & seasons$index == g$index &
                 seasons$level == g$level & seasons$method == g$method, ]
  e <- d$estimate - d$observed
  data.frame(g, n = nrow(d), observed = mean(d$observed),
             bias = mean(e), mae = mean(abs(e)),
             rel_bias = 100 * mean(e) / mean(d$observed))
}))
num <- vapply(per_station, is.numeric, TRUE)
per_station[num] <- lapply(per_station[num], round, 3)

utils::write.csv(stations, file.path(out, "ceaza-stations.csv"),
                 row.names = FALSE, fileEncoding = "UTF-8")
utils::write.csv(per_station, file.path(out, "ceaza-per-station.csv"),
                 row.names = FALSE)
file.copy(file.path(res, "ceaza-metrics.csv"),
          file.path(out, "ceaza-metrics.csv"), overwrite = TRUE)
file.copy(file.path(res, "ceaza-ensemble-weights.csv"),
          file.path(out, "ceaza-ensemble-weights.csv"), overwrite = TRUE)
