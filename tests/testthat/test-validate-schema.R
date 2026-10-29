test_that("dynms_validate_schema validates all indexed examples", {
  paths <- indexed_example_paths()

  valid <- vapply(
    paths,
    function(path) {
      dynms_validate_schema(path)$valid
    },
    logical(1)
  )

  expect_true(all(valid))
})

test_that("dynms_validate_schema selects the bundled schema by DynMS version", {
  for (version in c("0.2.1", "0.2.2")) {
    raw <- minimal_raw_platform()
    raw$dynms <- version
    path <- write_test_json(raw)

    expect_true(dynms_validate_schema(raw)$valid, info = version)
    expect_true(dynms_validate_schema(path)$valid, info = version)
    unlink(path)
  }
})

test_that("DynMS 0.2.2 schema supports scenarios", {
  raw <- minimal_raw_platform()
  raw$scenarios <- list(list(
    id = "baseline",
    model = "model",
    tspan = list(0, 10)
  ))

  expect_true(dynms_validate_schema(raw)$valid)

  raw$dynms <- "0.2.1"
  expect_false(dynms_validate_schema(raw)$valid)
})

test_that("dynms_validate_schema reports unsupported DynMS versions", {
  raw <- minimal_raw_platform()
  raw$dynms <- "0.2.999"

  result <- dynms_validate_schema(raw)
  expect_false(result$valid)
  expect_identical(result$errors[[1]]$path, "$.dynms")
  expect_match(result$errors[[1]]$message, "Unsupported DynMS version `0.2.999`", fixed = TRUE)
  expect_match(result$errors[[1]]$message, "0.2.1, 0.2.2", fixed = TRUE)
  expect_match(result$errors[[1]]$message, "Update DynMSR", fixed = TRUE)
  expect_match(result$errors[[1]]$message, "DynMS generator", fixed = TRUE)
  expect_error(dynms_validate_schema(raw, error = TRUE), "Unsupported DynMS version")
})

test_that("dynms_validate_schema reports messages for all indexed invalid examples", {
  paths <- indexed_example_paths("schemaErrorsExamples")

  results <- lapply(paths, dynms_validate_schema)

  expect_true(all(!vapply(results, `[[`, logical(1), "valid")))
  expect_true(all(vapply(results, function(result) length(result$errors) > 0L, logical(1))))
  expect_true(all(vapply(
    results,
    function(result) all(nzchar(vapply(result$errors, `[[`, character(1), "message"))),
    logical(1)
  )))
})

test_that("dynms_validate_schema accepts raw platforms and raises collected errors", {
  raw <- minimal_raw_platform()
  path <- write_test_json(raw)
  on.exit(unlink(path), add = TRUE)

  expect_true(dynms_validate_schema(raw)$valid)
  expect_equal(dynms_validate_schema(path), dynms_validate_schema(raw))

  raw$dynms <- NULL
  result <- dynms_validate_schema(raw)

  expect_false(result$valid)
  expect_gt(length(result$errors), 0L)
  expect_error(
    dynms_validate_schema(raw, error = TRUE),
    "DynMS schema validation failed"
  )
})

test_that("dynms_validate_schema rejects unsupported inputs", {
  expect_error(
    dynms_validate_schema("missing-file.json"),
    "`x` must be a DynMS file path or an R list."
  )
})

test_that("dynms_validate_schema requires numeric constant values", {
  raw <- minimal_raw_platform()
  raw$models[[1]]$constants <- list(list(
    id = "k",
    value = list(expr = 1, format = "math-json")
  ))

  expect_false(dynms_validate_schema(raw)$valid)
})

test_that("dynms_validate_schema reserves t for the time symbol", {
  raw <- minimal_raw_platform()
  raw$models[[1]]$constants <- list(list(id = "t", value = 1))

  expect_false(dynms_validate_schema(raw)$valid)
})
