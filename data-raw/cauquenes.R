# Builds data/cauquenes.rda from the official 2023 Political and
# Administrative Division of Chile (DPA 2023).
#
# Source: SUBDERE, Unidad de Investigacion Territorial (2023). Division
# Politico Administrativa 2023, file DivisionPoliticoAdministrativa2023
# (shapefile, SIRGAS-Chile 2002 geographic, EPSG:5360, scale 1:50,000),
# published 3 August 2023 through IDE Chile. Built by the IDE Chile DPA
# working group (SUBDERE, IGM, DIFROL, INE) from SUBDERE interior limits
# v0702, DIFROL international limit v4 and IGM coastline v3.
# Circulation authorised by DIFROL Resolucion No 87 of 2023.
#
# `cauquenes` is a packed terra SpatVector (terra::wrap) with two features:
#   nivel = "comuna"     Cauquenes commune   (CUT_COM  = "07201", ~2,124.5 km2)
#   nivel = "provincia"  Cauquenes province  (CUT_PROV = "072",   ~3,021.7 km2)
# in SIRGAS-Chile 2002 (EPSG:5360), with original geometry (not simplified).
#
# The national DPA 2023 layers are large and are not distributed with the
# package. Point the two variables below to local copies of the DPA 2023
# commune and province layers (shapefile, GeoPackage or file geodatabase)
# and run this script from the package root:
#   DPA_COMUNAS=... DPA_PROVINCIAS=... Rscript data-raw/cauquenes.R

library(terra)

comunas <- vect(Sys.getenv("DPA_COMUNAS"))
provincias <- vect(Sys.getenv("DPA_PROVINCIAS"))

comuna <- comunas[comunas$CUT_COM == "07201", ]
provincia <- provincias[provincias$CUT_PROV == "072", ]
stopifnot(nrow(comuna) == 1, nrow(provincia) == 1,
          all(is.valid(comuna)), all(is.valid(provincia)))

comuna$nivel <- "comuna"
provincia$nivel <- "provincia"
cq <- rbind(comuna, provincia)
cq <- cq[, c("nivel", "CUT_REG", "CUT_PROV", "CUT_COM", "REGION",
             "PROVINCIA", "COMUNA", "SUPERFICIE")]

# Checks against the SUPERFICIE attribute (km2) of the DPA layers
print(cbind(computed = expanse(cq, unit = "km"), dpa = cq$SUPERFICIE))

cauquenes <- wrap(cq)
save(cauquenes, file = "data/cauquenes.rda", compress = "xz")
