#' Print a DynMS platform
#'
#' Displays the DynMS version and a compact summary of each model in a
#' platform.
#'
#' @param x A DynMS platform object.
#' @param ... Unused.
#'
#' @return `x`, invisibly.
#' @export
print.platform <- function(x, ...) {
  cat("<DynMS platform>\n")
  cat("  DynMS version: ", x$dynms %||% "unknown", "\n", sep = "")
  if (!is.null(x$platformId)) {
    cat("  Platform ID: ", x$platformId, "\n", sep = "")
  }

  models <- x$models %||% list()
  cat("  Models: ", length(models), "\n", sep = "")
  for (index in seq_along(models)) {
    model <- models[[index]]
    cat(
      "    [", index, "] ", model$id %||% "<unnamed>", ": ",
      format_model_counts(model), "\n",
      sep = ""
    )
  }

  invisible(x)
}

#' Print a DynMS model
#'
#' Displays a compact inventory of model components and their identifiers.
#'
#' @param x A DynMS model object.
#' @param ... Unused.
#'
#' @return `x`, invisibly.
#' @export
print.model <- function(x, ...) {
  cat("<DynMS model: ", x$id %||% "<unnamed>", ">\n", sep = "")
  if (!is.null(x$title)) {
    cat("  Title: ", x$title, "\n", sep = "")
  }

  print_model_component("Dynamic states", x$dynamic)
  print_model_component("Static states", x$static)
  print_model_component("Constants", x$constants)
  print_model_component("Assignments", x$assignments)
  print_model_component("Time events", x$timeEvents)
  print_event_summary(x$events)
  print_model_component("Observables", x$observables, id_field = "symbol")

  invisible(x)
}

format_model_counts <- function(model) {
  paste(
    paste0(length(model$dynamic %||% list()), " dynamic"),
    paste0(length(model$static %||% list()), " static"),
    paste0(length(model$constants %||% list()), " constants"),
    paste0(length(model$assignments %||% list()), " assignments"),
    paste0(length(model$timeEvents %||% list()), " time events"),
    paste0(length(model$events %||% list()), " events"),
    paste0(length(model$observables %||% list()), " observables"),
    sep = ", "
  )
}

print_model_component <- function(label, items, id_field = "id") {
  items <- items %||% list()
  cat(
    "  ", label, " (", length(items), "): ",
    format_dynms_identifiers(items, id_field), "\n",
    sep = ""
  )
}

print_event_summary <- function(events) {
  events <- events %||% list()
  trigger_types <- vapply(
    events,
    function(event) event$trigger$type %||% "unknown",
    character(1)
  )
  type_counts <- table(trigger_types)
  details <- if (length(type_counts) == 0L) {
    "none"
  } else {
    paste(paste0(names(type_counts), " ", unname(type_counts)), collapse = ", ")
  }

  cat("  Events (", length(events), "): ", details, "\n", sep = "")
}

format_dynms_identifiers <- function(items, id_field, max_items = 10L) {
  if (length(items) == 0L) {
    return("none")
  }

  identifiers <- vapply(
    items,
    function(item) item[[id_field]] %||% "<unnamed>",
    character(1)
  )
  shown <- utils::head(identifiers, max_items)
  suffix <- if (length(identifiers) > max_items) {
    ", ..."
  } else {
    ""
  }

  paste0(paste(shown, collapse = ", "), suffix)
}
