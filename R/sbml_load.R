#' Load an SBML file as a DynMS platform
#'
#' Builds one SBML file through Heta compiler with the DynMS export enabled,
#' reads the generated DynMS JSON file, and returns a DynMS platform object.
#'
#' @param path Path to an SBML file.
#' @param debug If `TRUE`, passed to [heta_load()].
#' @param units_check If `TRUE`, passed to [heta_load()].
#' @param meta_dir Meta directory path, passed to [heta_load()].
#' @param log_mode Log file saving mode, passed to [heta_load()].
#' @param log_path Log file path, passed to [heta_load()].
#' @param declaration Declaration file path without extension, passed to
#'   [heta_load()].
#' @param log_level Log level, passed to [heta_load()].
#' @param skip_updates If `TRUE`, passed to [heta_load()].
#'
#' @return A platform list. Use [get_model()] or ordinary list access such as
#'   `platform$models[[1]]` to select one model.
#' @export
#'
#' @examples
#' \dontrun{
#' platform <- sbml_load("model.xml")
#' }
sbml_load <- function(path,
                      debug = FALSE,
                      units_check = FALSE,
                      meta_dir = NULL,
                      log_mode = NULL,
                      log_path = NULL,
                      declaration = NULL,
                      log_level = NULL,
                      skip_updates = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("`path` must be a single non-empty file path.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("SBML file does not exist: ", path, call. = FALSE)
  }

  normalized_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  dir <- dirname(normalized_path)
  source <- basename(normalized_path)

  heta_load(
    dir = dir,
    source = source,
    type = "sbml",
    debug = debug,
    units_check = units_check,
    meta_dir = meta_dir,
    log_mode = log_mode,
    log_path = log_path,
    declaration = declaration,
    log_level = log_level,
    skip_updates = skip_updates
  )
}
