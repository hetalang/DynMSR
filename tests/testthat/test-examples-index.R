test_that("examples index lists existing example files", {
  index_path <- system.file("examples", "index.json", package = "DynMSR")
  index <- jsonlite::fromJSON(index_path, simplifyVector = FALSE)

  expect_equal(index$contentType, "platform")
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
})
