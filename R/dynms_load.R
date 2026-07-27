#' Load a DynMS platform
#'
#' Reads a DynMS JSON file, validates it against the bundled schema, runs
#' backend-independent semantic validation, and returns a platform list.
#'
#' Schema and semantic validation are both attempted before loading fails.
#' Validation messages are reported with [message()], followed by one final
#' error when any validation issue is found.
#'
#' DynMSR currently supports only expressions with `format: "math-json"`.
#'
#' @param path Path to a DynMS JSON file.
#'
#' @return A platform list. Use `platform$models[[i]]` to select one model for
#'   backend-specific operations.
#' @export
dynms_load <- function(path) {
  raw_platform <- dynms_read(path)
  schema <- dynms_validate_schema(raw_platform, error = FALSE)
  semantic <- dynms_validate_semantic(raw_platform, error = FALSE)

  if (!schema$valid || !semantic$valid) {
    report_load_validation_errors(schema, semantic)
    stop(
      paste0(
        "DynMS load failed: validation found ",
        length(schema$errors) + length(semantic$errors),
        " error(s)."
      ),
      call. = FALSE
    )
  }

  new_platform(raw_platform)
}

report_load_validation_errors <- function(schema, semantic) {
  if (!schema$valid) {
    message(format_schema_errors(schema$errors))
  }

  if (!semantic$valid) {
    message(format_semantic_errors(semantic$errors))
  }

  invisible(NULL)
}
