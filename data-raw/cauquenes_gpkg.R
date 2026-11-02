# Builds inst/extdata/cauquenes.gpkg from the official 2023 Political and
# Administrative Division of Chile (DPA 2023).
#
# Layers (SIRGAS-Chile 2002, EPSG:5360, original geometry, not simplified):
#   comuna     Cauquenes commune   (CUT_COM  = "07201", about 2,124.5 km2)
#   provincia  Cauquenes province  (CUT_PROV = "072",   about 3,021.7 km2)
#
# The national DPA 2023 layers are large and are not distributed with the
# package. Point the two variables below to local copies of the DPA 2023
# commune and province layers (shapefile, GeoPackage or file geodatabase)
# and run this script from the package root:
#   DPA_COMUNAS=... DPA_PROVINCIAS=... Rscript data-raw/cauquenes_gpkg.R

library(terra)

comunas <- vect(Sys.getenv("DPA_COMUNAS"))
provincias <- vect(Sys.getenv("DPA_PROVINCIAS"))

comuna <- comunas[comunas$CUT_COM == "07201", ]
provincia <- provincias[provincias$CUT_PROV == "072", ]
stopifnot(nrow(comuna) == 1, nrow(provincia) == 1,
          all(is.valid(comuna)), all(is.valid(provincia)))

out <- "inst/extdata/cauquenes.gpkg"
unlink(out)
writeVector(comuna, out, layer = "comuna", filetype = "GPKG")
writeVector(provincia, out, layer = "provincia", filetype = "GPKG",
            insert = TRUE)

# Checks against the SUPERFICIE attribute (km2) of the DPA layers
print(cbind(computed = c(expanse(comuna, unit = "km"),
                         expanse(provincia, unit = "km")),
            dpa = c(comuna$SUPERFICIE, provincia$SUPERFICIE)))
