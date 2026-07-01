test_that("schema source metadata points to the bundled schema target", {
  source_path <- system.file("schema", "dynms.schema.source.json", package = "DynMSR")
  source <- jsonlite::fromJSON(source_path, simplifyVector = FALSE)

  expect_type(source$source, "character")
  expect_true(nzchar(source$source))
  expect_equal(source$target, "inst/schema/dynms.schema.json")
  expect_true(file.exists(system.file("schema", "dynms.schema.json", package = "DynMSR")))
})
