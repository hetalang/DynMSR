index <- jsonlite::fromJSON(
  system.file("examples", "index.json", package = "DynMSR"),
  simplifyVector = FALSE
)

test_that("dynms_read reads DynMS JSON without simplifying vectors", {
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")

  platform <- dynms_read(path)

  expect_type(platform, "list")
  expect_type(platform$models, "list")
})

test_that("dynms_read reports a missing file", {
  path <- file.path(
    system.file(index$locationBase, package = "DynMSR"),
    "missing-file.json"
  )

  expect_error(dynms_read(path), "DynMS file does not exist")
})

test_that("dynms_read reports an empty JSON file", {
  path <- system.file(index$locationBase, "empty-json.json", package = "DynMSR")

  expect_error(dynms_read(path))
})

test_that("dynms_read reports malformed JSON", {
  path <- system.file(index$locationBase, "malformed-json.json", package = "DynMSR")

  expect_error(dynms_read(path))
})

test_that("dynms_load reads, validates, and returns a platform", {
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")

  platform <- dynms_load(path)

  expect_type(platform, "list")
  expect_type(platform$models, "list")
  expect_gt(length(platform$models), 0L)
})
