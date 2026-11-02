#' Administrative boundaries of Cauquenes (DPA 2023)
#'
#' Official boundaries of the Cauquenes commune and province (Maule Region,
#' Chile) from the 2023 Political and Administrative Division of Chile
#' (DPA 2023), used by the Cauquenes case study and the examples of
#' [worldclim_region()].
#'
#' The object is a packed `terra` vector (see [terra::wrap()]). Use
#' [cauquenes_boundary()] to get one level as a ready-to-use `SpatVector`, or
#' `vect(cauquenes)` for both. Geometry and attributes are those of the
#' DPA 2023 layers, not simplified.
#'
#' @format A `PackedSpatVector` with 2 polygons in SIRGAS-Chile 2002
#'   (EPSG:5360) and 8 attributes:
#' \describe{
#'   \item{nivel}{`"comuna"` (Cauquenes commune) or `"provincia"`
#'     (Cauquenes province).}
#'   \item{CUT_REG, CUT_PROV, CUT_COM}{Unique territorial codes of region
#'     (`"07"`), province (`"072"`) and commune (`"07201"`; `NA` for the
#'     province).}
#'   \item{REGION, PROVINCIA, COMUNA}{Names.}
#'   \item{SUPERFICIE}{Area in km2 as published (2,124.54 for the commune,
#'     3,021.67 for the province).}
#' }
#' @source División Político-Administrativa de Chile 2023 (DPA 2023), commune
#'   and province layers. Built with `data-raw/cauquenes.R`.
#' @seealso [cauquenes_boundary()]
#' @examples
#' cq <- vect(cauquenes)
#' cq
#' plot(cq, "nivel")
"cauquenes"

#' Cauquenes boundary at a given administrative level
#'
#' Returns the official DPA 2023 boundary of the Cauquenes commune or
#' province (Maule Region, Chile) from the [cauquenes] dataset, unpacked as a
#' `SpatVector` and optionally projected.
#'
#' @param level Administrative level: `"comuna"` (commune 07201) or
#'   `"provincia"` (province 072). The English names `"commune"` and
#'   `"province"` are also accepted. Several levels can be requested at once.
#' @param crs Optional coordinate reference system to project to, for example
#'   `"EPSG:4326"`. `NULL` (default) keeps SIRGAS-Chile 2002 (EPSG:5360).
#' @return A `SpatVector` of polygons with the attributes described in
#'   [cauquenes], in the order of `level`.
#' @seealso [cauquenes], [worldclim_region()]
#' @examples
#' comuna <- cauquenes_boundary("comuna")
#' expanse(comuna, unit = "km")
#'
#' provincia <- cauquenes_boundary("provincia", crs = "EPSG:4326")
#' ext(provincia)
#'
#' plot(cauquenes_boundary(c("provincia", "comuna")), "nivel")
#' @export
cauquenes_boundary <- function(level = "comuna", crs = NULL) {
  aliases <- c(comuna = "comuna", commune = "comuna",
               provincia = "provincia", province = "provincia")
  if (!is.character(level) || length(level) == 0L || anyNA(level)) {
    stop("`level` must be \"comuna\" and/or \"provincia\".", call. = FALSE)
  }
  key <- tolower(level)
  bad <- !key %in% names(aliases)
  if (any(bad)) {
    stop(sprintf("Unknown `level`: %s. Use \"comuna\" or \"provincia\".",
                 paste0("\"", level[bad], "\"", collapse = ", ")),
         call. = FALSE)
  }
  key <- unique(unname(aliases[key]))
  cq <- terra::vect(thermify::cauquenes)
  out <- cq[match(key, cq$nivel), ]
  if (!is.null(crs)) out <- terra::project(out, crs)
  out
}
