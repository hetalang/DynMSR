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
