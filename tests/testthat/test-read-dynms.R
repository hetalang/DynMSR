test_that("dynms_read reads DynMS JSON without simplifying vectors", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")

  platform <- dynms_read(path)

  expect_type(platform, "list")
  expect_type(platform$models, "list")
  expect_type(platform$models[[1]]$id, "character")
})

test_that("dynms_read only reads raw DynMS JSON", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  path <- system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR")

  platform <- dynms_read(path)

  expect_equal(class(platform), "list")
  expect_type(platform$dynms, "character")
})
