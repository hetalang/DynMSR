#' Load a Heta project as a DynMS platform
#'
#' Builds a Heta project with the DynMS export enabled, reads the generated
#' DynMS JSON file, and returns a DynMS platform object.
#'
#' Requires a compatible `heta-compiler` installation. Compiler output is
#' placed under `output_dir` in `dist/`, `meta/`, and, when selected by
#' `log_mode`, `build.log`. When `output_dir` is omitted, a temporary directory
#' is removed after loading.
#'
#' @param dir Heta project working directory.
#' @param output_dir Optional directory for compiler output. If omitted, a
#'   temporary directory is used and removed after loading.
#' @param source Path to the main source file, passed to [heta_build()].
#' @param type Source file type, passed to [heta_build()].
#' @param debug If `TRUE`, passed to [heta_build()].
#' @param units_check If `TRUE`, passed to [heta_build()].
#' @param log_mode Log file saving mode, passed to [heta_build()]. Use
#'   `"always"` to write `build.log` after a successful build.
#' @param declaration Declaration file path without extension, passed to
#'   [heta_build()].
#' @param log_level Log level, passed to [heta_build()].
#' @param skip_updates If `TRUE`, passed to [heta_build()].
#'
#' @return A platform list. Use [get_model()] or ordinary list access such as
#'   `platform$models[[1]]` to select one model.
#' @export
#'
#' @examples
#' \dontrun{
#' platform <- heta_load("path/to/your/heta-project")
#' model <- get_model(platform, 1)
#' compiled <- build_mrgsolve(model, quiet = TRUE)
#' simulation <- mrgsolve::mrgsim_df(compiled, end = 24, delta = 0.1)
#' }
heta_load <- function(dir,
                      output_dir = NULL,
                      source = NULL,
                      type = NULL,
                      debug = FALSE,
                      units_check = FALSE,
                      log_mode = NULL,
                      declaration = NULL,
                      log_level = NULL,
                      skip_updates = FALSE) {
  if (missing(dir) || !is.character(dir) || length(dir) != 1L || is.na(dir) || !nzchar(dir)) {
    stop("`dir` must be a single non-empty directory path.", call. = FALSE)
  }
  if (is.null(output_dir)) {
    output_dir <- tempfile("dynmsr-heta-")
    if (!dir.create(output_dir)) {
      stop("Could not create a temporary Heta output directory.", call. = FALSE)
    }
    on.exit(unlink(output_dir, recursive = TRUE, force = TRUE), add = TRUE)
  }
  output_dir <- heta_output_dir(output_dir)

  heta_build(
    dir = dir,
    output_dir = output_dir,
    source = source,
    type = type,
    debug = debug,
    units_check = units_check,
    log_mode = log_mode,
    declaration = declaration,
    log_level = log_level,
    skip_updates = skip_updates,
    export = "DynMS"
  )

  dynms_path <- file.path(output_dir, "dist", "dynms", "output.dynms.json")
  if (!file.exists(dynms_path)) {
    stop("Heta compiler did not create DynMS output: ", dynms_path, call. = FALSE)
  }

  dynms_load(dynms_path)
}
