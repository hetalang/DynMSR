test_that("dynms_normalize returns a stable platform representation", {
  raw <- list(
    dynms = "0.1.0",
    models = list(
      list(
        id = "model",
        states = list(list(id = "A", initial = 1)),
        constants = list(list(id = "k", value = 0.1)),
        assignments = list(list(id = "calc", rhs = "k * A")),
        derivatives = list(list(state = "A", rhs = "-k * A")),
        events = list(list(id = "dose", trigger = list(type = "time", start = 0), actions = list())),
        observables = list(list(symbol = "A"))
      )
    )
  )

  platform <- dynms_normalize(raw)

  expect_type(platform, "list")
  expect_equal(class(platform), "list")
  expect_equal(platform$dynms, "0.1.0")
  expect_equal(platform$models[[1]]$id, "model")
  expect_named(platform$models[[1]]$constants, "k")
  expect_named(platform$models[[1]]$states, "A")
  expect_named(platform$models[[1]]$assignments, "calc")
  expect_named(platform$models[[1]]$derivatives, "A")
  expect_named(platform$models[[1]]$events, "dose")
  expect_named(platform$models[[1]]$observables, "A")
})

test_that("dynms_normalize leaves semantic duplicate checks to semantic validation", {
  raw <- list(
    models = list(
      list(
        id = "model",
        constants = list(),
        states = list(list(id = "A"), list(list(id = "A"))[[1]]),
        assignments = list(),
        derivatives = list(),
        events = list(),
        observables = list()
      )
    )
  )

  platform <- dynms_normalize(raw)

  expect_named(platform$models[[1]]$states, c("A", "A"))
})
