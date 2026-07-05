#' Normalize a DynMS object
#'
#' Converts raw DynMS content into a stable internal representation used by
#' backend exporters while preserving the DynMS document structure.
#'
#' @param x An R list representing a DynMS object.
#'
#' @return An R list with normalized DynMS platform content.
#' @export
dynms_normalize <- function(x) {
  if (!is.list(x)) {
    stop("`x` must be a DynMS object represented as an R list.", call. = FALSE)
  }

  normalized <- x
  normalized$models <- lapply(x$models, normalize_model)
  normalized
}

normalize_model <- function(model) {
  normalized <- model
  normalized$constants <- normalize_named_collection(model$constants %||% list(), "constants", "id")
  normalized$states <- normalize_named_collection(model$states %||% list(), "states", "id")
  normalized$assignments <- normalize_named_collection(model$assignments %||% list(), "assignments", "id")
  normalized$derivatives <- normalize_named_collection(model$derivatives %||% list(), "derivatives", "state")
  normalized$events <- normalize_named_collection(model$events %||% list(), "events", "id")
  normalized$observables <- normalize_named_collection(model$observables %||% list(), "observables", "symbol")
  normalized
}

normalize_named_collection <- function(x, field, key) {
  if (length(x) == 0L) {
    return(list())
  }

  items <- unname(x)

  names(items) <- vapply(items, `[[`, character(1), key)
  items
}
