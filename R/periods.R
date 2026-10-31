#' Select the days of an accumulation period
#'
#' Returns the positions of `dates` that fall inside a seasonal window given
#' as `"MM-DD"` bounds (both inclusive), in chronological order of the
#' season. Windows may cross the end of the year (for example `"09-01"` to
#' `"04-30"`, the southern-hemisphere growing season).
#'
#' For a climatological year (`cyclic = TRUE`, one calendar year representing
#' a closed annual cycle) a window that crosses the year end is returned as
#' the tail of the year followed by its head, so that sequential models such as
#' the Dynamic model run through the season in the right order. For observed
#' multi-year series (`cyclic = FALSE`) the attribute `"season"` gives the
#' calendar year in which each selected day's season starts.
#'
#' Southern-hemisphere defaults used by [thermify()]: chill accumulation from
#' 1 May to 31 August and heat accumulation from 1 September to 30 April. They
#' are conventions, not universal truths: adapt them to the species, cultivar
#' and region.
#'
#' @param dates Vector of class `Date`.
#' @param start,end Window bounds as `"MM-DD"`.
#' @param cyclic Treat `dates` as one closed climatological year.
#' @return Integer vector of positions in `dates`, with attribute `"season"`.
#' @examples
#' d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "day")
#' idx <- season_days(d, "09-01", "04-30", cyclic = TRUE)
#' range(d[idx][1:3]); length(idx)
#' @export
season_days <- function(dates, start, end, cyclic = FALSE) {
  if (!inherits(dates, "Date")) stop("`dates` must be of class Date.",
                                     call. = FALSE)
  s <- parse_mmdd(start, "start")
  e <- parse_mmdd(end, "end")
  key <- as.integer(format(dates, "%m")) * 100L +
    as.integer(format(dates, "%d"))
  wraps <- s > e
  inside <- if (wraps) key >= s | key <= e else key >= s & key <= e
  year <- as.integer(format(dates, "%Y"))
  season <- if (wraps) ifelse(key >= s, year, year - 1L) else year
  idx <- which(inside)
  if (cyclic && wraps) {
    idx <- c(which(inside & key >= s), which(inside & key <= e))
    season <- rep(year[1L], length(dates))
  }
  structure(idx, season = season[idx])
}

parse_mmdd <- function(x, name) {
  if (!is.character(x) || length(x) != 1L ||
      !grepl("^[01][0-9]-[0-3][0-9]$", x)) {
    stop(sprintf("`%s` must be a single \"MM-DD\" string.", name),
         call. = FALSE)
  }
  probe <- as.Date(paste0("2024-", x), optional = TRUE)
  if (is.na(probe)) stop(sprintf("`%s` is not a valid date.", name),
                         call. = FALSE)
  as.integer(substr(x, 1, 2)) * 100L + as.integer(substr(x, 4, 5))
}
