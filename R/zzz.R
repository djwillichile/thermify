# Package state.
the <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  defaults <- list(
    thermify.tempify_auto = tempify_auto_default(),
    thermify.tempify_requirement =
      Sys.getenv("THERMIFY_TEMPIFY_REQUIREMENT", tempify_default_requirement())
  )
  set <- !names(defaults) %in% names(options())
  if (any(set)) options(defaults[set])
  the$tempify_route <- tryCatch(setup_tempify(), error = function(e) "none")
  invisible()
}
