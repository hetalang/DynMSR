#' Validate DynMS semantic consistency
#'
#' Validates backend-independent semantic consistency of a schema-valid raw
#' DynMS platform object. Unlike schema validation, this function collects all
#' currently known semantic issues before returning.
#'
#' @param raw_platform Raw DynMS platform object, typically returned by
#'   [dynms_read()].
#' @param error Whether semantic validation errors should be raised as one R
#'   error after all issues are collected.
#'
#' @return A list with `valid`, `errors`, and `warnings` fields.
#' @export
dynms_validate_semantic <- function(raw_platform, error = FALSE) {
  issues <- list()

  add_error <- function(path, code, message) {
    issues[[length(issues) + 1L]] <<- list(
      path = path,
      code = code,
      message = message
    )
  }

  for (model_index in seq_along(raw_platform$models)) {
    model_path <- paste0("$.models[", model_index, "]")
    model <- raw_platform$models[[model_index]]

    validate_model_identifiers(model, model_path, add_error)
    validate_model_references(model, model_path, add_error)
  }

  return_semantic_result(issues, error)
}

return_semantic_result <- function(errors, error) {
  result <- list(
    valid = length(errors) == 0L,
    errors = errors,
    warnings = list()
  )

  if (!result$valid && isTRUE(error)) {
    stop(format_semantic_errors(errors), call. = FALSE)
  }

  result
}

validate_model_identifiers <- function(model, model_path, add_error) {
  collections <- c("constants", "dynamic", "static", "assignments", "timeEvents", "events")
  identifiers <- lapply(collections, function(name) collect_identifiers(model[[name]], "id"))
  names(identifiers) <- collections
  ids <- unlist(identifiers, use.names = FALSE)
  duplicated_ids <- unique(ids[duplicated(ids)])

  for (id in duplicated_ids) {
    fields <- names(identifiers)[vapply(identifiers, function(x) id %in% x, logical(1))]
    message <- duplicate_identifier_message(id, fields)
    add_error(
      model_path,
      "duplicate_identifier",
      message
    )
  }

  invisible(TRUE)
}

duplicate_identifier_message <- function(id, fields) {
  if (length(fields) == 1L) {
    return(paste0("Duplicate identifier in `", fields, "`: ", id))
  }
  if (identical(sort(fields), c("dynamic", "static"))) {
    return(paste0("Duplicate state identifier across `dynamic` and `static`: ", id))
  }
  if (identical(sort(fields), c("events", "timeEvents"))) {
    return(paste0("Duplicate event identifier across `timeEvents` and `events`: ", id))
  }

  paste0("Duplicate identifier across `", paste(fields, collapse = "` and `"), "`: ", id)
}

validate_model_references <- function(model, model_path, add_error) {
  constant_ids <- collect_identifiers(model$constants, "id")
  dynamic_ids <- collect_identifiers(model$dynamic, "id")
  static_ids <- collect_identifiers(model$static, "id")
  assignment_ids <- collect_identifiers(model$assignments, "id")
  state_ids <- c(dynamic_ids, static_ids)
  symbols <- c(constant_ids, state_ids, assignment_ids, "t", mathjson_constants())

  validate_state_initials(model$dynamic, "dynamic", model_path, constant_ids, add_error)
  validate_state_initials(model$static, "static", model_path, constant_ids, add_error)
  validate_expression_collection(
    model$dynamic, "derivative", paste0(model_path, ".dynamic"), symbols, add_error
  )
  validate_expression_collection(
    model$assignments, "rhs", paste0(model_path, ".assignments"), symbols, add_error
  )
  validate_assignments(model$assignments, model_path, add_error)
  validate_events(model$timeEvents, "timeEvents", model_path, state_ids, constant_ids, symbols, add_error)
  validate_events(model$events, "events", model_path, state_ids, constant_ids, symbols, add_error)
  validate_observables(model$observables, model_path, state_ids, assignment_ids, add_error)

  invisible(TRUE)
}

validate_expression_collection <- function(x, field, path, allowed, add_error) {
  for (index in seq_along(x)) {
    validate_expression_symbols(
      x[[index]][[field]],
      paste0(path, "[", index, "].", field),
      allowed,
      add_error
    )
  }

  invisible(TRUE)
}

validate_state_initials <- function(states, field, model_path, constant_ids, add_error) {
  for (index in seq_along(states)) {
    validate_expression_symbols(
      states[[index]]$initial,
      paste0(model_path, ".", field, "[", index, "].initial"),
      c(constant_ids, mathjson_constants()),
      add_error
    )
  }

  invisible(TRUE)
}

validate_assignments <- function(assignments, model_path, add_error) {
  assignment_ids <- collect_identifiers(assignments, "id")

  for (index in seq_along(assignments)) {
    references <- expression_symbols(assignments[[index]]$rhs)
    later_ids <- assignment_ids[index:length(assignment_ids)]
    invalid <- intersect(references, later_ids)

    for (id in invalid) {
      add_error(
        paste0(model_path, ".assignments[", index, "].rhs"),
        "assignment_order",
        paste0("Assignment `", assignments[[index]]$id,
               "` must not reference itself or a later assignment: ", id)
      )
    }
  }

  invisible(TRUE)
}

validate_events <- function(events, field, model_path, state_ids, constant_ids, symbols, add_error) {
  for (index in seq_along(events)) {
    event <- events[[index]]
    event_path <- paste0(model_path, ".", field, "[", index, "]")

    if (identical(field, "timeEvents")) {
      for (name in c("start", "period", "stop")) {
        validate_expression_symbols(
          event$trigger[[name]], paste0(event_path, ".trigger.", name),
          c(constant_ids, mathjson_constants()), add_error
        )
      }
    } else {
      validate_expression_symbols(event$trigger$rhs, paste0(event_path, ".trigger.rhs"), symbols, add_error)
    }

    validate_event_actions(event$actions, event_path, state_ids, symbols, add_error)
  }

  invisible(TRUE)
}

validate_event_actions <- function(actions, event_path, state_ids, symbols, add_error) {
  targets <- character()

  for (index in seq_along(actions)) {
    action <- actions[[index]]
    action_path <- paste0(event_path, ".actions[", index, "]")

    if (!action$state %in% state_ids) {
      add_error(action_path, "invalid_action_state",
                paste0("Event action must target a dynamic or static state: ", action$state))
    }
    if (action$state %in% targets) {
      add_error(action_path, "duplicate_action_state",
                paste0("Event action state occurs more than once: ", action$state))
    }
    targets <- c(targets, action$state)
    validate_expression_symbols(action$rhs, paste0(action_path, ".rhs"), symbols, add_error)
  }

  invisible(TRUE)
}

validate_observables <- function(observables, model_path, state_ids, assignment_ids, add_error) {
  for (index in seq_along(observables)) {
    symbol <- observables[[index]]$symbol
    if (!symbol %in% c(state_ids, assignment_ids)) {
      add_error(
        paste0(model_path, ".observables[", index, "].symbol"),
        "invalid_observable",
        paste0("Observable must reference a dynamic state, static state, or assignment: ", symbol)
      )
    }
  }

  invisible(TRUE)
}

validate_expression_symbols <- function(expression, path, allowed, add_error) {
  references <- expression_symbols(expression)
  invalid <- setdiff(references, allowed)

  for (symbol in invalid) {
    add_error(path, "unknown_symbol", paste0("Unknown or disallowed symbol: ", symbol))
  }

  invisible(TRUE)
}

expression_symbols <- function(expression) {
  if (!is.list(expression) || !identical(expression$format, "math-json")) {
    return(character())
  }

  unique(mathjson_symbols(expression$expr))
}

mathjson_symbols <- function(node) {
  if (is.character(node)) {
    return(node)
  }
  if (!is.list(node)) {
    return(character())
  }
  if (!is.null(node$sym)) {
    return(node$sym)
  }
  if (!is.null(node$num) || !is.null(node$str)) {
    return(character())
  }
  if (!is.null(node$fn)) {
    node <- node$fn
  }
  if (length(node) <= 1L) {
    return(character())
  }

  unlist(lapply(node[-1L], mathjson_symbols), use.names = FALSE)
}

mathjson_constants <- function() {
  c("Pi", "ExponentialE", "ImaginaryUnit", "ComplexInfinity", "Infinity", "NaN", "True", "False")
}

collect_identifiers <- function(x, id_field) {
  if (length(x) == 0L) {
    return(character())
  }

  vapply(x, `[[`, character(1), id_field)
}

format_semantic_errors <- function(errors) {
  lines <- vapply(
    errors,
    function(issue) {
      paste0(issue$path, " [", issue$code, "]: ", issue$message)
    },
    character(1)
  )

  paste(
    "DynMS semantic validation failed:",
    paste(lines, collapse = "\n"),
    sep = "\n"
  )
}
