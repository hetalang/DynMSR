test_that("dynms_validate_schema validates a DynMS file", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")

  expect_true(dynms_validate_schema(path))
})

test_that("dynms_validate_schema validates a raw DynMS object", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")
  raw_platform <- dynms_read(path)

  expect_true(dynms_validate_schema(raw_platform))
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

  valid <- vapply(paths, dynms_validate_schema, logical(1))

  expect_true(all(valid))
})

test_that("dynms_validate_schema rejects structurally invalid input", {
  invalid <- list(format = "DynMS")

  expect_false(dynms_validate_schema(invalid))
})
