test_that("examples index lists existing example files", {
  index_path <- system.file("examples", "index.json", package = "DynMSR")
  index <- jsonlite::fromJSON(index_path, simplifyVector = FALSE)

  expect_true(length(index$examples) > 0L)

  paths <- vapply(
    index$examples,
    function(example) {
      system.file(index$locationBase, example$file, package = "DynMSR")
    },
    character(1)
  )

  expect_true(all(nzchar(paths)))
  expect_true(all(file.exists(paths)))

  validation_error_paths <- vapply(
    index$validationErrorsExamples,
    function(example) {
      system.file(index$locationBase, example$file, package = "DynMSR")
    },
    character(1)
  )

  expect_true(all(nzchar(validation_error_paths)))
  expect_true(all(file.exists(validation_error_paths)))
})
