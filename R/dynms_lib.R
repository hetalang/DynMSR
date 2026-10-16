#' Locate bundled DynMS examples
#'
#' Returns the available example names or the path to one bundled DynMS JSON
#' file. Use [dynms_load()] to load the selected example.
#'
#' @param name Name of a bundled example. If `NULL`, returns all available
#'   names.
#'
#' @return If `name` is `NULL`, a character vector of example names. Otherwise,
#'   the path to the selected DynMS JSON file.
#' @export
#'
#' @examples
#' dynms_lib()
#' platform <- dynms_load(dynms_lib("first-order-decay"))
dynms_lib <- function(name = NULL) {
  index_path <- system.file(
    "extdata", "dynms", "index.json",
    package = "DynMSR",
    mustWork = TRUE
  )
  index <- jsonlite::fromJSON(index_path, simplifyVector = FALSE)
  examples <- index$examples
  names <- vapply(examples, `[[`, character(1), "id")

  if (is.null(name)) {
    return(names)
  }

  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    stop("`name` must be a single bundled DynMS example name.", call. = FALSE)
  }
  if (!name %in% names) {
    stop(
      "Unknown bundled DynMS example: ", name,
      ". Available examples: ", paste(names, collapse = ", "), ".",
      call. = FALSE
    )
  }

  entry <- examples[[match(name, names)]]
  system.file(
    "extdata", "dynms", entry$file,
    package = "DynMSR",
    mustWork = TRUE
  )
}
