.dynms_mrgsolve_template_path <- function() {
  system.file(
    "templates",
    "mrgsolve-model.mod.mustache",
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
  time_event_index <- stats::setNames(seq_along(time_event_ids), time_event_ids)

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
  data$has_events <- length(time_events) + length(events) > 0L
  data$has_captured_observables <- any(vapply(data$observables, `[[`, logical(1), "captured"))

  data
}

prepare_mrgsolve_constant <- function(constant) {
  constant$value_expr <- dynms_value_to_mrgsolve(constant$value)
  constant$title <- constant$title %||% "-"
  constant
}

prepare_mrgsolve_dynamic_state <- function(state) {
  numeric_initial <- is.numeric(state$initial)

  state$initial_value <- dynms_initial_value_to_mrgsolve(state$initial)
  state$initial_expr <- dynms_value_to_mrgsolve(state$initial)
  state$has_expression_initial <- !numeric_initial
  state$derivative_expr <- dynms_expression_to_mrgsolve(state$derivative)
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_static_state <- function(state) {
  state$initial_expr <- dynms_value_to_mrgsolve(state$initial)
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_assignment <- function(assignment) {
  assignment$rhs_expr <- dynms_expression_to_mrgsolve(assignment$rhs)
  assignment$title <- assignment$title %||% "-"
  assignment
}

prepare_mrgsolve_time_event <- function(event, dynamic_index, time_event_index, event_number) {
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value <- if (isFALSE(event$active)) "0" else "1"
  event$time_index <- unname(time_event_index[[event$id]])
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) prepare_mrgsolve_event_action(event$actions[[i]], dynamic_index, event_number, i)
  )

  event$trigger <- trigger
  event$trigger$start_expr <- dynms_value_to_mrgsolve(trigger$start)
  event$trigger$has_period <- !is.null(trigger$period)
  event$trigger$period_expr <- if (!is.null(trigger$period)) dynms_value_to_mrgsolve(trigger$period) else ""
  event$trigger$has_stop <- !is.null(trigger$stop)
  event$trigger$stop_expr <- if (!is.null(trigger$stop)) dynms_value_to_mrgsolve(trigger$stop) else ""

  event
}

prepare_mrgsolve_event <- function(event, dynamic_index, event_number) {
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value <- if (isFALSE(event$active)) "0" else "1"
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) prepare_mrgsolve_event_action(event$actions[[i]], dynamic_index, event_number, i)
  )

  event$trigger <- trigger
  event$trigger$initial_pull <- if (isTRUE(trigger$atStart)) "false" else "true"
  event$trigger$trigger_expr <- dynms_expression_to_mrgsolve(trigger$rhs)
  event$trigger$trigger_suffix <- if (identical(trigger$type, "crossing")) " >= 0.0" else ""

  event
}

prepare_mrgsolve_event_action <- function(action, dynamic_index, event_number, action_number) {
  dynamic <- action$state %in% names(dynamic_index)

  action$rhs_expr <- dynms_expression_to_mrgsolve(action$rhs)
  action$dynamic <- dynamic
  action$static <- !dynamic
  action$cmt <- if (dynamic) unname(dynamic_index[[action$state]]) else ""
  action$event_var <- paste0("evt_", event_number, "_", action_number, "_")

  action
}

prepare_mrgsolve_observable <- function(observable, dynamic_index) {
  observable$captured <- !(observable$symbol %in% names(dynamic_index))
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
