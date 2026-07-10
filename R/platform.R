new_platform <- function(raw_platform) {
  if (!is.list(raw_platform)) {
    stop("`raw_platform` must be a DynMS platform represented as an R list.", call. = FALSE)
  }

  platform <- raw_platform
  platform$models <- lapply(platform$models %||% list(), new_model)
  structure(platform, class = c("platform", "list"))
}

new_model <- function(raw_model) {
  if (!is.list(raw_model)) {
    stop("Each platform model must be represented as an R list.", call. = FALSE)
  }

  structure(raw_model, class = c("model", "list"))
}
