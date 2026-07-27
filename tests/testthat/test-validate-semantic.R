test_that("dynms_validate_semantic succeeds for all indexed valid examples", {
  paths <- indexed_example_paths()

  results <- lapply(paths, function(path) {
    raw <- dynms_read(path)
    dynms_validate_semantic(raw)
  })

  expect_true(all(vapply(results, `[[`, logical(1), "valid")))
  expect_true(all(vapply(results, function(result) length(result$errors) == 0L, logical(1))))
  expect_true(all(vapply(results, function(result) length(result$warnings) == 0L, logical(1))))
})

test_that("dynms_validate_semantic reports messages for all indexed semantic error examples", {
  paths <- indexed_example_paths("semanticErrorsExamples")

  results <- lapply(paths, function(path) {
    raw <- dynms_read(path)
    expect_true(dynms_validate_schema(raw)$valid)
    dynms_validate_semantic(raw)
  })

  expect_true(all(!vapply(results, `[[`, logical(1), "valid")))
  expect_true(all(vapply(results, function(result) length(result$errors) > 0L, logical(1))))
  expect_true(all(vapply(
    results,
    function(result) all(nzchar(vapply(result$errors, `[[`, character(1), "message"))),
    logical(1)
  )))
})

test_that("dynms_validate_semantic aggregates errors and can raise them", {
  raw <- minimal_raw_platform()
  raw$models[[1]]$constants <- list(
    list(id = "k", value = 1),
    list(id = "k", value = 2)
  )
  raw$models[[1]]$dynamic <- list(
    list(id = "A", initial = 1, derivative = list(expr = 0, format = "math-json")),
    list(id = "A", initial = 2, derivative = list(expr = 0, format = "math-json"))
  )

  result <- dynms_validate_semantic(raw)

  expect_false(result$valid)
  expect_length(result$errors, 2L)
  expect_error(
    dynms_validate_semantic(raw, error = TRUE),
    "DynMS semantic validation failed"
  )
})

test_that("dynms_validate_semantic checks duplicate identifiers in every collection", {
  expression <- list(expr = 0, format = "math-json")
  duplicate_components <- list(
    dynamic = list(
      list(id = "A", initial = 1, derivative = expression),
      list(id = "A", initial = 2, derivative = expression)
    ),
    static = list(list(id = "V", initial = 1), list(id = "V", initial = 2)),
    constants = list(list(id = "k", value = 1), list(id = "k", value = 2)),
    assignments = list(
      list(id = "rate", rhs = expression),
      list(id = "rate", rhs = expression)
    ),
    timeEvents = list(
      list(id = "dose", trigger = list(type = "time", start = 0), actions = list()),
      list(id = "dose", trigger = list(type = "time", start = 1), actions = list())
    ),
    events = list(
      list(
        id = "switch",
        trigger = list(type = "conditional", rhs = expression),
        actions = list()
      ),
      list(
        id = "switch",
        trigger = list(type = "conditional", rhs = expression),
        actions = list()
      )
    )
  )

  for (field in names(duplicate_components)) {
    raw <- minimal_raw_platform()
    raw$models[[1]][[field]] <- duplicate_components[[field]]
    result <- dynms_validate_semantic(raw)

    expect_true(dynms_validate_schema(raw)$valid, info = field)
    expect_false(result$valid, info = field)
    expect_equal(result$errors[[1]]$code, "duplicate_identifier", info = field)
  }
})

test_that("dynms_validate_semantic permits repeated observable references", {
  raw <- minimal_raw_platform()
  raw$models[[1]]$dynamic <- list(list(
    id = "A", initial = 1, derivative = list(expr = 0, format = "math-json")
  ))
  raw$models[[1]]$observables <- list(list(symbol = "A"), list(symbol = "A"))

  expect_true(dynms_validate_semantic(raw)$valid)
})

test_that("dynms_validate_semantic resolves canonical and compatible MathJSON symbols", {
  raw <- minimal_raw_platform()
  raw$models[[1]]$constants <- list(list(id = "k", value = 1))
  raw$models[[1]]$dynamic <- list(list(
    id = "A",
    initial = 1,
    derivative = list(
      expr = list("Add", list(sym = "k"), "Pi"),
      format = "math-json"
    )
  ))

  expect_true(dynms_validate_semantic(raw)$valid)
})

test_that("dynms_validate_semantic rejects duplicate state ids across dynamic and static", {
  raw <- list(
    dynms = "0.2.0",
    models = list(
      list(
        id = "model",
        constants = list(),
        dynamic = list(list(
          id = "A",
          initial = 1,
          derivative = list(expr = 0, format = "math-json")
        )),
        static = list(list(id = "A", initial = 2)),
        assignments = list(),
        timeEvents = list(),
        events = list(),
        observables = list()
      )
    )
  )

  result <- dynms_validate_semantic(raw)
  messages <- vapply(result$errors, `[[`, character(1), "message")

  expect_false(result$valid)
  expect_true(any(grepl(
    "Duplicate state identifier across `dynamic` and `static`: A",
    messages,
    fixed = TRUE
  )))
})

test_that("dynms_validate_semantic rejects duplicate event ids across timeEvents and events", {
  raw <- list(
    dynms = "0.2.0",
    models = list(
      list(
        id = "model",
        constants = list(),
        dynamic = list(),
        static = list(),
        assignments = list(),
        timeEvents = list(list(
          id = "sw",
          trigger = list(type = "time", start = 0),
          actions = list()
        )),
        events = list(list(
          id = "sw",
          trigger = list(
            type = "conditional",
            rhs = list(expr = 1, format = "math-json")
          ),
          actions = list()
        )),
        observables = list()
      )
    )
  )

  result <- dynms_validate_semantic(raw)
  messages <- vapply(result$errors, `[[`, character(1), "message")

  expect_false(result$valid)
  expect_true(any(grepl(
    "Duplicate event identifier across `timeEvents` and `events`: sw",
    messages,
    fixed = TRUE
  )))
})

test_that("dynms_validate_semantic checks references and initialization contexts", {
  expression <- function(expr) list(expr = expr, format = "math-json")
  raw <- minimal_raw_platform()
  raw$models[[1]]$constants <- list(list(id = "k", value = expression("missing")))
  raw$models[[1]]$dynamic <- list(list(
    id = "A", initial = expression("A"), derivative = expression("missing")
  ))
  raw$models[[1]]$static <- list(list(id = "V", initial = expression("t")))
  raw$models[[1]]$assignments <- list(
    list(id = "first", rhs = expression("second")),
    list(id = "second", rhs = expression("A"))
  )
  raw$models[[1]]$timeEvents <- list(list(
    id = "dose",
    trigger = list(type = "time", start = expression("A")),
    actions = list(
      list(state = "k", rhs = expression("missing")),
      list(state = "k", rhs = expression(0))
    )
  ))
  raw$models[[1]]$events <- list(list(
    id = "limit",
    trigger = list(type = "conditional", rhs = expression("missing")),
    actions = list()
  ))
  raw$models[[1]]$observables <- list(list(symbol = "k"))

  codes <- vapply(dynms_validate_semantic(raw)$errors, `[[`, character(1), "code")

  expect_true(all(c(
    "unknown_symbol", "assignment_order", "invalid_action_state",
    "duplicate_action_state", "invalid_observable"
  ) %in% codes))
})

test_that("dynms_validate_semantic checks identifiers across all collections", {
  raw <- minimal_raw_platform()
  raw$models[[1]]$constants <- list(list(id = "shared", value = 1))
  raw$models[[1]]$assignments <- list(list(
    id = "shared", rhs = list(expr = 1, format = "math-json")
  ))

  result <- dynms_validate_semantic(raw)

  expect_false(result$valid)
  expect_equal(result$errors[[1]]$code, "duplicate_identifier")
})
