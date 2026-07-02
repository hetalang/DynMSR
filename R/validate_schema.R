#' Get the bundled DynMS JSON Schema path
#'
#' @return Path to the DynMS JSON Schema installed with DynMSR.
#' @export
dynms_schema_path <- function() {
  path <- system.file("schema", "dynms.schema.json", package = "DynMSR")

  if (!nzchar(path)) {
    stop("DynMS schema file was not found in the installed package.", call. = FALSE)
  }

  path
}

#' Validate a DynMS document against the JSON Schema
#'
#' Validates a DynMS document against a JSON Schema. The document can be passed
#' as a file path or as the raw R list returned by [dynms_read()]. By default,
#' the schema bundled with DynMSR is used. Validation uses the `ajv` engine
#' because the bundled schema uses modern JSON Schema features.
#'
#' @param x Path to a DynMS JSON file, or the raw R list returned by
#'   [dynms_read()].
#' @param error Whether validation errors should be raised as R errors.
#' @param verbose Whether to return verbose validation output from
#'   `jsonvalidate`.
#'
#' @return `TRUE` or `FALSE`, unless verbose validation is requested.
#' @export
dynms_validate_schema <- function(x, error = FALSE, verbose = FALSE) {
  schema <- dynms_schema_path()

  if (!is.character(schema) || length(schema) != 1L || !file.exists(schema)) {
    stop("`schema` must be a path to an existing JSON Schema file.", call. = FALSE)
  }

  json <- dynms_json_input(x)
  jsonvalidate::json_validate(
    json = json,
    schema = schema,
    error = error,
    verbose = verbose,
    engine = "ajv"
  )
}

# XXX: We convert the input back to JSON here, mybe this is not the best approach. 
# We can validate just from file or file content inside dynms_read() function.
dynms_json_input <- function(x) {
  if (is.character(x) && length(x) == 1L && file.exists(x)) {
    return(x)
  }

  if (is.list(x)) {
    return(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
  }

  stop("`x` must be a DynMS file path or an R list.", call. = FALSE)
}
