rename_model_identifiers <- function(model, identifier_map) {
  validate_identifier_map(model, identifier_map)
  if (length(identifier_map) == 0L) {
    return(model)
  }

  rename_id <- function(item) {
    item$id <- mapped_identifier(item$id, identifier_map)
    item
  }
  rename_expression <- function(expression) {
    rename_expression_identifiers(expression, identifier_map)
  }
  rename_action <- function(action) {
    action$state <- mapped_identifier(action$state, identifier_map)
    action$rhs <- rename_expression(action$rhs)
    action
  }

  model$constants <- lapply(model$constants, function(item) {
    item <- rename_id(item)
    item$value <- rename_expression(item$value)
    item
  })
  model$dynamic <- lapply(model$dynamic, function(item) {
    item <- rename_id(item)
    item$initial <- rename_expression(item$initial)
    item$derivative <- rename_expression(item$derivative)
    item
  })
  model$static <- lapply(model$static, function(item) {
    item <- rename_id(item)
    item$initial <- rename_expression(item$initial)
    item
  })
  model$assignments <- lapply(model$assignments, function(item) {
    item <- rename_id(item)
    item$rhs <- rename_expression(item$rhs)
    item
  })
  model$timeEvents <- lapply(model$timeEvents, function(item) {
    item <- rename_id(item)
    for (field in intersect(c("start", "period", "stop"), names(item$trigger))) {
      item$trigger[[field]] <- rename_expression(item$trigger[[field]])
    }
    item$actions <- lapply(item$actions, rename_action)
    item
  })
  model$events <- lapply(model$events, function(item) {
    item <- rename_id(item)
    item$trigger$rhs <- rename_expression(item$trigger$rhs)
    item$actions <- lapply(item$actions, rename_action)
    item
  })
  model$observables <- lapply(model$observables, function(item) {
    item$symbol <- mapped_identifier(item$symbol, identifier_map)
    item
  })

  model
}

validate_identifier_map <- function(model, identifier_map) {
  if (!is.character(identifier_map)) {
    stop("`identifier_map` must be a named character vector.", call. = FALSE)
  }
  if (length(identifier_map) == 0L) {
    return(invisible(TRUE))
  }
  if (is.null(names(identifier_map))) {
    stop("`identifier_map` must be a named character vector.", call. = FALSE)
  }
  if (any(!nzchar(names(identifier_map))) || anyDuplicated(names(identifier_map))) {
    stop("`identifier_map` must have unique, non-empty names.", call. = FALSE)
  }
  if ("t" %in% c(names(identifier_map), identifier_map)) {
    stop("The time symbol `t` cannot be renamed or used as an identifier.", call. = FALSE)
  }
  if (any(!grepl("^[A-Za-z][A-Za-z0-9_]*$", identifier_map))) {
    stop("Renamed identifiers must be valid DynMS identifiers.", call. = FALSE)
  }

  fields <- c("constants", "dynamic", "static", "assignments", "timeEvents", "events")
  identifiers <- unlist(lapply(fields, function(field) {
    vapply(model[[field]], `[[`, character(1), "id")
  }), use.names = FALSE)
  unknown <- setdiff(names(identifier_map), identifiers)
  if (length(unknown) > 0L) {
    stop("Unknown identifiers in `identifier_map`: ", paste(unknown, collapse = ", "), call. = FALSE)
  }

  renamed <- vapply(identifiers, mapped_identifier, character(1), identifier_map)
  duplicated <- unique(renamed[duplicated(renamed)])
  if (length(duplicated) > 0L) {
    stop("Identifier mapping creates collisions: ", paste(duplicated, collapse = ", "), call. = FALSE)
  }

  invisible(TRUE)
}

mapped_identifier <- function(identifier, identifier_map) {
  if (!identifier %in% names(identifier_map)) {
    return(identifier)
  }

  unname(identifier_map[[identifier]])
}

rename_expression_identifiers <- function(expression, identifier_map) {
  if (!is.list(expression) || !identical(expression$format, "math-json")) {
    return(expression)
  }

  expression$expr <- rename_mathjson_identifiers(expression$expr, identifier_map)
  expression
}

rename_mathjson_identifiers <- function(node, identifier_map) {
  if (is.character(node)) {
    return(mapped_identifier(node, identifier_map))
  }
  if (!is.list(node) || !is.null(node$num) || !is.null(node$str)) {
    return(node)
  }
  if (!is.null(node$sym)) {
    node$sym <- mapped_identifier(node$sym, identifier_map)
    return(node)
  }
  if (!is.null(node$fn)) {
    node$fn <- rename_mathjson_identifiers(node$fn, identifier_map)
    return(node)
  }
  if (length(node) > 1L) {
    node[-1L] <- lapply(node[-1L], rename_mathjson_identifiers, identifier_map)
  }

  node
}
