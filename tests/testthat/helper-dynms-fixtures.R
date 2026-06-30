write_test_dynms_file <- function(path = tempfile(fileext = ".json")) {
  model <- list(
    dynms = "0.1.0",
    models = list(
      list(
        id = "one_compartment_decay",
        constants = list(
          list(id = "k", value = 0.1)
        ),
        states = list(
          list(id = "A", initial = 100)
        ),
        assignments = list(),
        derivatives = list(
          list(
            state = "A",
            rhs = list(expr = "-k * A", format = "c")
          )
        ),
        events = list(),
        observables = list(
          list(symbol = "A")
        )
      )
    )
  )

  jsonlite::write_json(model, path, auto_unbox = TRUE, null = "null", pretty = TRUE)
  path
}
