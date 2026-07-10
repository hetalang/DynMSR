.dynms_schema_path <- system.file(
  "schema",
  "dynms.schema.json",
  package = "DynMSR",
  mustWork = TRUE
)

#' Validate a DynMS document against the JSON Schema
#'
#' Validates a DynMS document against a JSON Schema. The document can be passed
#' as a file path or as the raw R list returned by [dynms_read()]. By default,
#' the schema bundled with DynMSR is used. Validation uses the `ajv` engine
#' because the bundled schema uses modern JSON Schema features.
#'
#' @param x Path to a DynMS JSON file, or the raw R list returned by
#'   [dynms_read()].
#' @param error Whether schema validation errors should be raised as one R
#'   error after all available issues are collected.
#'
#' @return A list with `valid`, `errors`, and `warnings` fields.
#' @export
dynms_validate_schema <- function(x, error = FALSE) {
  json <- dynms_json_input(x)
  validation <- jsonvalidate::json_validate(
    json = json,
    schema = .dynms_schema_path,
    error = FALSE,
    verbose = TRUE,
    greedy = TRUE,
    engine = "ajv"
  )

  errors <- schema_validation_errors(attr(validation, "errors"))
  result <- list(
    valid = isTRUE(unname(validation)),
    errors = errors,
    warnings = list()
  )

  if (!result$valid && isTRUE(error)) {
    stop(format_schema_errors(errors), call. = FALSE)
  }

  result
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

schema_validation_errors <- function(errors) {
  if (is.null(errors) || nrow(errors) == 0L) {
    return(list())
  }

  lapply(seq_len(nrow(errors)), function(i) {
    row <- errors[i, , drop = FALSE]
    path <- row[["instancePath"]]

    if (is.null(path) || is.na(path) || !nzchar(path)) {
      path <- "$"
    } else {
      path <- paste0("$", path)
    }

    list(
      path = path,
      code = row[["keyword"]],
      message = row[["message"]],
      schema_path = row[["schemaPath"]]
    )
  })
}

format_schema_errors <- function(errors) {
  lines <- vapply(
    errors,
    function(issue) {
      paste0(issue$path, " [", issue$code, "]: ", issue$message)
    },
    character(1)
  )

  paste(
    "DynMS schema validation failed:",
    paste(lines, collapse = "\n"),
    sep = "\n"
  )
}
