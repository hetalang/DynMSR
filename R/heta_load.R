#' Load a Heta project as a DynMS platform
#'
#' Builds a Heta project with the DynMS export enabled, reads the generated
#' DynMS JSON file, and returns a DynMS platform object.
#'
#' Requires a compatible `heta-compiler` installation. The generated DynMS
#' export is written to a temporary directory and removed after loading.
#'
#' @param dir Heta project working directory.
#' @param source Path to the main source file, passed to [heta_build()].
#' @param type Source file type, passed to [heta_build()].
#' @param debug If `TRUE`, passed to [heta_build()].
#' @param units_check If `TRUE`, passed to [heta_build()].
#' @param meta_dir Meta directory path, passed to [heta_build()].
#' @param log_mode Log file saving mode, passed to [heta_build()].
#' @param log_path Log file path, passed to [heta_build()].
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
#' platform <- heta_load("_drafts/0-hello-world")
#' }
heta_load <- function(dir = ".",
                      source = NULL,
                      type = NULL,
                      debug = FALSE,
                      units_check = FALSE,
                      meta_dir = NULL,
                      log_mode = NULL,
                      log_path = NULL,
                      declaration = NULL,
                      log_level = NULL,
                      skip_updates = FALSE) {
  temp_dist <- tempfile("dynmsr-heta-dist-")
  dir.create(temp_dist, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(temp_dist, recursive = TRUE, force = TRUE), add = TRUE)

  heta_build(
    dir = dir,
    source = source,
    type = type,
    debug = debug,
    units_check = units_check,
    dist_dir = temp_dist,
    meta_dir = meta_dir,
    log_mode = log_mode,
    log_path = log_path,
    declaration = declaration,
    log_level = log_level,
    skip_updates = skip_updates,
    export = "DynMS"
  )

  dynms_path <- file.path(temp_dist, "dynms", "output.dynms.json")
  if (!file.exists(dynms_path)) {
    stop("Heta compiler did not create DynMS output: ", dynms_path, call. = FALSE)
  }

  dynms_load(dynms_path)
}
