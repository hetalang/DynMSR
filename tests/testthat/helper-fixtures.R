minimal_raw_model <- function() {
  list(
    id = "model",
    constants = list(),
    dynamic = list(),
    static = list(),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )
}

minimal_raw_platform <- function() {
  list(
    dynms = "0.2.1",
    models = list(minimal_raw_model())
  )
}

write_test_json <- function(object) {
  path <- tempfile(fileext = ".json")
  jsonlite::write_json(object, path, auto_unbox = TRUE)
  path
}
