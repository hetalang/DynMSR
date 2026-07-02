test_that("dynms_validate_semantic returns a valid report", {
  raw <- list(
    models = list(
      list(
        id = "model",
        states = list(list(id = "A")),
        constants = list(list(id = "k")),
        assignments = list(),
        events = list(),
        observables = list(list(symbol = "A"))
      )
    )
  )

  result <- dynms_validate_semantic(raw)

  expect_true(result$valid)
  expect_equal(result$errors, list())
  expect_equal(result$warnings, list())
})

test_that("dynms_validate_semantic collects duplicate identifiers", {
  raw <- list(
    models = list(
      list(
        id = "model",
        states = list(list(id = "A"), list(id = "A")),
        constants = list(),
        assignments = list(),
        events = list(),
        observables = list(list(symbol = "C"), list(symbol = "C"))
      )
    )
  )

  result <- dynms_validate_semantic(raw)

  expect_false(result$valid)
  expect_length(result$errors, 2L)
  expect_equal(
    vapply(result$errors, `[[`, character(1), "code"),
    c("duplicate_identifier", "duplicate_identifier")
  )
  expect_match(result$errors[[1]]$message, "states")
  expect_match(result$errors[[2]]$message, "observables")
})

test_that("dynms_validate_semantic reports empty model lists", {
  raw <- list(models = list())

  result <- dynms_validate_semantic(raw)

  expect_false(result$valid)
  expect_length(result$errors, 1L)
  expect_equal(result$errors[[1]]$code, "empty_models")
})

test_that("dynms_validate_semantic can raise one error with all collected issues", {
  raw <- list(
    models = list(
      list(
        id = "model",
        states = list(list(id = "A"), list(id = "A")),
        constants = list(list(id = "k"), list(id = "k")),
        assignments = list(),
        events = list(),
        observables = list()
      )
    )
  )

  expect_error(
    dynms_validate_semantic(raw, error = TRUE),
    "DynMS semantic validation failed"
  )
})
