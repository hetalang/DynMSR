test_that("examples index lists existing example files", {
  paths <- indexed_example_paths("examples")

  expect_true(length(paths) > 0L)
  expect_true(all(nzchar(paths)))
  expect_true(all(file.exists(paths)))

  validation_error_paths <- indexed_example_paths("schemaErrorsExamples")

  expect_true(all(nzchar(validation_error_paths)))
  expect_true(all(file.exists(validation_error_paths)))

  semantic_error_paths <- indexed_example_paths("semanticErrorsExamples")

  expect_true(all(nzchar(semantic_error_paths)))
  expect_true(all(file.exists(semantic_error_paths)))
})
