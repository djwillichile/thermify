#' Administrative boundaries of Cauquenes (DPA 2023)
#'
#' Official boundaries of the Cauquenes commune and province (Maule Region,
#' Chile) from the 2023 Political and Administrative Division of Chile
#' (DPA 2023), used by the Cauquenes case study and the examples of
#' [worldclim_region()].
#'
#' The object is a packed `terra` vector (see [terra::wrap()]): convert it
#' with `terra::vect(cauquenes)` before use. Geometry and attributes are those
#' of the DPA 2023 layers, not simplified.
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
#' @examples
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   cq <- terra::vect(cauquenes)
#'   comuna <- cq[cq$nivel == "comuna", ]
#'   terra::expanse(comuna, unit = "km")
#'   terra::plot(cq, "nivel")
#' }
"cauquenes"
