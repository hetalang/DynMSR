.dynms_mrgsolve_template_path <- system.file(
  "templates",
  "mrgsolve-model.mod.mustache",
  package = "DynMSR",
  mustWork = TRUE
)

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
  template <- readLines(.dynms_mrgsolve_template_path, warn = FALSE)
  code <- whisker::whisker.render(paste(template, collapse = "\n"), data)

  output_dir <- dirname(filepath)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  writeLines(code, filepath, useBytes = TRUE)
  filepath
}

#' Compile a DynMS model with mrgsolve
#'
#' Generates an mrgsolve model source file and compiles it with `mrgsolve`.
#' The `mrgsolve` package is optional and is required only when this function is
#' called.
#'
#' @param model A model list, such as one element of `platform$models`.
#' @param filepath Path where the intermediate mrgsolve model source should be
#'   written. If omitted, a temporary `.mod` file is created.
#' @param ... Additional arguments passed to [mrgsolve::mread()].
#'
#' @return A compiled mrgsolve model object.
#' @export
build_mrgsolve <- function(model, filepath = tempfile(fileext = ".mod"), ...) {
  check_mrgsolve_model(model, "build_mrgsolve")

  if (!requireNamespace("mrgsolve", quietly = TRUE)) {
    stop(
      paste(
        "Package `mrgsolve` is required to compile DynMS models with mrgsolve.",
        "Install it with `install.packages(\"mrgsolve\")`.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  path <- write_mrgsolve(model, filepath)
  mrgsolve::mread(
    model = tools::file_path_sans_ext(basename(path)),
    project = dirname(path),
    file = basename(path),
    ...
  )
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
  states <- unname(model$states)
  assignments <- unname(model$assignments)
  derivatives <- unname(model$derivatives)
  events <- unname(model$events)
  observables <- unname(model$observables)

  dynamic_state_ids <- vapply(
    Filter(function(x) !isTRUE(x$static), states),
    `[[`,
    character(1),
    "id"
  )
  dynamic_index <- stats::setNames(seq_along(dynamic_state_ids), dynamic_state_ids)

  time_event_ids <- vapply(
    Filter(function(x) identical(x$trigger$type, "time"), events),
    `[[`,
    character(1),
    "id"
  )
  time_event_index <- stats::setNames(seq_along(time_event_ids), time_event_ids)

  data$constants <- lapply(constants, prepare_mrgsolve_constant)
  data$states <- lapply(states, prepare_mrgsolve_state)
  data$assignments <- lapply(assignments, prepare_mrgsolve_assignment)
  data$derivatives <- lapply(derivatives, prepare_mrgsolve_derivative)
  data$events <- lapply(
    seq_along(events),
    function(i) prepare_mrgsolve_event(events[[i]], dynamic_index, time_event_index, i)
  )
  data$observables <- lapply(observables, prepare_mrgsolve_observable, dynamic_index = dynamic_index)
  data$has_events <- length(events) > 0L
  data$has_captured_observables <- any(vapply(data$observables, `[[`, logical(1), "captured"))

  data
}

prepare_mrgsolve_constant <- function(constant) {
  constant$value_expr <- dynms_value_to_mrgsolve(constant$value)
  constant$title <- constant$title %||% "-"
  constant
}

prepare_mrgsolve_state <- function(state) {
  static <- isTRUE(state$static)
  numeric_initial <- is.numeric(state$initial)

  state$static <- static
  state$dynamic <- !static
  state$initial_value <- dynms_initial_value_to_mrgsolve(state$initial)
  state$initial_expr <- dynms_value_to_mrgsolve(state$initial)
  state$has_expression_initial <- !static && !numeric_initial
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_assignment <- function(assignment) {
  assignment$rhs_expr <- dynms_expression_to_mrgsolve(assignment$rhs)
  assignment$title <- assignment$title %||% "-"
  assignment
}

prepare_mrgsolve_derivative <- function(derivative) {
  derivative$rhs_expr <- dynms_expression_to_mrgsolve(derivative$rhs)
  derivative
}

prepare_mrgsolve_event <- function(event, dynamic_index, time_event_index, event_number) {
  is_time <- identical(event$trigger$type, "time")
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value <- if (isFALSE(event$active)) "0" else "1"
  event$is_time <- is_time
  event$is_non_time <- !is_time
  event$time_index <- if (is_time) unname(time_event_index[[event$id]]) else ""
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) prepare_mrgsolve_event_action(event$actions[[i]], dynamic_index, event_number, i)
  )

  event$trigger <- trigger
  if (is_time) {
    event$trigger$start_expr <- dynms_value_to_mrgsolve(trigger$start)
    event$trigger$has_period <- !is.null(trigger$period)
    event$trigger$period_expr <- if (!is.null(trigger$period)) dynms_value_to_mrgsolve(trigger$period) else ""
    event$trigger$has_stop <- !is.null(trigger$stop)
    event$trigger$stop_expr <- if (!is.null(trigger$stop)) dynms_value_to_mrgsolve(trigger$stop) else ""
  } else {
    event$trigger$initial_pull <- if (isTRUE(trigger$atStart)) "false" else "true"
    event$trigger$trigger_expr <- dynms_expression_to_mrgsolve(trigger$rhs)
    event$trigger$trigger_suffix <- if (identical(trigger$type, "crossing")) " >= 0.0" else ""
  }

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
