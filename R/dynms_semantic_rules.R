validate_scenario_identifiers <- function(raw_platform, add_error) {
  seen <- character()

  for (index in seq_along(raw_platform$scenarios)) {
    id <- raw_platform$scenarios[[index]]$id
    if (!is.character(id) || length(id) != 1L || is.na(id)) next

    if (id %in% seen) {
      add_error(
        paste0("$.scenarios[", index, "].id"),
        "duplicate_scenario_identifier",
        paste0("Duplicate scenario identifier: ", id)
      )
    }
    seen <- c(seen, id)
  }

  invisible(TRUE)
}

validate_scenario_references <- function(raw_platform, add_error) {
  model_ids <- vapply(raw_platform$models, function(model) {
    id <- model$id
    if (is.character(id) && length(id) == 1L && !is.na(id)) id else NA_character_
  }, character(1))

  for (index in seq_along(raw_platform$scenarios)) {
    model <- raw_platform$scenarios[[index]]$model
    if (!is.character(model) || length(model) != 1L || is.na(model)) next

    if (!model %in% model_ids) {
      add_error(
        paste0("$.scenarios[", index, "].model"),
        "unknown_scenario_model",
        paste0("Scenario references an unknown model: ", model)
      )
    }
  }

  invisible(TRUE)
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
  if (is.list(expression) && !identical(expression$format, "math-json")) {
    add_error(
      path,
      "unsupported_expression_format",
      paste0("DynMSR supports only `math-json` expressions; found `", expression$format, "`.")
    )
    return(invisible(TRUE))
  }

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

