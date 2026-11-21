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
# Route A is opt-in: it downloads Python and tempify and writes a cache in
# the user's home, so it runs only when the user asks for it with
# options(thermify.tempify_auto = TRUE) or THERMIFY_TEMPIFY_AUTO=true before
# thermify is loaded. Route B needs an explicit call to install_tempify().
# Neither route runs when the user has already chosen a Python
# (RETICULATE_PYTHON, reticulate::use_*()) or when Python is already running.

# Whether the automatic setup is on: only when the environment variable
# THERMIFY_TEMPIFY_AUTO asks for it (the option, when set, takes precedence;
# see .onLoad()).
tempify_auto_default <- function(env = Sys.getenv("THERMIFY_TEMPIFY_AUTO")) {
  tolower(env) %in% c("true", "1", "yes")
}

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
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    return(invisible("no_reticulate"))
  }
  # A Python chosen by the user, or the persistent environment created by
  # install_tempify(), is always used: neither downloads anything.
  if (python_chosen_by_user() || python_initialized()) {
    return(invisible("user_python"))
  }
  env <- tempify_envname()
  if (isTRUE(tryCatch(reticulate::virtualenv_exists(env),
                      error = function(e) FALSE))) {
    reticulate::use_virtualenv(env, required = FALSE)
    return(invisible("virtualenv"))
  }
  # Only the automatic route downloads Python, so it needs the user's opt-in.
  if (!isTRUE(getOption("thermify.tempify_auto", FALSE))) {
    return(invisible("disabled"))
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
#' thermify never downloads Python or tempify unless you ask for it. There
#' are two ways to do so:
#'
#' * `install_tempify()` creates a named, persistent environment once;
#'   thermify uses it in every later session.
#' * The automatic route: with `reticulate` (>= 1.41), set
#'   `options(thermify.tempify_auto = TRUE)` or the environment variable
#'   `THERMIFY_TEMPIFY_AUTO=true` before loading thermify. thermify then
#'   declares tempify with `reticulate::py_require()`, and the first time the
#'   tempify engine is used reticulate builds and caches a Python environment
#'   with it (one or two minutes and about 100 MB, once).
#'
#' Both are skipped when you have already chosen a Python
#' (`RETICULATE_PYTHON`, `reticulate::use_python()` and similar), which is
#' used as is. Without tempify, thermify uses an equivalent native R engine;
#' the first time that happens in a session with `temporal = "auto"` (or
#' `engine = "auto"`), a note says how to install tempify. Hide it with
#' `options(thermify.tempify_hint = FALSE)`.
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

# Once per session, when temporal/engine = "auto" falls back to the native
# engine because tempify is not reachable, say that tempify is optional and
# how to install it. Never shown during checks or when the user opted out.
note_tempify_fallback <- function() {
  if (isTRUE(the$tempify_hint_shown) ||
      isFALSE(getOption("thermify.tempify_hint", TRUE)) ||
      nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_"))) {
    return(invisible())
  }
  the$tempify_hint_shown <- TRUE
  how <- if (requireNamespace("reticulate", quietly = TRUE)) {
    "run install_tempify() once, or set options(thermify.tempify_auto = TRUE) before loading thermify"
  } else {
    "install the 'reticulate' package and run install_tempify() once"
  }
  message("The optional tempify Python backend was not found, so the native ",
          "R engine is used (same results to within 1e-13 degC). To use tempify, ",
          how, ". Hide this note with options(thermify.tempify_hint = FALSE).")
  invisible()
}
