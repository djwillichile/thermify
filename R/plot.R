#' Plot and print the maps produced by thermify_rast()
#'
#' `plot()` draws the index maps returned by [thermify_rast()], one panel per
#' index and layer, with titles, units and a colour palette per index family.
#' `print()` summarises the object.
#'
#' @param x An object returned by [thermify_rast()].
#' @param variable Indices to plot: full keys such as `"cp_dynamic"` or
#'   `"gdd_single_sine_b10"`, or families `"gdd"`, `"ch"`, `"cu"`, `"cp"`.
#'   `NULL` (default) plots every index.
#' @param type Layer to plot: `"season"` (default), `"annual"`, `"monthly"`
#'   (the 12 monthly layers), or one or more month layers such as `"m07"`.
#'   Utah units and chill portions have no `"annual"` layer; they are skipped
#'   with a message.
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
#' @param ... Further arguments passed to [terra::plot()]. With three or more
#'   columns the titles are reduced (`cex.main` 0.85 or 0.75) unless
#'   `cex.main` is given.
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
#' @name plot.thermify_rast
#' @export
plot.thermify_rast <- function(x, variable = NULL, type = "season",
                               nrow = NULL, ncol = NULL, col = NULL,
                               boundary = NULL,
                               range = c("variable", "panel"), ...) {
  range <- match.arg(range)
  keys <- select_keys(names(x), variable)
  layers <- select_layers(type)
  if (!is.null(boundary) && !inherits(boundary, "SpatVector")) {
    stop("`boundary` must be a SpatVector.", call. = FALSE)
  }

  panels <- list()
  skipped <- character()
  for (k in keys) {
    available <- intersect(layers, names(x[[k]]))
    if (length(available) == 0L) {
      skipped <- c(skipped, k)
      next
    }
    for (l in available) panels[[length(panels) + 1L]] <- c(key = k, layer = l)
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
  if (length(panels) > 1L) {
    op <- graphics::par(mfrow = layout)
    on.exit(graphics::par(op), add = TRUE)
  }
  if (!is.null(boundary)) {
    boundary <- terra::project(boundary, terra::crs(x[[keys[1]]]))
  }
  config <- attr(x, "provenance")$config
  scales <- list()
  for (p in panels) {
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
    args <- list(r, col = pal, main = panel_title(k, p[["layer"]], config))
    if (!is.null(zlim) && all(is.finite(zlim)) && diff(zlim) > 0) {
      args$range <- zlim
    }
    dots <- list(...)
    if (is.null(dots$cex.main) && layout[2] >= 3L) {
      # Smaller titles so that they fit in narrow panels.
      dots$cex.main <- if (layout[2] == 3L) 0.85 else 0.75
    }
    do.call(draw_panel, c(args, dots))
    if (!is.null(boundary)) terra::lines(boundary)
  }
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
