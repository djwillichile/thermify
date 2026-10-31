# Analytical diurnal temperature profiles.
#
# Every daily method in thermify is built on two functionals of an idealised
# diurnal profile between a minimum `lo` and a maximum `hi`:
#
#   excess(x)   I(x) = (1 / P) * integral over the day of max(0, T(t) - x) dt
#   above(x)    F(x) = fraction of the day with T(t) > x
#
# Both depend only on the distribution of temperatures within the day, not on
# the timing of the extremes. For a sine wave this distribution is the arcsine
# law; for a symmetric triangle it is uniform. Half-day segments (used by the
# double methods) have the same distribution as a full day with the same
# extremes, so the same functionals apply.

profile_excess <- function(lo, hi, x, shape = c("sine", "triangle")) {
  shape <- match.arg(shape)
  mid <- (lo + hi) / 2
  if (shape == "sine") {
    amp <- (hi - lo) / 2
    z <- (x - mid) / amp
    z[!is.finite(z)] <- sign(x - mid)[!is.finite(z)]
    theta <- asin(pmin(1, pmax(-1, z)))
    out <- ((mid - x) * (pi / 2 - theta) + amp * cos(theta)) / pi
    flat <- !is.na(amp) & amp == 0
    out[flat] <- pmax(0, mid - x)[flat]
  } else {
    rng <- hi - lo
    out <- ifelse(x <= lo, mid - x,
                  ifelse(x >= hi, 0, (hi - x)^2 / (2 * rng)))
  }
  # Guard against round-off producing tiny negative values.
  pmax(0, out)
}

profile_above <- function(lo, hi, x, shape = c("sine", "triangle")) {
  shape <- match.arg(shape)
  mid <- (lo + hi) / 2
  if (shape == "sine") {
    amp <- (hi - lo) / 2
    z <- (x - mid) / amp
    out <- 0.5 - asin(pmin(1, pmax(-1, z))) / pi
  } else {
    out <- pmin(1, pmax(0, (hi - x) / (hi - lo)))
  }
  flat <- !is.na(lo) & !is.na(hi) & hi == lo
  out[flat] <- as.numeric(mid[flat] > x)
  out
}

# Degree-days for one profile and one pair of thresholds, applying the
# requested upper-threshold cutoff. Expressed in terms of I() and F():
#
#   none          I(L)
#   horizontal    I(L) - I(U)
#   vertical      I(L) - I(U) - (U - L) F(U)
#   intermediate  I(L) - 2 I(U) + I(2U - L)
#
# The intermediate rate is (U - L) - (T - U) above U, floored at zero; the
# last term restores that floor and is zero whenever T < 2U - L.
profile_degree_days <- function(lo, hi, base, upper, cutoff, shape) {
  il <- profile_excess(lo, hi, base, shape)
  if (is.null(upper)) return(il)
  iu <- profile_excess(lo, hi, upper, shape)
  switch(cutoff,
    horizontal = il - iu,
    vertical = il - iu - (upper - base) * profile_above(lo, hi, upper, shape),
    intermediate = il - 2 * iu +
      profile_excess(lo, hi, 2 * upper - base, shape)
  )
}

# Numerical reference: evaluate the profile on `n` equally spaced instants
# (midpoint rule) over one day. Used for verification, not as a default engine.
profile_values <- function(lo, hi, n = 1440L, shape = c("sine", "triangle")) {
  shape <- match.arg(shape)
  phase <- (seq_len(n) - 0.5) / n
  wave <- if (shape == "sine") {
    -cos(2 * pi * phase)
  } else {
    ifelse(phase < 0.5, 4 * phase - 1, 3 - 4 * phase)
  }
  mid <- (lo + hi) / 2
  amp <- (hi - lo) / 2
  outer(mid, rep(1, n)) + outer(amp, wave)
}
