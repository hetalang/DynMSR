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
#' @details
#' The exporter warns and ignores unsupported DynMS features: algebraic dynamic
#' states, `stopSimulation`, and state-event trigger `detection`. Algebraic
#' states are emitted as ordinary ODE states; state-event conditions are
#' evaluated in generated code without root finding. A detected state event is
#' processed at an mrgsolve output record, so its state update can be delayed by
#' up to one output interval. Use a smaller `delta` in [mrgsolve::mrgsim()] for
#' a closer step-based approximation; this does not reproduce the exact
#' root-crossing time. Reducing mrgsolve's `hmax` improves integration accuracy
#' but does not change the output-record event-processing rule.
#'
#' Identifiers reserved by mrgsolve are renamed with an `_rnm_` suffix. Further
#' numeric suffixes are added when needed to avoid collisions. The exporter
#' emits one warning and records the complete mapping in the generated model.
#' The DynMS time symbol `t` is emitted as `SOLVERTIME` in `$ODE` and as `TIME`
#' in other blocks.
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
  warn_mrgsolve_unsupported_features(model)
  prepared <- prepare_mrgsolve_identifiers(model)
  model <- prepared$model
  identifier_map <- prepared$identifier_map

  data <- model
  data$renamedIdentifiers <- lapply(names(identifier_map), function(identifier) {
    list(
      original = identifier,
      renamed = unname(identifier_map[[identifier]])
    )
  })
  data$has_renamed_identifiers_ <- length(identifier_map) > 0L

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
    function(i) {
      prepare_mrgsolve_time_event(
        time_events[[i]],
        dynamic_index,
        time_event_index,
        i
      )
    }
  )
  data$events <- lapply(
    seq_along(events),
    function(i) {
      prepare_mrgsolve_event(
        events[[i]],
        dynamic_index,
        i + length(time_events)
      )
    }
  )
  data$observables <- lapply(
    observables,
    prepare_mrgsolve_observable,
    dynamic_index = dynamic_index
  )
  data$has_events_ <- length(time_events) + length(events) > 0L
  data$has_parameters_ <- length(constants) + length(time_events) + length(events) > 0L
  data$has_dynamic_ <- length(dynamic) > 0L
  data$has_table_ <- length(assignments) + length(time_events) + length(events) > 0L
  data$has_captured_observables_ <- any(vapply(data$observables, `[[`, logical(1), "captured_"))

  data
}

prepare_mrgsolve_identifiers <- function(model) {
  identifier_map <- build_mrgsolve_identifier_map(model)
  warn_mrgsolve_renamed_identifiers(identifier_map)

  list(
    model = rename_model_identifiers(model, identifier_map),
    identifier_map = identifier_map
  )
}

build_mrgsolve_identifier_map <- function(model) {
  reserved <- jsonlite::fromJSON(.dynms_mrgsolve_reserved_words_path())
  collections <- c("constants", "dynamic", "static", "assignments", "timeEvents", "events")
  identifiers <- unlist(lapply(collections, function(field) {
    items <- model[[field]] %||% list()
    vapply(items, `[[`, character(1), "id")
  }), use.names = FALSE)
  used <- identifiers
  mapping <- character()

  for (identifier in identifiers) {
    if (!is_mrgsolve_reserved_identifier(identifier, reserved)) {
      next
    }

    base <- paste0(identifier, "_rnm_")
    if (is_mrgsolve_reserved_identifier(base, reserved)) {
      base <- paste0("rnm_", identifier, "_rnm_")
    }
    candidate <- base
    suffix <- 2L
    while (candidate %in% used || is_mrgsolve_reserved_identifier(candidate, reserved)) {
      candidate <- paste0(base, suffix)
      suffix <- suffix + 1L
    }

    mapping[identifier] <- candidate
    used <- c(used, candidate)
  }

  mapping
}

warn_mrgsolve_renamed_identifiers <- function(identifier_map) {
  if (length(identifier_map) == 0L) {
    return(invisible(NULL))
  }

  details <- paste0(
    "- `", names(identifier_map), "` -> `", unname(identifier_map), "`"
  )
  warning(
    paste(
      "mrgsolve export renamed reserved identifiers:",
      paste(details, collapse = "\n"),
      sep = "\n"
    ),
    call. = FALSE
  )

  invisible(NULL)
}

warn_mrgsolve_unsupported_features <- function(model) {
  issues <- character()
  dynamic <- model$dynamic %||% list()

  for (index in seq_along(dynamic)) {
    if (isTRUE(dynamic[[index]]$algebraic)) {
      issues <- c(
        issues,
        paste0("`dynamic[", index, "].algebraic`: algebraic states are emitted as ordinary ODE states")
      )
    }
  }

  for (field in c("timeEvents", "events")) {
    events <- model[[field]] %||% list()
    for (index in seq_along(events)) {
      event <- events[[index]]
      if (isTRUE(event$stopSimulation)) {
        issues <- c(
          issues,
          paste0("`", field, "[", index, "].stopSimulation`: simulation will not stop")
        )
      }
      if (identical(field, "events") && !is.null(event$trigger$detection)) {
        issues <- c(
          issues,
          paste0(
            "`events[", index, "].trigger.detection`: detection mode is ignored; ",
            "the condition is evaluated without root finding"
          )
        )
      }
    }
  }

  if (length(issues) > 0L) {
    warning(
      paste(
        "mrgsolve export ignores unsupported DynMS features:",
        paste(paste0("- ", issues), collapse = "\n"),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  invisible(NULL)
}

is_mrgsolve_reserved_identifier <- function(identifier, reserved) {
  if (identifier %in% reserved$reservedWords) {
    return(TRUE)
  }

  !is.null(find_mrgsolve_reserved_pattern(
    identifier,
    reserved$compartmentDependentPatterns
  ))
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
  constant$value_expr_ <- dynms_value_to_mrgsolve(constant$value, "TIME")
  constant$title <- constant$title %||% "-"
  constant
}

prepare_mrgsolve_dynamic_state <- function(state) {
  numeric_initial <- is.numeric(state$initial)

  state$initial_value_ <- dynms_initial_value_to_mrgsolve(state$initial, "TIME")
  state$initial_expr_ <- dynms_value_to_mrgsolve(state$initial, "TIME")
  state$has_expression_initial_ <- !numeric_initial
  state$derivative_expr_ <- dynms_expression_to_mrgsolve(state$derivative, "SOLVERTIME")
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_static_state <- function(state) {
  state$initial_expr_ <- dynms_value_to_mrgsolve(state$initial, "TIME")
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_assignment <- function(assignment) {
  assignment$rhs_expr_ <- dynms_expression_to_mrgsolve(assignment$rhs, "SOLVERTIME")
  assignment$rhs_expr_table_ <- dynms_expression_to_mrgsolve(assignment$rhs, "TIME")
  assignment$title <- assignment$title %||% "-"
  assignment
}

prepare_mrgsolve_time_event <- function(
  event, dynamic_index, time_event_index, event_number
) {
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value_ <- if (isFALSE(event$active)) "0" else "1"
  event$time_index_ <- unname(time_event_index[[event$id]])
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) {
      prepare_mrgsolve_event_action(
        event$actions[[i]], dynamic_index, event_number, i
      )
    }
  )

  event$trigger <- trigger
  event$trigger$start_expr_ <- dynms_value_to_mrgsolve(trigger$start, "TIME")
  event$trigger$has_period_ <- !is.null(trigger$period)
  event$trigger$period_expr_ <- if (!is.null(trigger$period)) {
    dynms_value_to_mrgsolve(trigger$period, "TIME")
  } else {
    ""
  }
  event$trigger$has_stop_ <- !is.null(trigger$stop)
  event$trigger$stop_expr_ <- if (!is.null(trigger$stop)) {
    dynms_value_to_mrgsolve(trigger$stop, "TIME")
  } else {
    ""
  }
  event
}

prepare_mrgsolve_event <- function(event, dynamic_index, event_number) {
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value_ <- if (isFALSE(event$active)) "0" else "1"
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) {
      prepare_mrgsolve_event_action(
        event$actions[[i]], dynamic_index, event_number, i
      )
    }
  )

  event$trigger <- trigger
  event$trigger$initial_pull_ <- if (isTRUE(trigger$atStart)) "false" else "true"
  event$trigger$trigger_expr_ <- dynms_expression_to_mrgsolve(trigger$rhs, "SOLVERTIME")
  event$trigger$trigger_suffix_ <- if (identical(trigger$type, "crossing")) " >= 0.0" else ""

  event
}

prepare_mrgsolve_event_action <- function(
  action, dynamic_index, event_number, action_number
) {
  dynamic <- action$state %in% names(dynamic_index)

  action$rhs_expr_ <- dynms_expression_to_mrgsolve(action$rhs, "TIME")
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

dynms_value_to_mrgsolve <- function(
  value, time_symbol = "TIME"
) {
  if (is.numeric(value)) {
    return(dynms_number_to_c(value))
  }

  dynms_expression_to_mrgsolve(value, time_symbol)
}

dynms_initial_value_to_mrgsolve <- function(
  value, time_symbol = "TIME"
) {
  if (is.numeric(value)) {
    return(dynms_value_to_mrgsolve(value, time_symbol))
  }

  "0.0"
}

dynms_expression_to_mrgsolve <- function(
  expression, time_symbol = "TIME"
) {
  dynms_mathjson_to_c(expression$expr, time_symbol)
}
