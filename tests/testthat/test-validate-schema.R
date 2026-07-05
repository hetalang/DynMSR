test_that("dynms_validate_schema validates all indexed examples", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )

  paths <- vapply(
    index$examples,
    function(example) {
      system.file(index$locationBase, example$file, package = "DynMSR")
    },
    character(1)
  )

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
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )

  paths <- vapply(
    index$schemaErrorsExamples,
    function(example) {
      system.file(index$locationBase, example$file, package = "DynMSR")
    },
    character(1)
  )

  results <- lapply(paths, dynms_validate_schema)

  expect_true(all(!vapply(results, `[[`, logical(1), "valid")))
  expect_true(all(vapply(results, function(result) length(result$errors) > 0L, logical(1))))
  expect_true(all(vapply(
    results,
    function(result) all(nzchar(vapply(result$errors, `[[`, character(1), "message"))),
    logical(1)
  )))
})

