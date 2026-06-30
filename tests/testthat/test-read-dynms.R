test_that("dynms_read reads DynMS JSON without simplifying vectors", {
  path <- write_test_dynms_file()

  platform <- dynms_read(path)

  expect_type(platform, "list")
  expect_type(platform$models, "list")
  expect_equal(platform$models[[1]]$id, "one_compartment_decay")
})

test_that("dynms_read only reads raw DynMS JSON", {
  path <- write_test_dynms_file()

  platform <- dynms_read(path)

  expect_equal(class(platform), "list")
  expect_equal(platform$dynms, "0.1.0")
})
