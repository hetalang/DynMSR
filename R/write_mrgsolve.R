.dynms_mrgsolve_template_path <- function() {
  system.file(
    "templates",
    "mrgsolve-model.mod.mustache",
    package = "DynMSR",
    mustWork = TRUE
  )
}

.dynms_mrgsolve_reserved_words_path <- function() {
  system.file(
    "templates",
    "reserved-words.json",
    package = "DynMSR",
    mustWork = TRUE
  )
}

#' Write an mrgsolve model file
#'
#' Generates mrgsolve source from one DynMS model.
#'
#' @param model A model list, such as one element of `platform$models`.
#' @param filepath Path where the generated model source should be written. If
#'   omitted, a temporary `.mod` file is created.
#'
#' @return The path to the generated model file.
#' @export
write_mrgsolve <- function(model, filepath = tempfile(fileext = ".mod")) {
  if (!is.character(filepath) || length(filepath) != 1L || is.na(filepath)) {
    stop("`filepath` must be a single output file path.", call. = FALSE)
  }
  check_mrgsolve_model(model, "write_mrgsolve")

  data <- prepare_mrgsolve_template_data(model)
  template <- readLines(.dynms_mrgsolve_template_path(), warn = FALSE)
  code <- whisker::whisker.render(paste(template, collapse = "\n"), data)

  output_dir <- dirname(filepath)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  writeLines(code, filepath, useBytes = TRUE)
  filepath
}

check_mrgsolve_model <- function(model, caller) {
  if (!is.list(model)) {
    stop("`model` must be a DynMS model represented as an R list.", call. = FALSE)
  }
  if (is.list(model$models)) {
    stop(
      paste(
        "`", caller, "()` expects one model, not a platform.",
        "Select a model first, for example `platform$models[[1]]`.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  invisible(model)
}

prepare_mrgsolve_template_data <- function(model) {
  validate_mrgsolve_identifiers(model)

  data <- model

  constants <- unname(model$constants)
  dynamic <- unname(model$dynamic)
  static <- unname(model$static)
  assignments <- unname(model$assignments)
  time_events <- unname(model$timeEvents)
  events <- unname(model$events)
  observables <- unname(model$observables)

  dynamic_state_ids <- vapply(dynamic, `[[`, character(1), "id")
  dynamic_index <- stats::setNames(seq_along(dynamic_state_ids), dynamic_state_ids)

  time_event_ids <- vapply(time_events, `[[`, character(1), "id")
  time_event_index <- stats::setNames(seq_along(time_event_ids) + 9L, time_event_ids)

  data$constants <- lapply(constants, prepare_mrgsolve_constant)
  data$dynamic <- lapply(dynamic, prepare_mrgsolve_dynamic_state)
  data$static <- lapply(static, prepare_mrgsolve_static_state)
  data$assignments <- lapply(assignments, prepare_mrgsolve_assignment)
  data$timeEvents <- lapply(
    seq_along(time_events),
    function(i) prepare_mrgsolve_time_event(time_events[[i]], dynamic_index, time_event_index, i)
  )
  data$events <- lapply(
    seq_along(events),
    function(i) prepare_mrgsolve_event(events[[i]], dynamic_index, i + length(time_events))
  )
  data$observables <- lapply(observables, prepare_mrgsolve_observable, dynamic_index = dynamic_index)
  data$has_events_ <- length(time_events) + length(events) > 0L
  data$has_captured_observables_ <- any(vapply(data$observables, `[[`, logical(1), "captured_"))

  data
}

validate_mrgsolve_identifiers <- function(model) {
  reserved <- jsonlite::fromJSON(.dynms_mrgsolve_reserved_words_path())
  identifiers <- collect_mrgsolve_identifiers(model)
  violations <- lapply(identifiers, find_mrgsolve_identifier_violation, reserved = reserved)
  violations <- Filter(Negate(is.null), violations)

  if (length(violations) == 0L) {
    return(invisible(model))
  }

  details <- vapply(
    violations,
    function(violation) {
      paste0(
        "- `", violation$path, "` (`", violation$identifier, "`) ",
        violation$reason, "."
      )
    },
    character(1)
  )
  stop(
    paste(
      "mrgsolve export cannot use reserved identifiers:",
      paste(details, collapse = "\n"),
      sep = "\n"
    ),
    call. = FALSE
  )
}

collect_mrgsolve_identifiers <- function(model) {
  entries <- c(
    collect_mrgsolve_field_identifiers(model$constants, "constants", "id"),
    collect_mrgsolve_field_identifiers(model$dynamic, "dynamic", "id"),
    collect_mrgsolve_field_identifiers(model$static, "static", "id"),
    collect_mrgsolve_field_identifiers(model$assignments, "assignments", "id"),
    collect_mrgsolve_field_identifiers(model$timeEvents, "timeEvents", "id"),
    collect_mrgsolve_field_identifiers(model$events, "events", "id"),
    collect_mrgsolve_field_identifiers(model$observables, "observables", "symbol"),
    collect_mrgsolve_action_identifiers(model$timeEvents, "timeEvents"),
    collect_mrgsolve_action_identifiers(model$events, "events")
  )

  unname(entries)
}

collect_mrgsolve_field_identifiers <- function(items, collection, field) {
  items <- items %||% list()
  lapply(seq_along(items), function(index) {
    list(
      path = paste0(collection, "[", index, "].", field),
      identifier = items[[index]][[field]]
    )
  })
}

collect_mrgsolve_action_identifiers <- function(events, collection) {
  events <- events %||% list()
  entries <- list()

  for (event_index in seq_along(events)) {
    actions <- events[[event_index]]$actions %||% list()
    for (action_index in seq_along(actions)) {
      entries[[length(entries) + 1L]] <- list(
        path = paste0(
          collection, "[", event_index, "].actions[", action_index, "].state"
        ),
        identifier = actions[[action_index]]$state
      )
    }
  }

  entries
}

find_mrgsolve_identifier_violation <- function(entry, reserved) {
  identifier <- entry$identifier
  if (identifier %in% reserved$reservedWords) {
    return(c(entry, list(reason = "is a reserved word")))
  }

  matching_pattern <- find_mrgsolve_reserved_pattern(
    identifier,
    reserved$compartmentDependentPatterns
  )
  if (!is.null(matching_pattern)) {
    return(c(
      entry,
      list(reason = paste0("matches reserved pattern `", matching_pattern, "`"))
    ))
  }

  NULL
}

find_mrgsolve_reserved_pattern <- function(identifier, patterns) {
  for (pattern in patterns) {
    expression <- paste0(
      "^",
      sub("{CMT}", "[A-Za-z][A-Za-z0-9_]*", pattern, fixed = TRUE),
      "$"
    )
    if (grepl(expression, identifier)) {
      return(pattern)
    }
  }

  NULL
}

prepare_mrgsolve_constant <- function(constant) {
  constant$value_expr_ <- dynms_value_to_mrgsolve(constant$value)
  constant$title <- constant$title %||% "-"
  constant
}

prepare_mrgsolve_dynamic_state <- function(state) {
  numeric_initial <- is.numeric(state$initial)

  state$initial_value_ <- dynms_initial_value_to_mrgsolve(state$initial)
  state$initial_expr_ <- dynms_value_to_mrgsolve(state$initial)
  state$has_expression_initial_ <- !numeric_initial
  state$derivative_expr_ <- dynms_expression_to_mrgsolve(state$derivative)
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_static_state <- function(state) {
  state$initial_expr_ <- dynms_value_to_mrgsolve(state$initial)
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_assignment <- function(assignment) {
  assignment$rhs_expr_ <- dynms_expression_to_mrgsolve(assignment$rhs)
  assignment$title <- assignment$title %||% "-"
  assignment
}

prepare_mrgsolve_time_event <- function(event, dynamic_index, time_event_index, event_number) {
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value_ <- if (isFALSE(event$active)) "0" else "1"
  event$time_index_ <- unname(time_event_index[[event$id]])
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) prepare_mrgsolve_event_action(event$actions[[i]], dynamic_index, event_number, i)
  )

  event$trigger <- trigger
  event$trigger$start_expr_ <- dynms_value_to_mrgsolve(trigger$start)
  event$trigger$has_period_ <- !is.null(trigger$period)
  event$trigger$period_expr_ <- if (!is.null(trigger$period)) dynms_value_to_mrgsolve(trigger$period) else ""
  event$trigger$has_stop_ <- !is.null(trigger$stop)
  event$trigger$stop_expr_ <- if (!is.null(trigger$stop)) dynms_value_to_mrgsolve(trigger$stop) else ""

  event
}

prepare_mrgsolve_event <- function(event, dynamic_index, event_number) {
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value_ <- if (isFALSE(event$active)) "0" else "1"
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) prepare_mrgsolve_event_action(event$actions[[i]], dynamic_index, event_number, i)
  )

  event$trigger <- trigger
  event$trigger$initial_pull_ <- if (isTRUE(trigger$atStart)) "false" else "true"
  event$trigger$trigger_expr_ <- dynms_expression_to_mrgsolve(trigger$rhs)
  event$trigger$trigger_suffix_ <- if (identical(trigger$type, "crossing")) " >= 0.0" else ""

  event
}

prepare_mrgsolve_event_action <- function(action, dynamic_index, event_number, action_number) {
  dynamic <- action$state %in% names(dynamic_index)

  action$rhs_expr_ <- dynms_expression_to_mrgsolve(action$rhs)
  action$dynamic_ <- dynamic
  action$static_ <- !dynamic
  action$cmt_ <- if (dynamic) unname(dynamic_index[[action$state]]) else ""
  action$event_var_ <- paste0("evt_", event_number, "_", action_number, "_")

  action
}

prepare_mrgsolve_observable <- function(observable, dynamic_index) {
  observable$captured_ <- !(observable$symbol %in% names(dynamic_index))
  observable$title <- observable$title %||% "-"
  observable
}

# mrgsolve specific helpers for converting DynMS objects to mrgsolve code

dynms_value_to_mrgsolve <- function(value) {
  if (is.numeric(value)) {
    return(dynms_number_to_c(value))
  }

  dynms_expression_to_mrgsolve(value)
}

dynms_initial_value_to_mrgsolve <- function(value) {
  if (is.numeric(value)) {
    return(dynms_value_to_mrgsolve(value))
  }

  "0.0"
}

dynms_expression_to_mrgsolve <- function(expression) {
  dynms_mathjson_to_c(expression$expr)
}
