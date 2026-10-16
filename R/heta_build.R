#' Build a Heta project
#'
#' Runs `heta build` for a Heta project directory. The arguments map directly
#' to Heta compiler CLI options, for example `units_check = TRUE` adds
#' `--units-check`.
#'
#' @details
#' Requires a `heta` command that satisfies DynMSR's bundled compatibility
#' rule. Use [heta_check()] to inspect availability and the supported version
#' range before building. Compiler output paths are placed under `output_dir`:
#' `dist/`, `meta/`, and, when selected by `log_mode`, `build.log`. The output
#' directory must be supplied explicitly and remains available after the build.
#'
#' @param dir Project working directory passed as the final CLI argument.
#' @param output_dir Directory for all compiler output. Required. Use
#'   `output_dir = dir` to place output under the project directory.
#' @param source Path to the main source file, passed as `--source`.
#' @param type Source file type, passed as `--type`.
#' @param debug If `TRUE`, add `--debug`.
#' @param units_check If `TRUE`, add `--units-check`.
#' @param log_mode Log file saving mode, passed as `--log-mode`. Use `"always"`
#'   to write `build.log` after a successful build.
#' @param declaration Declaration file path without extension, passed as
#'   `--declaration`.
#' @param log_level Log level, passed as `--log-level`.
#' @param skip_updates If `TRUE`, add `--skip-updates`.
#' @param export Export format specification, passed as `--export`.
#'
#' @return Invisibly returns a list with the command, arguments, exit status,
#'   captured output, and `output_dir`.
#' @export
#'
#' @examples
#' \dontrun{
#' project_dir <- "path/to/your/heta-project"
#' # Save exports and build.log in the project directory.
#' heta_build(project_dir, output_dir = project_dir, export = "SBML",
#'            log_mode = "always")
#' }
heta_build <- function(dir,
                       output_dir,
                       source = NULL,
                       type = NULL,
                       debug = FALSE,
                       units_check = FALSE,
                       log_mode = NULL,
                       declaration = NULL,
                       log_level = NULL,
                       skip_updates = FALSE,
                       export = NULL) {
  if (missing(dir) || !is.character(dir) || length(dir) != 1L || is.na(dir) || !nzchar(dir)) {
    stop("`dir` must be a single non-empty directory path.", call. = FALSE)
  }
  if (missing(output_dir) || is.null(output_dir)) {
    stop("`output_dir` must be a single non-empty directory path.", call. = FALSE)
  }

  heta <- heta_check()
  if (!isTRUE(heta$supported)) {
    stop(heta$message, call. = FALSE)
  }
  output_dir <- heta_output_dir(output_dir)

  args <- c(
    "build",
    heta_cli_option("--source", source),
    heta_cli_option("--type", type),
    heta_cli_flag("--debug", debug),
    heta_cli_flag("--units-check", units_check),
    heta_cli_option("--dist-dir", file.path(output_dir, "dist")),
    heta_cli_option("--meta-dir", file.path(output_dir, "meta")),
    heta_cli_option("--log-mode", log_mode),
    heta_cli_option("--log-path", file.path(output_dir, "build.log")),
    heta_cli_option("--declaration", declaration),
    heta_cli_option("--log-level", log_level),
    heta_cli_flag("--skip-updates", skip_updates),
    heta_cli_option("--export", export),
    dir
  )

  output <- tryCatch(
    heta_run_command(args),
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
    output = output_text,
    output_dir = output_dir
  )

  if (!identical(result$status, 0L)) {
    stop("Heta compiler build failed.", call. = FALSE)
  }

  invisible(result)
}

heta_output_dir <- function(output_dir) {
  if (!is.character(output_dir) || length(output_dir) != 1L ||
      is.na(output_dir) || !nzchar(output_dir)) {
    stop("`output_dir` must be a single non-empty directory path.", call. = FALSE)
  }

  if (!dir.exists(output_dir) &&
      !dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)) {
    stop("Could not create Heta output directory: ", output_dir, call. = FALSE)
  }

  normalizePath(output_dir, winslash = "/", mustWork = TRUE)
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
