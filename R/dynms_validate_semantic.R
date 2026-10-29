#' Validate DynMS semantic consistency
#'
#' Validates backend-independent semantic consistency of a schema-valid raw
#' DynMS platform object. Unlike schema validation, this function collects all
#' currently known semantic issues before returning. It does not validate the
#' document structure; use [dynms_validate_schema()] first when the input has
#' not already passed schema validation.
#'
#' @param raw_platform Raw DynMS platform object, typically returned by
#'   [dynms_read()].
#' @param error Whether semantic validation errors should be raised as one R
#'   error after all issues are collected.
#'
#' @return A list with `valid`, `errors`, and `warnings` fields.
#' @export
#'
#' @examples
#' raw_platform <- dynms_read(dynms_lib("first-order-decay"))
#' validation <- dynms_validate_semantic(raw_platform)
#' validation$valid
dynms_validate_semantic <- function(raw_platform, error = FALSE) {
  version <- raw_platform$dynms
  if (identical(version, "0.2.1")) {
    return(dynms_validate_semantic_0_2_1(raw_platform, error))
  }
  if (identical(version, "0.2.2")) {
    return(dynms_validate_semantic_0_2_2(raw_platform, error))
  }

  # Schema validation reports missing or unsupported versions. Keep collecting
  # version-independent issues so dynms_load() can report both kinds of error.
  validate_semantic_rules(
    raw_platform,
    list(validate_model_identifiers, validate_model_references),
    error
  )
}

dynms_validate_semantic_0_2_1 <- function(raw_platform, error = FALSE) {
  model_rules <- list(
    validate_model_identifiers,
    validate_model_references
  )
  validate_semantic_rules(raw_platform, model_rules, error)
}

dynms_validate_semantic_0_2_2 <- function(raw_platform, error = FALSE) {
  model_rules <- list(
    validate_model_identifiers,
    validate_model_references
  )
  platform_rules <- list(
    validate_scenario_identifiers,
    validate_scenario_references
  )
  validate_semantic_rules(raw_platform, model_rules, error, platform_rules)
}

validate_semantic_rules <- function(raw_platform, model_rules, error, platform_rules = list()) {
  issues <- list()

  add_error <- function(path, code, message) {
    issues[[length(issues) + 1L]] <<- list(
      path = path,
      code = code,
      message = message
    )
  }

  for (rule in platform_rules) {
    rule(raw_platform, add_error)
  }

  for (model_index in seq_along(raw_platform$models)) {
    model_path <- paste0("$.models[", model_index, "]")
    model <- raw_platform$models[[model_index]]

    for (rule in model_rules) {
      rule(model, model_path, add_error)
    }
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
