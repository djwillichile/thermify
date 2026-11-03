# Package state.
the <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  auto <- Sys.getenv("THERMIFY_TEMPIFY_AUTO")
  defaults <- list(
    thermify.tempify_auto = !tolower(auto) %in% c("false", "0", "no"),
    thermify.tempify_requirement =
      Sys.getenv("THERMIFY_TEMPIFY_REQUIREMENT", tempify_default_requirement())
  )
  set <- !names(defaults) %in% names(options())
  if (any(set)) options(defaults[set])
  the$tempify_route <- tryCatch(setup_tempify(), error = function(e) "none")
  invisible()
}
