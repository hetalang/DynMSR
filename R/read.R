#' Read a DynMS JSON file
#'
#' Reads a DynMS JSON file into an R list. DynMS documents are parsed with
#' `jsonlite::fromJSON(..., simplifyVector = FALSE)` to preserve the document
#' structure.
#'
#' @param path Path to a DynMS JSON file.
#'
#' @return An R list parsed from JSON.
#' @export
#'
#' @examples
#' path <- tempfile(fileext = ".json")
#' jsonlite::write_json(
#'   list(dynms = "0.1.0", models = list()),
#'   path,
#'   auto_unbox = TRUE
#' )
#' try(dynms_read(path))
dynms_read <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    stop("`path` must be a single file path.", call. = FALSE)
  }

  if (!file.exists(path)) {
    stop("DynMS file does not exist: ", path, call. = FALSE)
  }

  output <- jsonlite::fromJSON(path, simplifyVector = FALSE)


  return(output)
}

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
