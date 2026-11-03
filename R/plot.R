#' Plot and print the maps produced by thermify_rast()
#'
#' `plot()` draws the index maps returned by [thermify_rast()], one panel per
#' index and layer, with titles, units and a colour palette per index family.
#' When a single index is shown month by month, each panel is titled with the
#' month and units and the index name is written once above the panels.
#' `print()` summarises the object.
#'
#' @param x An object returned by [thermify_rast()].
#' @param variable Indices to plot: full keys such as `"cp_dynamic"` or
#'   `"gdd_single_sine_b10"`, or families `"gdd"`, `"ch"`, `"cu"`, `"cp"`.
#'   `NULL` (default) plots every index.
#' @param type Layer to plot: `"season"` (default), `"annual"`, `"monthly"`
#'   (the 12 monthly layers), or one or more month layers such as `"m07"`.
#'   Utah units and chill portions have no `"annual"` layer, and their months
#'   outside the chill period hold no data; such layers are left out with a
#'   message.
#' @param nrow,ncol Panel layout. When both are `NULL` the layout is chosen
#'   from the number of panels; when one is given the other is derived.
#' @param col Colours for the maps, as a vector of colours or a function of
#'   the number of colours. `NULL` (default) uses one sequential palette per
#'   family: orange-red for degree-days, blue for chilling hours, purple for
#'   Utah units and green for chill portions.
#' @param boundary Optional `SpatVector` drawn over every panel, for example
#'   [cauquenes_boundary()]. It is projected to the raster CRS when needed.
#' @param range `"variable"` (default) uses a common colour scale for all
#'   panels of the same index, so that months are comparable; `"panel"`
#'   scales each panel on its own.
#' @param titles Panel titles: `"auto"` (default) writes the index and method,
#'   period and units in each panel, except when a single index is shown
#'   month by month, where panels show only the month and units and the
#'   index name is written once above them; `"full"` always writes the index
#'   and method in each panel; `"short"` writes only the period or month and
#'   the units (and the index name once above, when there is a single index).
#' @param ... Further arguments passed to [terra::plot()]. Titles that do
#'   not fit in the width of a panel are wrapped onto several lines, breaking
#'   preferably between method, period and units, and the top margin grows
#'   to make room for them; `cex.main` changes their size. Only in very small
#'   panels, where the lines would take too much of the height, is the title
#'   reduced. A `main`
#'   given here (one title, or one per panel) replaces the automatic titles
#'   and is not wrapped.
#' @return `x`, invisibly.
#' @seealso [thermify_rast()]
#' @examples
#' r <- rast(nrows = 4, ncols = 4, nlyrs = 12,
#'           xmin = -72.4, xmax = -72.3, ymin = -36, ymax = -35.9)
#' base_min <- c(11, 11, 9, 7, 5, 4, 3, 4, 5, 6, 8, 10)
#' base_max <- c(29, 29, 26, 22, 17, 14, 13, 15, 18, 21, 25, 28)
#' tmin <- setValues(r, outer(seq(-1, 1, length.out = 16), base_min, "+"))
#' tmax <- setValues(r, outer(seq(-1, 1, length.out = 16), base_max, "+"))
#' maps <- thermify_rast(tmin, tmax, output_dir = tempfile(),
#'                       temporal = "native", indices = c("gdd", "cp"),
#'                       gdd_methods = "single_sine", base = 10,
#'                       progress = FALSE)
#' maps
#' plot(maps)
#' plot(maps, variable = "gdd", type = "monthly", nrow = 3, ncol = 4)
#' plot(maps, variable = "cp_dynamic", type = c("m06", "m07"))
#' plot(maps, variable = "gdd", type = "monthly", titles = "full")
#' @name plot.thermify_rast
#' @export
plot.thermify_rast <- function(x, variable = NULL, type = "season",
                               nrow = NULL, ncol = NULL, col = NULL,
                               boundary = NULL,
                               range = c("variable", "panel"),
                               titles = c("auto", "full", "short"), ...) {
  range <- match.arg(range)
  titles <- match.arg(titles)
  keys <- select_keys(names(x), variable)
  layers <- select_layers(type)
  if (!is.null(boundary) && !inherits(boundary, "SpatVector")) {
    stop("`boundary` must be a SpatVector.", call. = FALSE)
  }

  panels <- list()
  skipped <- character()
  empty <- character()
  for (k in keys) {
    available <- intersect(layers, names(x[[k]]))
    if (length(available) == 0L) {
      skipped <- c(skipped, k)
      next
    }
    for (l in available) {
      # Months outside the accumulation period hold no data (for example
      # Utah units in January): leave them out instead of drawing blanks.
      if (has_no_data(x[[k]][[l]])) {
        empty <- c(empty, stats::setNames(l, k))
        next
      }
      panels[[length(panels) + 1L]] <- c(key = k, layer = l)
    }
  }
  if (length(empty) > 0L) {
    by_key <- split(unname(empty), names(empty))
    message("No data outside the accumulation period, left out: ",
            paste(vapply(names(by_key), function(k) {
              paste0(k, " (", paste(layer_label(by_key[[k]]), collapse = ", "),
                     ")")
            }, ""), collapse = "; "), ".")
  }
  if (length(skipped) > 0L) {
    message("No ", paste(type, collapse = ", "), " layer for: ",
            paste(skipped, collapse = ", "), ".")
  }
  if (length(panels) == 0L) {
    stop("Nothing to plot for the requested `variable` and `type`.",
         call. = FALSE)
  }

  layout <- panel_layout(length(panels), nrow, ncol)
  # One index shown month by month: short panel titles (month and units)
  # and the index name once, as a title over all panels.
  panel_keys <- unique(vapply(panels, `[[`, "", "key"))
  user_main <- list(...)$main
  short <- switch(titles,
    full = FALSE,
    short = TRUE,
    auto = length(panels) > 1L && length(panel_keys) == 1L &&
      all(vapply(panels, `[[`, "", "layer") %in% sprintf("m%02d", 1:12)))
  # The index name goes once above the panels when every panel shows the
  # same index with short titles.
  overall <- short && length(panels) > 1L && length(panel_keys) == 1L &&
    is.null(user_main)
  if (length(panels) > 1L) {
    op <- graphics::par(mfrow = layout,
                        oma = if (overall) c(0, 0, 2, 0)
                        else graphics::par("oma"))
    on.exit(graphics::par(op), add = TRUE)
  }
  if (!is.null(boundary)) {
    boundary <- terra::project(boundary, terra::crs(x[[keys[1]]]))
  }
  config <- attr(x, "provenance")$config
  scales <- list()
  for (i in seq_along(panels)) {
    p <- panels[[i]]
    k <- p[["key"]]
    r <- x[[k]][[p[["layer"]]]]
    zlim <- if (range == "variable") {
      if (is.null(scales[[k]])) {
        v <- terra::minmax(x[[k]][[intersect(layers, names(x[[k]]))]],
                           compute = TRUE)
        scales[[k]] <- c(min(v[1, ], na.rm = TRUE), max(v[2, ], na.rm = TRUE))
      }
      scales[[k]]
    }
    pal <- index_palette(k, col)
    dots <- list(...)
    title <- if (is.null(user_main)) {
      if (short) {
        short_title(k, p[["layer"]], config)
      } else {
        panel_title(k, p[["layer"]], config)
      }
    } else {
      rep_len(user_main, length(panels))[i]
    }
    if (is.null(user_main)) {
      # Wrap the title to the width of the panel and make room for it.
      mar <- if (is.null(dots$mar)) c(2, 2, 2, 4) else dots$mar
      cex <- if (is.null(dots$cex.main)) 1.2 else dots$cex.main
      fitted <- fit_title(title, mar, cex)
      title <- fitted$title
      if (fitted$cex != cex) dots$cex.main <- fitted$cex
      n_lines <- length(strsplit(title, "\n")[[1]])
      if (is.null(dots$mar) && n_lines > 1L) {
        mar[3] <- mar[3] + 1.1 * (n_lines - 1L)
        # Only when the panel can take the larger margin; otherwise leave
        # the margins to terra (tiny panels).
        csi <- graphics::par("csi")
        fin <- graphics::par("fin")
        if (fin[2] > (mar[1] + mar[3]) * csi + 0.5 &&
            fin[1] > (mar[2] + mar[4]) * csi + 0.5) {
          dots$mar <- mar
        }
      }
    }
    args <- list(r, col = pal, main = title)
    if (!is.null(zlim) && all(is.finite(zlim)) && diff(zlim) > 0) {
      args$range <- zlim
    }
    do.call(draw_panel, c(args, dots[setdiff(names(dots), "main")]))
    if (!is.null(boundary)) terra::lines(boundary)
  }
  if (overall) draw_overall_title(index_label(panel_keys))
  invisible(x)
}

#' @rdname plot.thermify_rast
#' @export
print.thermify_rast <- function(x, ...) {
  p <- attr(x, "provenance")
  r <- x[[1]]
  cat("<thermify_rast>", length(x), "indices,",
      terra::nrow(r), "x", terra::ncol(r), "cells")
  if (!is.null(p$n_valid_cells)) cat(",", p$n_valid_cells, "valid")
  cat("\n")
  if (!is.null(p)) {
    cat("engine:", p$engine, "| interpolation:", p$interpolation,
        "| reference year:", p$year, "\n")
  }
  for (k in names(x)) {
    cat(sprintf("  %-24s %-14s %s\n", k, paste0("[", index_units(k), "]"),
                paste(names(x[[k]]), collapse = " ")))
  }
  files <- unique(terra::sources(r))
  if (length(files) && nzchar(files[1])) {
    cat("files in:", dirname(files[1]), "\n")
  }
  invisible(x)
}

# Width (inches) available for a title over one panel: the width of the
# plot region, since the title is centred on the map and must not run into
# the legend on its right.
panel_width <- function(mar) {
  fin <- graphics::par("fin")[1]
  csi <- graphics::par("csi")
  max(fin - (mar[2] + mar[4]) * csi, 0.5)
}

# Wrap a title to the panel width. When the lines would take too much of
# the panel height (very small panels), reduce the size step by step.
fit_title <- function(title, mar, cex) {
  width <- panel_width(mar)
  csi <- graphics::par("csi")
  # Keep at least about half of the panel height for the map.
  max_lines <- max(1L, floor(0.5 * graphics::par("fin")[2] / csi / 1.1))
  repeat {
    wrapped <- wrap_title(title, width, cex = cex)
    n <- length(strsplit(wrapped, "\n")[[1]])
    if (n <= max_lines || cex <= 0.6) break
    cex <- round(cex - 0.1, 1)
  }
  list(title = wrapped, cex = cex)
}

# Break a title into lines that fit in `width` inches. Breaks prefer the
# commas between method, period and units; long parts are split at spaces.
wrap_title <- function(title, width, cex = 1.2, font = 2L) {
  fits <- function(txt) {
    graphics::strwidth(txt, units = "inches", cex = cex, font = font) <=
      width
  }
  if (fits(title)) return(title)
  parts <- strsplit(title, "(?<=,) ", perl = TRUE)[[1]]
  pieces <- unlist(lapply(parts, function(part) {
    if (fits(part)) return(part)
    words <- strsplit(part, " ", fixed = TRUE)[[1]]
    out <- character()
    line <- ""
    for (w in words) {
      cand <- if (nzchar(line)) paste(line, w) else w
      if (fits(cand) || !nzchar(line)) {
        line <- cand
      } else {
        out <- c(out, line)
        line <- w
      }
    }
    c(out, line)
  }))
  lines <- character()
  line <- ""
  for (pc in pieces) {
    cand <- if (nzchar(line)) paste(line, pc) else pc
    if (fits(cand) || !nzchar(line)) {
      line <- cand
    } else {
      lines <- c(lines, line)
      line <- pc
    }
  }
  paste(c(lines, line), collapse = "\n")
}

has_no_data <- function(r) {
  isTRUE(terra::global(r, "notNA")[1, 1] == 0)
}

# Index name above all panels (or above the single panel).
draw_overall_title <- function(text) {
  graphics::mtext(text, side = 3, line = 0.5, outer = TRUE, font = 2,
                  cex = 1.2)
}

# Wrapper so that tests can count panels without drawing them.
draw_panel <- function(...) terra::plot(...)

select_keys <- function(keys, variable) {
  if (is.null(variable)) return(keys)
  if (!is.character(variable) || length(variable) == 0L || anyNA(variable)) {
    stop("`variable` must be index keys or families (gdd, ch, cu, cp).",
         call. = FALSE)
  }
  out <- character()
  for (v in variable) {
    hit <- if (v %in% keys) v else keys[startsWith(keys, paste0(v, "_"))]
    if (length(hit) == 0L) {
      stop(sprintf("`variable` \"%s\" is not in the object. Available: %s.",
                   v, paste(keys, collapse = ", ")), call. = FALSE)
    }
    out <- c(out, hit)
  }
  unique(out)
}

select_layers <- function(type) {
  months <- sprintf("m%02d", 1:12)
  if (!is.character(type) || length(type) == 0L || anyNA(type)) {
    stop("`type` must be \"season\", \"annual\", \"monthly\" or month ",
         "layers such as \"m07\".", call. = FALSE)
  }
  out <- character()
  for (t in type) {
    if (t == "monthly") {
      out <- c(out, months)
    } else if (t %in% c("season", "annual", months)) {
      out <- c(out, t)
    } else {
      stop(sprintf(paste0("Unknown `type` \"%s\": use \"season\", ",
                          "\"annual\", \"monthly\" or \"m01\" to \"m12\"."),
                   t), call. = FALSE)
    }
  }
  unique(out)
}

panel_layout <- function(n, nrow, ncol) {
  for (a in list(nrow, ncol)) {
    if (!is.null(a) && (length(a) != 1L || !is.numeric(a) || a < 1)) {
      stop("`nrow` and `ncol` must be positive whole numbers.", call. = FALSE)
    }
  }
  if (is.null(nrow) && is.null(ncol)) {
    ncol <- ceiling(sqrt(n))
    nrow <- ceiling(n / ncol)
  } else if (is.null(nrow)) {
    nrow <- ceiling(n / ncol)
  } else if (is.null(ncol)) {
    ncol <- ceiling(n / nrow)
  } else if (nrow * ncol < n) {
    warning(sprintf("%d panels do not fit in %d x %d; extra panels start a ",
                    n, nrow, ncol), "new page.", call. = FALSE)
  }
  as.integer(c(nrow, ncol))
}

index_palette <- function(key, col, n = 50) {
  if (is.function(col)) return(col(n))
  if (!is.null(col)) return(col)
  pal <- switch(sub("_.*", "", key), gdd = "YlOrRd", ch = "Blues",
                cu = "Purples", cp = "Greens", "viridis")
  grDevices::hcl.colors(n, pal, rev = pal != "viridis")
}

layer_label <- function(layer) {
  out <- layer
  m <- layer %in% sprintf("m%02d", 1:12)
  out[m] <- month.abb[as.integer(sub("m", "", layer[m]))]
  out
}

# Period or month and units only, for example "Jul [portions]" or
# "1 May - 31 Aug [portions]".
short_title <- function(key, layer, config = NULL) {
  period <- if (layer == "season") {
    p <- if (startsWith(key, "gdd_")) config$heat_period else
      config$chill_period
    if (is.null(p)) "season" else format_period(p)
  } else {
    layer_label(layer)
  }
  sprintf("%s [%s]", period, index_units(key))
}

panel_title <- function(key, layer, config = NULL) {
  label <- index_label(key)
  period <- if (layer == "season") {
    p <- if (startsWith(key, "gdd_")) config$heat_period else
      config$chill_period
    if (is.null(p)) "season" else format_period(p)
  } else if (layer == "annual") {
    "annual"
  } else {
    month.abb[as.integer(sub("m", "", layer))]
  }
  sprintf("%s, %s [%s]", label, period, index_units(key))
}

index_label <- function(key) {
  if (startsWith(key, "gdd_")) {
    base <- sub(".*_b", "", key)
    method <- gsub("_", " ", sub("^gdd_(.*)_b[^_]*$", "\\1", key))
    return(sprintf("GDD %s, base %s", method, base))
  }
  switch(key,
         ch_sine = "Chilling hours (sine)",
         ch_triangle = "Chilling hours (triangle)",
         ch_hourly = "Chilling hours (hourly)",
         cu_utah = "Utah chill units",
         cp_dynamic = "Chill portions (Dynamic)",
         key)
}

format_period <- function(p) {
  m <- as.integer(substr(p, 1, 2))
  paste(as.integer(substr(p, 4, 5)), month.abb[m], collapse = " - ")
}
