#!/bin/bash
# Setup script for the thermify cloud environment.
#
# Installs R, the R packages used by thermify (development, tests,
# documentation and the Cauquenes case study) and a Python virtual
# environment with tempify. Runs once at the start of each new session.
#
# Paste it into: Environment settings > Setup script. Then add this
# environment variable (setup scripts cannot set it for the session):
#   RETICULATE_PYTHON=/root/.virtualenvs/thermify/bin/python
#
# Optional steps never make the script fail: if tempify cannot be
# installed, thermify still works with its native engine.

set -u
export DEBIAN_FRONTEND=noninteractive
log() { echo "[thermify-setup] $*"; }

log "Installing R and R packages (Ubuntu repositories)"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  r-base r-base-dev pandoc \
  r-cran-terra r-cran-ncdf4 \
  r-cran-testthat r-cran-withr r-cran-devtools r-cran-roxygen2 \
  r-cran-rcmdcheck r-cran-usethis r-cran-pkgdown r-cran-knitr \
  r-cran-rmarkdown r-cran-bench r-cran-reticulate r-cran-jsonlite \
  r-cran-rsvg r-cran-crayon r-cran-zoo r-cran-magrittr \
  || { log "ERROR: apt-get install failed"; exit 1; }

# chillR is not installed here: one of its dependencies (GenSA) fails to
# compile with the Ubuntu R toolchain. The cross-check script reads it from a
# source checkout instead (see inst/verification/verify_references.R).
log "Installing optional CRAN packages (geodata)"
Rscript -e 'for (p in c("geodata")) if (!requireNamespace(p, quietly = TRUE)) try(install.packages(p, repos = "https://cloud.r-project.org", Ncpus = 4, quiet = TRUE))' \
  || log "WARNING: optional CRAN packages not installed"

log "Creating Python environment with tempify"
VENV=/root/.virtualenvs/thermify
python3 -m venv "$VENV" \
  && "$VENV/bin/pip" install -q --upgrade pip \
  && "$VENV/bin/pip" install -q "git+https://github.com/djwillichile/tempify" \
  || log "WARNING: tempify not installed; thermify will use its native engine"

log "Versions"
R --version | head -1
"$VENV/bin/python" -c "import tempify; print('tempify', tempify.__version__)" 2>/dev/null \
  || log "tempify not available"
log "Done"
