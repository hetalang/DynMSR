test_that("dynms_validate_schema validates a DynMS file", {
  path <- write_test_dynms_file()

  expect_true(dynms_validate_schema(path))
})

test_that("dynms_validate_schema validates a raw DynMS object", {
  path <- write_test_dynms_file()
  raw_platform <- dynms_read(path)

  expect_true(dynms_validate_schema(raw_platform))
})

test_that("dynms_validate_schema rejects structurally invalid input", {
  invalid <- list(format = "DynMS")

  expect_false(dynms_validate_schema(invalid))
})
