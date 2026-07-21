#' Build a Heta project
#'
#' Runs `heta build` for a Heta project directory. The arguments map directly
#' to Heta compiler CLI options, for example `units_check = TRUE` adds
#' `--units-check`.
#'
#' @param dir Project working directory passed as the final CLI argument.
#' @param source Path to the main source file, passed as `--source`.
#' @param type Source file type, passed as `--type`.
#' @param debug If `TRUE`, add `--debug`.
#' @param units_check If `TRUE`, add `--units-check`.
#' @param dist_dir Export directory path, passed as `--dist-dir`.
#' @param meta_dir Meta directory path, passed as `--meta-dir`.
#' @param log_mode Log file saving mode, passed as `--log-mode`.
#' @param log_path Log file path, passed as `--log-path`.
#' @param declaration Declaration file path without extension, passed as
#'   `--declaration`.
#' @param log_level Log level, passed as `--log-level`.
#' @param skip_updates If `TRUE`, add `--skip-updates`.
#' @param export Export format specification, passed as `--export`.
#'
#' @return Invisibly returns a list with the command, arguments, exit status,
#'   and captured output.
#' @export
#'
#' @examples
#' \dontrun{
#' heta_build("_drafts/0-hello-world", export = "DynMS")
#' }
heta_build <- function(dir = ".",
                       source = NULL,
                       type = NULL,
                       debug = FALSE,
                       units_check = FALSE,
                       dist_dir = NULL,
                       meta_dir = NULL,
                       log_mode = NULL,
                       log_path = NULL,
                       declaration = NULL,
                       log_level = NULL,
                       skip_updates = FALSE,
                       export = NULL) {
  if (!is.character(dir) || length(dir) != 1L || is.na(dir) || !nzchar(dir)) {
    stop("`dir` must be a single non-empty directory path.", call. = FALSE)
  }

  heta <- heta_check()
  if (!isTRUE(heta$supported)) {
    stop(heta$message, call. = FALSE)
  }

  args <- c(
    "build",
    heta_cli_option("--source", source),
    heta_cli_option("--type", type),
    heta_cli_flag("--debug", debug),
    heta_cli_flag("--units-check", units_check),
    heta_cli_option("--dist-dir", dist_dir),
    heta_cli_option("--meta-dir", meta_dir),
    heta_cli_option("--log-mode", log_mode),
    heta_cli_option("--log-path", log_path),
    heta_cli_option("--declaration", declaration),
    heta_cli_option("--log-level", log_level),
    heta_cli_flag("--skip-updates", skip_updates),
    heta_cli_option("--export", export),
    dir
  )

  output <- tryCatch(
    suppressWarnings(system2("heta", args, stdout = TRUE, stderr = TRUE)),
    error = identity
  )

  if (inherits(output, "error")) {
    stop(conditionMessage(output), call. = FALSE)
  }

  output_text <- paste(output, collapse = "\n")
  heta_message_output(output_text)

  status <- attr(output, "status") %||% 0L
  result <- list(
    command = "heta",
    args = args,
    status = as.integer(status),
    output = output_text
  )

  if (!identical(result$status, 0L)) {
    stop("Heta compiler build failed.", call. = FALSE)
  }

  invisible(result)
}

heta_cli_option <- function(option, value) {
  if (is.null(value)) {
    return(character())
  }

  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
    stop("`", option, "` value must be a single non-empty string.", call. = FALSE)
  }

  c(option, value)
}

heta_cli_flag <- function(option, value) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop("`", option, "` value must be a single TRUE or FALSE value.", call. = FALSE)
  }

  if (isTRUE(value)) {
    option
  } else {
    character()
  }
}

heta_message_output <- function(output) {
  if (!nzchar(output)) {
    return(invisible(NULL))
  }

  for (line in strsplit(output, "\n", fixed = TRUE)[[1]]) {
    if (nzchar(line)) {
      message(line)
    }
  }

  invisible(NULL)
}
