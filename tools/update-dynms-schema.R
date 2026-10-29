#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

config_path <- file.path("inst", "config", "dynms.json")
json_schema_meta_url <- "https://json-schema.org/draft/2020-12/schema"

download_file <- function(url, dest) {
  tryCatch(
    {
      utils::download.file(
        url,
        dest,
        mode = "wb",
        quiet = TRUE,
        method = if (capabilities("libcurl")) "libcurl" else "auto"
      )
      NULL
    },
    error = function(e) conditionMessage(e),
    warning = function(w) conditionMessage(w)
  )
}

validate_json_schema <- function(schema_path) {
  message("Validating DynMS schema with AJV.")

  schema <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
  if (!identical(schema[["$schema"]], json_schema_meta_url)) {
    stop(
      paste(
        "DynMS schema must declare JSON Schema draft 2020-12.",
        "",
        "Expected `$schema`:",
        json_schema_meta_url,
        "",
        "The existing local schema was not modified.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  tryCatch(
    {
      jsonvalidate::json_validator(
        schema = schema_path,
        engine = "ajv"
      )
      invisible(TRUE)
    },
    error = function(e) {
      stop(
        paste(
          "DynMS schema could not be compiled by AJV as JSON Schema draft 2020-12.",
          "",
          "Reason:",
          conditionMessage(e),
          "",
          "The existing local schema was not modified.",
          sep = "\n"
        ),
        call. = FALSE
      )
    }
  )
}

if (!file.exists(config_path)) {
  stop("Schema source config was not found: ", config_path, call. = FALSE)
}

versions <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)$versions
if (!is.list(versions) || length(versions) == 0L ||
    is.null(names(versions)) || any(!nzchar(names(versions)))) {
  stop("DynMS config must contain named `versions` entries.", call. = FALSE)
}

version_args <- sub("^--version=", "", args[grepl("^--version=", args)])
if (length(version_args) > 1L || (length(version_args) == 1L && !nzchar(version_args))) {
  stop("Specify one non-empty `--version=VERSION` argument.", call. = FALSE)
}
if (length(version_args) == 0L) {
  if (length(versions) != 1L) {
    stop("Specify `--version=VERSION`. Available versions: ",
         paste(names(versions), collapse = ", "), call. = FALSE)
  }
  version <- names(versions)[[1]]
} else {
  version <- version_args[[1]]
}

config <- versions[[version]]
if (is.null(config)) {
  stop("Unsupported DynMS version: ", version, call. = FALSE)
}
if (!is.list(config)) {
  stop("DynMS version entry must contain `source` and `target` strings.", call. = FALSE)
}

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
  download_error <- download_file(config$source, tmp)

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
        "If needed, set `source` for this version in inst/config/dynms.json",
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

if (!identical(schema$properties$dynms$const, version)) {
  stop("DynMS schema version does not match config version ", version,
       ". The existing local schema was not modified.", call. = FALSE)
}

validate_json_schema(tmp)

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
