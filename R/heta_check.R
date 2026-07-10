#' Check Heta compiler availability
#'
#' Checks whether the `heta` command is available and can report its version
#' with `heta --version`.
#'
#' @return A list with `available`, `command`, `version`, and `output` fields.
#' @export
#'
#' @examples
#' heta_check()
heta_check <- function() {
  output <- tryCatch(
    suppressWarnings(system2("heta", "--version", stdout = TRUE, stderr = TRUE)),
    error = identity
  )

  if (inherits(output, "error")) {
    return(list(
      available = FALSE,
      command = "heta",
      version = NA_character_,
      output = conditionMessage(output)
    ))
  }

  status <- attr(output, "status") %||% 0L
  output_text <- paste(output, collapse = "\n")
  if (!identical(as.integer(status), 0L)) {
    return(list(
      available = FALSE,
      command = "heta",
      version = NA_character_,
      output = output_text
    ))
  }

  list(
    available = TRUE,
    command = "heta",
    version = heta_parse_version(output_text),
    output = output_text
  )
}

heta_parse_version <- function(output) {
  version <- regmatches(
    output,
    regexpr("[0-9]+(\\.[0-9]+)+([.-][A-Za-z0-9]+)?", output, perl = TRUE)
  )

  if (length(version) == 0L || !nzchar(version)) {
    return(NA_character_)
  }

  version
}
