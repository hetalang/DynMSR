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
