# These tests check the decisions of the automatic setup without creating
# Python environments; the end-to-end provisioning runs in the CI job
# "tempify auto-install".

test_that("the default requirement installs tempify from GitHub", {
  expect_identical(tempify_default_requirement(),
                   "tempify @ git+https://github.com/djwillichile/tempify")
  withr::local_options(thermify.tempify_requirement = "tempify==0.1.6")
  expect_identical(tempify_requirement(), "tempify==0.1.6")
  withr::local_options(thermify.tempify_requirement = "")
  expect_identical(tempify_requirement(), tempify_default_requirement())
})

test_that("the setup can be disabled", {
  withr::local_options(thermify.tempify_auto = FALSE)
  expect_identical(setup_tempify(), "disabled")
})

test_that("a Python chosen by the user is respected", {
  skip_if_not_installed("reticulate")
  withr::local_options(thermify.tempify_auto = TRUE)
  withr::local_envvar(RETICULATE_PYTHON = "/usr/bin/python3")
  expect_identical(setup_tempify(), "user_python")
})

test_that("an existing r-thermify environment takes precedence", {
  skip_if_not_installed("reticulate")
  withr::local_options(thermify.tempify_auto = TRUE)
  withr::local_envvar(RETICULATE_PYTHON = "", RETICULATE_PYTHON_ENV = "")
  used <- NULL
  local_mocked_bindings(python_initialized = function() FALSE)
  local_mocked_bindings(
    virtualenv_exists = function(envname) TRUE,
    use_virtualenv = function(virtualenv, required = FALSE) used <<- virtualenv,
    py_require = function(...) stop("should not be called"),
    .package = "reticulate")
  expect_identical(setup_tempify(), "virtualenv")
  expect_identical(used, "r-thermify")
})

test_that("otherwise tempify is declared with py_require()", {
  skip_if_not_installed("reticulate", minimum_version = "1.41")
  withr::local_options(thermify.tempify_auto = TRUE,
                       thermify.tempify_requirement = "tempify==9.9")
  withr::local_envvar(RETICULATE_PYTHON = "", RETICULATE_PYTHON_ENV = "")
  required <- NULL
  local_mocked_bindings(python_initialized = function() FALSE)
  local_mocked_bindings(
    virtualenv_exists = function(envname) FALSE,
    py_require = function(packages, ...) required <<- packages,
    .package = "reticulate")
  old <- the$tempify_route
  withr::defer(the$tempify_route <- old)
  expect_identical(setup_tempify(), "py_require")
  expect_identical(required, "tempify==9.9")
  # A failing declaration is not fatal.
  local_mocked_bindings(py_require = function(...) stop("boom"),
                        .package = "reticulate")
  expect_identical(setup_tempify(), "none")
})

test_that("install_tempify() explains missing prerequisites", {
  skip_if_not_installed("reticulate")
  local_mocked_bindings(Sys.which = function(names) c(git = ""),
                        .package = "base")
  expect_error(install_tempify(), "needs git")
})

test_that("install_tempify() creates the environment and installs tempify", {
  skip_if_not_installed("reticulate")
  calls <- character()
  local_mocked_bindings(
    virtualenv_exists = function(envname) FALSE,
    virtualenv_starter = function(version) "/usr/bin/python3",
    virtualenv_create = function(envname, python) calls <<- c(calls, "create"),
    virtualenv_install = function(envname, packages, ...) {
      calls <<- c(calls, paste("install", packages))
    },
    virtualenv_python = function(envname) "/envs/r-thermify/bin/python",
    .package = "reticulate")
  py <- install_tempify(requirement = "tempify==0.1.6",
                        restart_message = FALSE)
  expect_identical(calls, c("create", "install tempify==0.1.6"))
  expect_identical(py, "/envs/r-thermify/bin/python")
  expect_message(install_tempify(requirement = "tempify==0.1.6"),
                 "Restart R")
})
