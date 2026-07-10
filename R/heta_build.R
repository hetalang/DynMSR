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
  if (!isTRUE(heta$available)) {
    stop(
      paste(
        "Heta compiler is not available.",
        heta$output,
        sep = "\n"
      ),
      call. = FALSE
    )
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
