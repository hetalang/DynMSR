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

test_that("dynms_load reports schema and semantic validation messages before failing", {
  path <- tempfile(fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  jsonlite::write_json(
    list(
      models = list(
        list(
          id = "model",
          constants = list(),
          states = list(
            list(id = "A", initial = 1),
            list(id = "A", initial = 2)
          ),
          assignments = list(),
          derivatives = list(),
          events = list(),
          observables = list()
        )
      )
    ),
    path,
    auto_unbox = TRUE
  )

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
  expect_true(any(grepl("Duplicate identifier in `states`: A", messages, fixed = TRUE)))
})
