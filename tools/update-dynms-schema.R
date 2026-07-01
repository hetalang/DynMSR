#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

config_path <- file.path("inst", "schema", "dynms.schema.source.json")

if (!file.exists(config_path)) {
  stop("Schema source config was not found: ", config_path, call. = FALSE)
}

config <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)

if (!is.character(config$source) || length(config$source) != 1L || !nzchar(config$source)) {
  stop("Schema source config must contain a non-empty `source` string.", call. = FALSE)
}

if (!is.character(config$target) || length(config$target) != 1L || !nzchar(config$target)) {
  stop("Schema source config must contain a non-empty `target` string.", call. = FALSE)
}

target <- normalizePath(config$target, winslash = "/", mustWork = FALSE)
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)

if (!startsWith(target, paste0(repo_root, "/"))) {
  stop("Refusing to write schema outside the repository: ", config$target, call. = FALSE)
}

tmp <- tempfile(fileext = ".json")
on.exit(unlink(tmp), add = TRUE)

is_url <- grepl("^https?://", config$source)

if (is_url) {
  message("Downloading DynMS schema from: ", config$source)
  download_error <- tryCatch(
    {
      utils::download.file(
        config$source,
        tmp,
        mode = "wb",
        quiet = TRUE,
        method = if (capabilities("libcurl")) "libcurl" else "auto"
      )
      NULL
    },
    error = function(e) conditionMessage(e),
    warning = function(w) conditionMessage(w)
  )

  if (!is.null(download_error)) {
    stop(
      paste(
        "Could not download DynMS schema from:",
        config$source,
        "",
        "Reason:",
        download_error,
        "",
        "Check internet access, DNS, proxy, or GitHub availability.",
        "The existing local schema was not modified.",
        "If needed, set `source` in inst/schema/dynms.schema.source.json",
        "to a local schema file path and run this command again.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }
} else {
  source_path <- normalizePath(config$source, winslash = "/", mustWork = FALSE)
  if (!file.exists(source_path)) {
    stop("Local schema source file does not exist: ", config$source, call. = FALSE)
  }

  message("Reading DynMS schema from local file: ", config$source)
  copied <- file.copy(source_path, tmp, overwrite = TRUE)
  if (!isTRUE(copied)) {
    stop("Could not copy local schema source file: ", config$source, call. = FALSE)
  }
}

schema <- tryCatch(
  jsonlite::fromJSON(tmp, simplifyVector = FALSE),
  error = function(e) {
    stop("Schema source is not valid JSON: ", conditionMessage(e), call. = FALSE)
  }
)

if (!is.list(schema) || is.null(schema[["$schema"]]) || is.null(schema[["$id"]])) {
  stop("Downloaded file does not look like a JSON Schema document.", call. = FALSE)
}

if (isTRUE(dry_run)) {
  message("Dry run complete; target was not modified: ", config$target)
  quit(status = 0)
}

target_dir <- dirname(target)
if (!dir.exists(target_dir)) {
  dir.create(target_dir, recursive = TRUE)
}

copied <- file.copy(tmp, target, overwrite = TRUE)
if (!isTRUE(copied)) {
  stop("Could not update local DynMS schema: ", config$target, call. = FALSE)
}
message("Updated local DynMS schema: ", config$target)
