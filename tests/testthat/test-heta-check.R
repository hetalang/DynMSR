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
