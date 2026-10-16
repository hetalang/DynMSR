#' Load an SBML file as a DynMS platform
#'
#' Builds one SBML file through Heta compiler with the DynMS export enabled,
#' reads the generated DynMS JSON file, and returns a DynMS platform object.
#'
#' Requires a compatible `heta-compiler` installation. The generated DynMS
#' export is written to a temporary directory and removed after loading unless
#' `output_dir` is supplied.
#'
#' @param path Path to an SBML file.
#' @param output_dir Optional directory for compiler output, passed to
#'   [heta_load()].
#' @param debug If `TRUE`, passed to [heta_load()].
#' @param units_check If `TRUE`, passed to [heta_load()].
#' @param log_mode Log file saving mode, passed to [heta_load()].
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
#' sbml_path <- "path/to/your/model.xml"
#' platform <- sbml_load(sbml_path)
#' model <- get_model(platform, 1)
#' compiled <- build_mrgsolve(model, quiet = TRUE)
#' simulation <- mrgsolve::mrgsim_df(compiled, end = 24, delta = 0.1)
#' }
sbml_load <- function(path,
                      output_dir = NULL,
                      debug = FALSE,
                      units_check = FALSE,
                      log_mode = NULL,
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
    output_dir = output_dir,
    source = source,
    type = "sbml",
    debug = debug,
    units_check = units_check,
    log_mode = log_mode,
    declaration = declaration,
    log_level = log_level,
    skip_updates = skip_updates
  )
}
