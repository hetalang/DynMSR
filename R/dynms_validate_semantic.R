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

    validate_duplicate_identifiers(
      model$dynamic,
      paste0(model_path, ".dynamic"),
      "dynamic",
      "id",
      add_error
    )
    validate_duplicate_identifiers(
      model$static,
      paste0(model_path, ".static"),
      "static",
      "id",
      add_error
    )
    validate_duplicate_state_identifiers(
      model$dynamic,
      model$static,
      model_path,
      add_error
    )
    validate_duplicate_identifiers(
      model$constants,
      paste0(model_path, ".constants"),
      "constants",
      "id",
      add_error
    )
    validate_duplicate_identifiers(
      model$assignments,
      paste0(model_path, ".assignments"),
      "assignments",
      "id",
      add_error
    )
    validate_duplicate_identifiers(
      model$events,
      paste0(model_path, ".events"),
      "events",
      "id",
      add_error
    )
    validate_duplicate_identifiers(
      model$observables,
      paste0(model_path, ".observables"),
      "observables",
      "symbol",
      add_error
    )
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

validate_duplicate_identifiers <- function(x, path, field, id_field, add_error) {
  if (length(x) == 0L) {
    return(invisible(TRUE))
  }

  ids <- vapply(x, `[[`, character(1), id_field)
  duplicated_ids <- unique(ids[duplicated(ids)])

  for (id in duplicated_ids) {
    add_error(
      path,
      "duplicate_identifier",
      paste0("Duplicate identifier in `", field, "`: ", id)
    )
  }

  invisible(TRUE)
}

validate_duplicate_state_identifiers <- function(dynamic, static, model_path, add_error) {
  dynamic_ids <- collect_identifiers(dynamic, "id")
  static_ids <- collect_identifiers(static, "id")
  duplicated_ids <- intersect(dynamic_ids, static_ids)

  for (id in duplicated_ids) {
    add_error(
      model_path,
      "duplicate_identifier",
      paste0("Duplicate state identifier across `dynamic` and `static`: ", id)
    )
  }

  invisible(TRUE)
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
