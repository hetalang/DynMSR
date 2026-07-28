test_that("rename_model_identifiers updates definitions and references", {
  expression <- function(expr) list(expr = expr, format = "math-json")
  model <- list(
    id = "model",
    constants = list(list(id = "k", value = 1)),
    dynamic = list(list(
      id = "A",
      initial = expression("k"),
      derivative = expression(list("Add", list(sym = "k"), "A", "t"))
    )),
    static = list(list(id = "V", initial = expression("k"))),
    assignments = list(list(
      id = "rate",
      rhs = expression(list(fn = list("Multiply", "k", "A")))
    )),
    timeEvents = list(list(
      id = "dose",
      trigger = list(
        type = "time",
        start = expression("k"),
        period = expression("k"),
        stop = expression("k")
      ),
      actions = list(list(state = "A", rhs = expression("rate")))
    )),
    events = list(list(
      id = "limit",
      trigger = list(
        type = "conditional",
        rhs = expression(list("Greater", "A", "rate"))
      ),
      actions = list(list(state = "V", rhs = expression("A")))
    )),
    observables = list(list(symbol = "rate"))
  )
  original <- model
  identifier_map <- c(
    k = "k2",
    A = "A2",
    V = "V2",
    rate = "rate2",
    dose = "dose2",
    limit = "limit2"
  )

  renamed <- rename_model_identifiers(model, identifier_map)

  expect_identical(model, original)
  expect_identical(renamed$constants[[1]]$id, "k2")
  expect_identical(renamed$dynamic[[1]]$id, "A2")
  expect_identical(
    renamed$dynamic[[1]]$derivative$expr,
    list("Add", list(sym = "k2"), "A2", "t")
  )
  expect_identical(
    renamed$assignments[[1]]$rhs$expr,
    list(fn = list("Multiply", "k2", "A2"))
  )
  expect_identical(renamed$timeEvents[[1]]$id, "dose2")
  expect_identical(renamed$timeEvents[[1]]$trigger$period$expr, "k2")
  expect_identical(renamed$timeEvents[[1]]$actions[[1]]$state, "A2")
  expect_identical(renamed$timeEvents[[1]]$actions[[1]]$rhs$expr, "rate2")
  expect_identical(renamed$events[[1]]$id, "limit2")
  expect_identical(renamed$events[[1]]$actions[[1]]$state, "V2")
  expect_identical(renamed$observables[[1]]$symbol, "rate2")
})

test_that("rename_model_identifiers validates mappings", {
  model <- minimal_raw_model()
  model$constants <- list(list(id = "k", value = 1))
  model$dynamic <- list(list(
    id = "A",
    initial = 1,
    derivative = list(expr = 0, format = "math-json")
  ))

  expect_error(
    rename_model_identifiers(model, c(k = "A")),
    "creates collisions"
  )
  expect_error(
    rename_model_identifiers(model, c(t = "time")),
    "time symbol `t`"
  )
  expect_error(
    rename_model_identifiers(model, c(k = "t")),
    "time symbol `t`"
  )
  expect_error(
    rename_model_identifiers(model, c(missing = "renamed")),
    "Unknown identifiers"
  )
})
