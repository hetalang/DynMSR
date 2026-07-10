new_platform <- function(raw_platform) {
  if (!is.list(raw_platform)) {
    stop("`raw_platform` must be a DynMS platform represented as an R list.", call. = FALSE)
  }

  raw_platform
}
