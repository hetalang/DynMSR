#' Check Heta compiler availability
#'
#' Checks whether the `heta` command is available, can report its version with
#' `heta --version`, and satisfies the bundled DynMSR compatibility rule.
#'
#' @return A list with `available`, `supported`, `command`, `version`,
#'   `supported_version`, `installation_url`, `output`, and `message` fields.
#' @export
#'
#' @examples
#' heta_check()
heta_check <- function() {
  config <- heta_compiler_config()
  output <- tryCatch(
    suppressWarnings(system2("heta", "--version", stdout = TRUE, stderr = TRUE)),
    error = identity
  )

  if (inherits(output, "error")) {
    return(heta_check_result(
      available = FALSE,
      supported = FALSE,
      version = NA_character_,
      output = conditionMessage(output),
      message = paste(
        "Heta compiler is not available.",
        heta_installation_message(config)
      ),
      config = config
    ))
  }

  status <- attr(output, "status") %||% 0L
  output_text <- paste(output, collapse = "\n")
  if (!identical(as.integer(status), 0L)) {
    return(heta_check_result(
      available = FALSE,
      supported = FALSE,
      version = NA_character_,
      output = output_text,
      message = paste(
        "Heta compiler could not report its version.",
        heta_installation_message(config)
      ),
      config = config
    ))
  }

  version <- heta_parse_version(output_text)
  if (is.na(version)) {
    return(heta_check_result(
      available = TRUE,
      supported = FALSE,
      version = NA_character_,
      output = output_text,
      message = paste(
        "Heta compiler version could not be determined.",
        heta_installation_message(config)
      ),
      config = config
    ))
  }

  supported <- heta_version_supported(version, config$supportedVersion)
  message <- if (supported) {
    paste0("Heta compiler version ", version, " is supported.")
  } else {
    paste0(
      "Unsupported heta-compiler version ", version, ". ",
      heta_installation_message(config)
    )
  }

  heta_check_result(
    available = TRUE,
    supported = supported,
    version = version,
    output = output_text,
    message = message,
    config = config
  )
}

heta_parse_version <- function(output) {
  version <- regmatches(
    output,
    regexpr(
      "[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?",
      output,
      perl = TRUE
    )
  )

  if (length(version) == 0L || !nzchar(version)) {
    return(NA_character_)
  }

  version
}

.heta_compiler_config_path <- function() {
  system.file(
    "config",
    "heta-compiler.json",
    package = "DynMSR",
    mustWork = TRUE
  )
}

heta_compiler_config <- function() {
  config <- jsonlite::fromJSON(.heta_compiler_config_path())
  required <- c("package", "supportedVersion", "testVersion", "installationUrl")

  if (!is.list(config) || !all(required %in% names(config))) {
    stop("Bundled Heta compiler configuration is invalid.", call. = FALSE)
  }

  config
}

heta_check_result <- function(available,
                              supported,
                              version,
                              output,
                              message,
                              config) {
  list(
    available = available,
    supported = supported,
    command = "heta",
    version = version,
    supported_version = config$supportedVersion,
    installation_url = config$installationUrl,
    output = output,
    message = message
  )
}

heta_installation_message <- function(config) {
  paste0(
    "DynMSR requires heta-compiler compatible with ",
    config$supportedVersion,
    ". See ",
    config$installationUrl
  )
}

heta_version_supported <- function(version, range) {
  range_match <- regmatches(
    range,
    regexec("^\\^([0-9]+)\\.([0-9]+)\\.([0-9]+)$", range, perl = TRUE)
  )[[1]]

  if (length(range_match) == 0L) {
    stop("Unsupported bundled Heta compiler version range: ", range, call. = FALSE)
  }

  candidate <- heta_semver_components(version)
  if (is.null(candidate) || !is.na(candidate$prerelease)) {
    return(FALSE)
  }

  minimum <- list(
    major = as.integer(range_match[[2]]),
    minor = as.integer(range_match[[3]]),
    patch = as.integer(range_match[[4]]),
    prerelease = NA_character_
  )
  upper <- heta_caret_upper_bound(minimum)

  heta_compare_semver(candidate, minimum) >= 0L &&
    heta_compare_semver(candidate, upper) < 0L
}

heta_semver_components <- function(version) {
  match <- regmatches(
    version,
    regexec(
      "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([0-9A-Za-z.-]+))?(?:\\+[0-9A-Za-z.-]+)?$",
      version,
      perl = TRUE
    )
  )[[1]]

  if (length(match) == 0L) {
    return(NULL)
  }

  list(
    major = as.integer(match[[2]]),
    minor = as.integer(match[[3]]),
    patch = as.integer(match[[4]]),
    prerelease = if (length(match) >= 5L && nzchar(match[[5]])) match[[5]] else NA_character_
  )
}

heta_caret_upper_bound <- function(version) {
  if (version$major > 0L) {
    return(list(major = version$major + 1L, minor = 0L, patch = 0L, prerelease = NA_character_))
  }

  if (version$minor > 0L) {
    return(list(major = 0L, minor = version$minor + 1L, patch = 0L, prerelease = NA_character_))
  }

  list(major = 0L, minor = 0L, patch = version$patch + 1L, prerelease = NA_character_)
}

heta_compare_semver <- function(left, right) {
  for (field in c("major", "minor", "patch")) {
    if (left[[field]] < right[[field]]) {
      return(-1L)
    }
    if (left[[field]] > right[[field]]) {
      return(1L)
    }
  }

  0L
}
