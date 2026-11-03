# Automatic provisioning of the tempify Python backend.
#
# tempify is a Python package, so it cannot be an R dependency. Two routes
# make it available without manual configuration:
#
#  A. On load, thermify declares tempify with reticulate::py_require()
#     (reticulate >= 1.41). The first time Python is used in the session,
#     reticulate builds (and caches) an environment with tempify using uv.
#  B. install_tempify() creates a persistent virtual environment
#     "r-thermify"; when it exists, thermify uses it on load instead of A.
#
# Neither route runs when the user has already chosen a Python
# (RETICULATE_PYTHON, reticulate::use_*()), when Python is already running,
# or when the option thermify.tempify_auto is FALSE.

tempify_default_requirement <- function() {
  "tempify @ git+https://github.com/djwillichile/tempify"
}

tempify_requirement <- function() {
  req <- getOption("thermify.tempify_requirement")
  if (is.null(req) || !nzchar(req)) tempify_default_requirement() else req
}

tempify_envname <- function() {
  getOption("thermify.tempify_envname", "r-thermify")
}

reticulate_supports_require <- function() {
  requireNamespace("reticulate", quietly = TRUE) &&
    utils::packageVersion("reticulate") >= "1.41"
}

python_chosen_by_user <- function() {
  nzchar(Sys.getenv("RETICULATE_PYTHON")) ||
    nzchar(Sys.getenv("RETICULATE_PYTHON_ENV"))
}

python_initialized <- function() {
  requireNamespace("reticulate", quietly = TRUE) &&
    isTRUE(tryCatch(reticulate::py_available(initialize = FALSE),
                    error = function(e) FALSE))
}

# Called from .onLoad(). Returns the route taken, invisibly.
setup_tempify <- function() {
  if (!isTRUE(getOption("thermify.tempify_auto", TRUE))) {
    return(invisible("disabled"))
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    return(invisible("no_reticulate"))
  }
  if (python_chosen_by_user() || python_initialized()) {
    return(invisible("user_python"))
  }
  env <- tempify_envname()
  if (isTRUE(tryCatch(reticulate::virtualenv_exists(env),
                      error = function(e) FALSE))) {
    reticulate::use_virtualenv(env, required = FALSE)
    return(invisible("virtualenv"))
  }
  if (reticulate_supports_require()) {
    ok <- tryCatch({
      reticulate::py_require(tempify_requirement())
      TRUE
    }, error = function(e) FALSE)
    if (ok) {
      the$tempify_route <- "py_require"
      return(invisible("py_require"))
    }
  }
  invisible("none")
}

#' Install the tempify Python backend
#'
#' Creates (or updates) a persistent Python virtual environment with the
#' [tempify](https://github.com/djwillichile/tempify) package, which
#' thermify then uses automatically in every session.
#'
#' You rarely need this function. With `reticulate` (>= 1.41) installed,
#' thermify declares tempify when it is loaded, and the first time the
#' tempify engine is used reticulate builds and caches a Python environment
#' with it (this takes one or two minutes and downloads about 100 MB once).
#' `install_tempify()` is the alternative when that automatic route is not
#' available (older `reticulate`) or when you prefer a named, persistent
#' environment.
#'
#' The automatic setup is skipped when you have already chosen a Python
#' (`RETICULATE_PYTHON`, `reticulate::use_python()` and similar). Disable it
#' with `options(thermify.tempify_auto = FALSE)` before loading thermify, or
#' with the environment variable `THERMIFY_TEMPIFY_AUTO=false`.
#'
#' Installing from GitHub needs `git` on the system path.
#'
#' @param envname Name of the virtual environment.
#' @param requirement pip requirement for tempify. The default installs the
#'   current version from GitHub; a tag can be pinned, for example
#'   `"tempify @ git+https://github.com/djwillichile/tempify@v0.1.6"`.
#' @param python_version Python version used to create the environment when
#'   it does not exist, passed to [reticulate::virtualenv_starter()].
#' @param restart_message Print the instructions to restart R?
#' @return The path of the environment's Python, invisibly.
#' @seealso [tempify_available()], [tempify_version()]
#' @examples
#' \dontrun{
#' install_tempify()
#' # restart R, then
#' library(thermify)
#' tempify_available()
#' }
#' @export
install_tempify <- function(envname = tempify_envname(),
                            requirement = tempify_requirement(),
                            python_version = ">=3.10",
                            restart_message = TRUE) {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("install_tempify() needs the R package 'reticulate': ",
         "install.packages(\"reticulate\").", call. = FALSE)
  }
  if (startsWith(sub("^.*@ *", "", requirement), "git+") &&
      !nzchar(Sys.which("git"))) {
    stop("Installing tempify from GitHub needs git on the system path ",
         "(https://git-scm.com/downloads).", call. = FALSE)
  }
  if (!reticulate::virtualenv_exists(envname)) {
    starter <- reticulate::virtualenv_starter(python_version)
    if (is.null(starter)) {
      stop("No Python ", python_version, " found to create the ",
           "environment. Install one with reticulate::install_python().",
           call. = FALSE)
    }
    reticulate::virtualenv_create(envname, python = starter)
  }
  reticulate::virtualenv_install(envname, requirement, ignore_installed = TRUE)
  python <- reticulate::virtualenv_python(envname)
  if (restart_message) {
    message("tempify installed in the virtual environment '", envname,
            "'.\nRestart R; thermify will use it automatically.")
  }
  invisible(python)
}
