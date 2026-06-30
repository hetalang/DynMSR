test_that("dynms_normalize returns a stable platform representation", {
  raw <- list(
    dynms = "0.1.0",
    models = list(
      list(
        id = "model",
        states = list(list(id = "A", initial = 1)),
        constants = list(list(id = "k", value = 0.1)),
        observables = list(list(symbol = "A"))
      )
    )
  )

  platform <- dynms_normalize(raw)

  expect_type(platform, "list")
  expect_equal(class(platform), "list")
  expect_equal(platform$version, "0.1.0")
  expect_named(platform$models[[1]]$states, "A")
  expect_named(platform$models[[1]]$parameters, "k")
  expect_named(platform$models[[1]]$outputs, "A")
})

test_that("dynms_normalize reports duplicate identifiers", {
  raw <- list(
    models = list(
      list(
        id = "model",
        states = list(list(id = "A"), list(id = "A"))
      )
    )
  )

  expect_error(dynms_normalize(raw), "Duplicate identifiers")
})
