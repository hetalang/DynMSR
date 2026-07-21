test_that("dynms_load loads every indexed valid example into a platform", {
  platforms <- lapply(indexed_example_paths(), dynms_load)

  expect_true(all(vapply(platforms, inherits, logical(1), "platform")))
  expect_true(all(vapply(
    platforms,
    function(platform) all(vapply(platform$models, inherits, logical(1), "model")),
    logical(1)
  )))
})

test_that("dynms_load rejects every indexed schema-invalid example", {
  paths <- indexed_example_paths("schemaErrorsExamples")

  for (path in paths) {
    expect_message(
      expect_error(dynms_load(path), "DynMS load failed: validation found"),
      "DynMS schema validation failed"
    )
  }
})

test_that("dynms_load rejects every indexed semantic-invalid example", {
  paths <- indexed_example_paths("semanticErrorsExamples")

  for (path in paths) {
    expect_message(
      expect_error(dynms_load(path), "DynMS load failed: validation found"),
      "DynMS semantic validation failed"
    )
  }
})

test_that("dynms_load reports schema and semantic errors before failing", {
  raw <- minimal_raw_platform()
  raw$dynms <- NULL
  raw$models[[1]]$dynamic <- list(
    list(id = "A", initial = 1, derivative = list(expr = 0, format = "math-json")),
    list(id = "A", initial = 2, derivative = list(expr = 0, format = "math-json"))
  )
  path <- write_test_json(raw)
  on.exit(unlink(path), add = TRUE)

  messages <- character()
  withCallingHandlers(
    expect_error(dynms_load(path), "DynMS load failed: validation found"),
    message = function(message) {
      messages <<- c(messages, conditionMessage(message))
      invokeRestart("muffleMessage")
    }
  )

  expect_true(any(grepl("DynMS schema validation failed", messages, fixed = TRUE)))
  expect_true(any(grepl("DynMS semantic validation failed", messages, fixed = TRUE)))
  expect_true(any(grepl("Duplicate identifier in `dynamic`: A", messages, fixed = TRUE)))
})
