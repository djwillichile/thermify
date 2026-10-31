# Lightweight progress reporting for long-running loops.
#
# Interactive sessions get a single self-updating line; non-interactive runs
# (Rscript, logs, CI) get full lines at most every `every` seconds plus the
# first and last step, so logs show that the process is alive without
# flooding them. Output goes to the message stream and can be silenced with
# suppressMessages() or `progress = FALSE`.

progress_start <- function(total, label, enabled = TRUE, every = 10) {
  p <- new.env(parent = emptyenv())
  p$total <- total
  p$label <- label
  p$enabled <- isTRUE(enabled) && total > 0
  p$every <- every
  p$t0 <- proc.time()[["elapsed"]]
  p$last <- -Inf
  p$inline <- interactive()
  p
}

progress_tick <- function(p, done, detail = "") {
  if (!p$enabled) return(invisible())
  now <- proc.time()[["elapsed"]]
  final <- done >= p$total
  if (!p$inline && !final && done > 1 && now - p$last < p$every) {
    return(invisible())
  }
  p$last <- now
  elapsed <- now - p$t0
  eta <- if (done > 0) elapsed / done * (p$total - done) else NA_real_
  pct <- 100 * done / p$total
  width <- 20L
  filled <- round(width * done / p$total)
  bar <- paste0("[", strrep("=", filled), strrep(" ", width - filled), "]")
  line <- sprintf("%s %s %3.0f%% %d/%d | elapsed %s | ETA %s%s", p$label,
                  bar, pct, done, p$total, format_seconds(elapsed),
                  if (final) "0:00" else format_seconds(eta),
                  if (nzchar(detail)) paste0(" | ", detail) else "")
  if (p$inline) {
    message("\r", line, appendLF = final)
  } else {
    message(line)
  }
  invisible()
}

format_seconds <- function(s) {
  if (is.na(s) || !is.finite(s)) return("--:--")
  s <- round(s)
  h <- s %/% 3600
  m <- (s %% 3600) %/% 60
  sec <- s %% 60
  if (h > 0) sprintf("%d:%02d:%02d", h, m, sec) else sprintf("%d:%02d", m, sec)
}
