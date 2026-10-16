test_that("heta_check reports a missing compiler with installation guidance", {
  testthat::local_mocked_bindings(
    heta_run_command = function(args) {
      stop("`heta` command was not found.", call. = FALSE)
    },
    .package = "DynMSR"
  )

  check <- heta_check()

  expect_false(check$available)
  expect_false(check$supported)
  expect_true(is.na(check$version))
  expect_match(check$message, "Heta compiler is not available.", fixed = TRUE)
  expect_match(
    check$message,
    "https://hetalang.github.io/hetacompiler/installation.html",
    fixed = TRUE
  )
})

test_that("heta_build validates its output directory", {
  testthat::local_mocked_bindings(
    heta_check = function() list(supported = TRUE),
    heta_run_command = function(args) character(),
    .package = "DynMSR"
  )

  expect_error(heta_build(), "`dir` must be a single non-empty directory path", fixed = TRUE)
  expect_error(
    heta_build("."),
    "`output_dir` must be a single non-empty directory path",
    fixed = TRUE
  )
  expect_error(
    heta_build(".", NULL),
    "`output_dir` must be a single non-empty directory path",
    fixed = TRUE
  )
  expect_error(
    DynMSR:::heta_output_dir(NULL),
    "`output_dir` must be a single non-empty directory path",
    fixed = TRUE
  )
  expect_error(
    heta_build(".", output_dir = "", export = "DynMS"),
    "`output_dir` must be a single non-empty directory path",
    fixed = TRUE
  )
  expect_error(
    heta_build(".", output_dir = NA_character_, export = "DynMS"),
    "`output_dir` must be a single non-empty directory path",
    fixed = TRUE
  )
})

test_that("heta_build puts all output under the requested directory", {
  testthat::local_mocked_bindings(
    heta_check = function() list(supported = TRUE),
    heta_run_command = function(args) {
      dist <- args[[match("--dist-dir", args) + 1L]]
      meta <- args[[match("--meta-dir", args) + 1L]]
      log <- args[[match("--log-path", args) + 1L]]
      dir.create(dist)
      dir.create(meta)
      writeLines("build output", log)
      character()
    },
    .package = "DynMSR"
  )

  output_dir <- tempfile("dynmsr-heta-test-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  result <- heta_build(".", output_dir, export = "DynMS")
  option_value <- function(option) result$args[[match(option, result$args) + 1L]]

  expect_identical(option_value("--dist-dir"), file.path(result$output_dir, "dist"))
  expect_identical(option_value("--meta-dir"), file.path(result$output_dir, "meta"))
  expect_identical(option_value("--log-path"), file.path(result$output_dir, "build.log"))
  expect_identical(basename(option_value("--log-path")), "build.log")
  expect_identical(result$output_dir, normalizePath(output_dir, winslash = "/"))
  expect_true(dir.exists(result$output_dir))
  expect_true(file.exists(option_value("--log-path")))
  expect_identical(tail(result$args, 1L), ".")
})

test_that("heta_build uses an explicit output directory", {
  testthat::local_mocked_bindings(
    heta_check = function() list(supported = TRUE),
    heta_run_command = function(args) character(),
    .package = "DynMSR"
  )

  output_dir <- tempfile("dynmsr-heta-test-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  result <- heta_build(".", output_dir = output_dir)
  normalized_dir <- normalizePath(output_dir, winslash = "/")
  expect_identical(result$output_dir, normalized_dir)
  expect_identical(result$args[match("--dist-dir", result$args) + 1L], file.path(normalized_dir, "dist"))
  expect_identical(result$args[match("--meta-dir", result$args) + 1L], file.path(normalized_dir, "meta"))
  expect_identical(result$args[match("--log-path", result$args) + 1L], file.path(normalized_dir, "build.log"))
  expect_true(dir.exists(output_dir))
})

test_that("heta_build resolves relative output paths before invoking Heta", {
  testthat::local_mocked_bindings(
    heta_check = function() list(supported = TRUE),
    heta_run_command = function(args) character(),
    .package = "DynMSR"
  )

  project_dir <- tempfile("dynmsr-heta-test-")
  dir.create(project_dir)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  withr::local_dir(project_dir)

  result <- heta_build(".", output_dir = "results")
  expect_identical(result$output_dir, file.path(normalizePath(project_dir, winslash = "/"), "results"))
  expect_identical(result$args[match("--dist-dir", result$args) + 1L], file.path(result$output_dir, "dist"))
  expect_true(dir.exists(result$output_dir))
})

test_that("heta_build preserves requested output after a compiler error", {
  captured_dir <- NULL
  testthat::local_mocked_bindings(
    heta_check = function() list(supported = TRUE),
    heta_run_command = function(args) {
      captured_dir <<- dirname(args[[match("--log-path", args) + 1L]])
      writeLines("build failed", file.path(captured_dir, "build.log"))
      stop("Compiler failed.", call. = FALSE)
    },
    .package = "DynMSR"
  )

  output_dir <- tempfile("dynmsr-heta-test-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  expect_error(heta_build(".", output_dir), "Compiler failed.", fixed = TRUE)
  expect_true(dir.exists(captured_dir))
  expect_true(file.exists(file.path(captured_dir, "build.log")))
})

test_that("heta_load keeps compiler output paths temporary", {
  captured <- NULL
  testthat::local_mocked_bindings(
    heta_build = function(...) {
      captured <<- list(...)
      path <- file.path(captured$output_dir, "dist", "dynms", "output.dynms.json")
      dir.create(dirname(path), recursive = TRUE)
      file.create(path)
      invisible(NULL)
    },
    dynms_load = function(path) list(path = path),
    .package = "DynMSR"
  )

  expect_error(heta_load(), "`dir` must be a single non-empty directory path", fixed = TRUE)
  heta_load(".")

  expect_identical(dirname(captured$output_dir), normalizePath(tempdir(), winslash = "/"))
  expect_false(dir.exists(captured$output_dir))
})

test_that("heta_load preserves an explicitly requested output directory", {
  testthat::local_mocked_bindings(
    heta_build = function(output_dir, ...) {
      path <- file.path(output_dir, "dist", "dynms", "output.dynms.json")
      dir.create(dirname(path), recursive = TRUE)
      file.create(path)
      invisible(NULL)
    },
    dynms_load = function(path) list(path = path),
    .package = "DynMSR"
  )

  output_dir <- tempfile("dynmsr-heta-test-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  result <- heta_load(".", output_dir)
  expect_true(dir.exists(output_dir))
  expect_identical(result$path, file.path(normalizePath(output_dir, winslash = "/"), "dist", "dynms", "output.dynms.json"))
})

test_that("heta_load removes temporary output when building fails", {
  captured_dir <- NULL
  testthat::local_mocked_bindings(
    heta_build = function(output_dir, ...) {
      captured_dir <<- output_dir
      stop("Compiler failed.", call. = FALSE)
    },
    .package = "DynMSR"
  )

  expect_error(heta_load("."), "Compiler failed.", fixed = TRUE)
  expect_false(dir.exists(captured_dir))
})

test_that("sbml_load passes the shared output directory to heta_load", {
  captured <- NULL
  testthat::local_mocked_bindings(
    heta_load = function(...) {
      captured <<- list(...)
      list()
    },
    .package = "DynMSR"
  )

  sbml_path <- tempfile(fileext = ".xml")
  on.exit(unlink(sbml_path), add = TRUE)
  file.create(sbml_path)
  output_dir <- tempfile("dynmsr-sbml-test-")
  sbml_load(sbml_path, output_dir)
  expect_identical(captured$output_dir, output_dir)
})

test_that("heta_check finds the configured integration-test compiler", {
  skip_if_heta_integration_disabled()

  config <- heta_compiler_config()
  check <- heta_check()

  expect_true(check$available, info = check$message)
  expect_true(check$supported, info = check$message)
  expect_identical(check$version, config$testVersion, info = check$message)
  expect_identical(check$supported_version, config$supportedVersion)
  expect_identical(check$installation_url, config$installationUrl)
})
