test_that("dynms_read reads DynMS JSON without simplifying vectors", {
  path <- indexed_example_paths()[[1]]

  platform <- dynms_read(path)

  expect_type(platform, "list")
  expect_type(platform$models, "list")
})

test_that("dynms_read rejects a non-path input", {
  expect_error(dynms_read(list()), "`path` must be a single file path.")
  expect_error(dynms_read(c("one.json", "two.json")), "`path` must be a single file path.")
})

test_that("dynms_read reports a missing file", {
  path <- file.path(
    system.file("examples", package = "DynMSR"),
    "missing-file.json"
  )

  expect_error(dynms_read(path), "DynMS file does not exist")
})

test_that("dynms_read reports an empty JSON file", {
  path <- system.file("examples", "empty-json.json", package = "DynMSR")

  expect_error(dynms_read(path))
})

test_that("dynms_read reports malformed JSON", {
  path <- system.file("examples", "malformed-json.json", package = "DynMSR")

  expect_error(dynms_read(path))
})
