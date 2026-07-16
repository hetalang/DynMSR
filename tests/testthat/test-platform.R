test_that("new_platform adds S3 classes to platform and models", {
  raw <- list(
    dynms = "0.2.0",
    models = list(
      list(id = "model_1"),
      list(id = "model_2")
    )
  )

  platform <- new_platform(raw)

  expect_s3_class(platform, "platform")
  expect_s3_class(platform$models[[1]], "model")
  expect_s3_class(platform$models[[2]], "model")
  expect_equal(platform$dynms, raw$dynms)
  expect_equal(platform$models[[1]]$id, "model_1")
})

test_that("new_platform validates platform and model inputs lightly", {
  expect_error(new_platform("not a platform"), "`raw_platform` must be a DynMS platform")
  expect_error(new_platform(list(models = list("not a model"))), "Each platform model")
})
