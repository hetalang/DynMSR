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

test_that("print.platform displays a compact model inventory", {
  platform <- new_platform(list(
    dynms = "0.2.0",
    platformId = "example-platform",
    models = list(list(
      id = "example-model",
      dynamic = list(list(id = "A")),
      static = list(),
      constants = list(list(id = "k")),
      assignments = list(),
      timeEvents = list(),
      events = list(),
      observables = list()
    ))
  ))

  output <- capture.output(result <- print(platform))

  expect_identical(result, platform)
  expect_equal(output, c(
    "<DynMS platform>",
    "  DynMS version: 0.2.0",
    "  Platform ID: example-platform",
    "  Models: 1",
    "    [1] example-model: 1 dynamic, 0 static, 1 constants, 0 assignments, 0 time events, 0 events, 0 observables"
  ))
})

test_that("print.model displays component identifiers and event types", {
  model <- new_model(list(
    id = "example-model",
    title = "Example model",
    dynamic = list(list(id = "A"), list(id = "B")),
    static = list(list(id = "V")),
    constants = list(list(id = "k")),
    assignments = list(list(id = "rate")),
    timeEvents = list(list(id = "dose")),
    events = list(
      list(id = "switch", trigger = list(type = "conditional")),
      list(id = "cross", trigger = list(type = "crossing"))
    ),
    observables = list(list(symbol = "rate"))
  ))

  output <- capture.output(result <- print(model))

  expect_identical(result, model)
  expect_equal(output, c(
    "<DynMS model: example-model>",
    "  Title: Example model",
    "  Dynamic states (2): A, B",
    "  Static states (1): V",
    "  Constants (1): k",
    "  Assignments (1): rate",
    "  Time events (1): dose",
    "  Events (2): conditional 1, crossing 1",
    "  Observables (1): rate"
  ))
})
