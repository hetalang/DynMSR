#!/usr/bin/env Rscript

# Manually refresh every bundled DynMS schema listed in inst/config/dynms.json.
# Sources may be URLs or local files. No package operation runs this script.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L || (length(args) == 1L && args != "--dry-run")) {
  stop("Only --dry-run is supported; all configured versions are updated together.",
       call. = FALSE)
}
dry_run <- length(args) == 1L

scalar_text <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
}

copy_file <- function(from, to) {
  isTRUE(tryCatch(file.copy(from, to, overwrite = TRUE), error = function(e) FALSE))
}

fetch_schema <- function(source, destination) {
  if (grepl("^https?://", source)) {
    status <- tryCatch(
      suppressWarnings(utils::download.file(source, destination, mode = "wb", quiet = TRUE)),
      error = function(e) NA_integer_
    )
    if (!identical(status, 0L)) {
      stop("Could not download schema from ", source, call. = FALSE)
    }
  } else if (!copy_file(source, destination)) {
    stop("Could not copy schema from ", source, call. = FALSE)
  }
}

check_schema <- function(path, version) {
  schema <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                     error = function(e) stop("Invalid JSON for DynMS ", version,
                                              ": ", conditionMessage(e), call. = FALSE))
  if (!identical(schema$`$schema`, "https://json-schema.org/draft/2020-12/schema") ||
      !scalar_text(schema$`$id`) ||
      !identical(schema$properties$dynms$const, version)) {
    stop("Schema metadata does not match DynMS ", version, call. = FALSE)
  }
  tryCatch(jsonvalidate::json_validator(path, engine = "ajv"),
           error = function(e) stop("Invalid schema for DynMS ", version,
                                    ": ", conditionMessage(e), call. = FALSE))
}

update_schemas <- function() {
  config <- jsonlite::fromJSON("inst/config/dynms.json", simplifyVector = FALSE)
  versions <- config$versions
  if (!is.list(versions) || !length(versions) ||
      is.null(names(versions)) || any(!nzchar(names(versions)))) {
    stop("inst/config/dynms.json must contain named versions.", call. = FALSE)
  }

  schema_dir <- normalizePath("inst/schema", winslash = "/", mustWork = TRUE)
  targets <- stages <- backups <- character(length(versions))
  on.exit(unlink(c(stages, backups)[nzchar(c(stages, backups))]), add = TRUE)

  for (i in seq_along(versions)) {
    version <- names(versions)[i]
    entry <- versions[[i]]
    if (!scalar_text(entry$source) || !scalar_text(entry$target)) {
      stop("DynMS ", version, " needs source and target fields.", call. = FALSE)
    }
    target <- normalizePath(entry$target, winslash = "/", mustWork = FALSE)
    if (!identical(tolower(dirname(target)), tolower(schema_dir)) ||
        !grepl("\\.json$", target, ignore.case = TRUE)) {
      stop("Target for DynMS ", version, " must be a JSON file in inst/schema.",
           call. = FALSE)
    }
    if (target %in% targets) {
      stop("Multiple DynMS versions share target ", target, call. = FALSE)
    }
    targets[i] <- target
    stages[i] <- tempfile(fileext = ".json")
    fetch_schema(entry$source, stages[i])
    check_schema(stages[i], version)
    message("Validated DynMS ", version)
  }

  if (dry_run) {
    message("Dry run: no bundled schemas changed.")
    return(invisible(NULL))
  }

  existed <- file.exists(targets)
  for (i in which(existed)) {
    backups[i] <- tempfile(fileext = ".json")
    if (!copy_file(targets[i], backups[i])) {
      stop("Could not back up ", targets[i], call. = FALSE)
    }
  }

  for (i in seq_along(targets)) {
    if (!copy_file(stages[i], targets[i])) {
      touched <- seq_len(i)
      restored <- vapply(touched, function(j) {
        if (existed[j]) copy_file(backups[j], targets[j])
        else !file.exists(targets[j]) || file.remove(targets[j])
      }, logical(1))
      if (!all(restored)) {
        stop("Could not update ", targets[i], "; rollback also failed for: ",
             paste(targets[touched][!restored], collapse = ", "), call. = FALSE)
      }
      stop("Could not update ", targets[i], "; previous schemas restored.",
           call. = FALSE)
    }
  }
  message("Updated ", length(targets), " bundled DynMS schemas.")
}

update_schemas()
