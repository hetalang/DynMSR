test_that("dynms_validate_schema validates a DynMS file", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")

  result <- dynms_validate_schema(path)

  expect_true(result$valid)
  expect_equal(result$errors, list())
  expect_equal(result$warnings, list())
})

test_that("dynms_validate_schema validates a raw DynMS object", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")
  raw_platform <- dynms_read(path)

  expect_true(dynms_validate_schema(raw_platform)$valid)
})

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

test_that("dynms_validate_schema rejects structurally invalid input", {
  invalid <- list(format = "DynMS")

  result <- dynms_validate_schema(invalid)

  expect_false(result$valid)
  expect_true(length(result$errors) > 1L)
  expect_true(all(c("path", "code", "message", "schema_path") %in% names(result$errors[[1]])))
})

test_that("dynms_validate_schema can raise one error with all collected issues", {
  invalid <- list(format = "DynMS")

  expect_error(
    dynms_validate_schema(invalid, error = TRUE),
    "DynMS schema validation failed"
  )
})
