#' Load a DynMS platform
#'
#' Reads a DynMS JSON file, validates it against the bundled schema, runs
#' backend-independent semantic validation, and returns a platform list.
#'
#' @param path Path to a DynMS JSON file.
#'
#' @return A platform list. Use `platform$models[[i]]` to select one model for
#'   backend-specific operations.
#' @export
dynms_load <- function(path) {
  raw_platform <- dynms_read(path)
  dynms_validate_schema(raw_platform, error = TRUE)
  dynms_validate_semantic(raw_platform, error = TRUE)
  new_platform(raw_platform)
}
