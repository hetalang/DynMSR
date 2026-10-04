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

#' Get one model from a platform
#'
#' Selects one model from a DynMS platform by numeric index or by name.
#'
#' @param platform A platform object returned by [dynms_load()],
#'   [heta_load()], or [sbml_load()].
#' @param model A single model index or model name.
#'
#' @return A model list.
#' @export
#'
#' @examples
#' \dontrun{
#' platform <- heta_load("_drafts/0-hello-world")
#' model <- get_model(platform, 2)
#' }
get_model <- function(platform, model) {
  if (!inherits(platform, "platform")) {
    stop("`platform` must be a DynMS platform object.", call. = FALSE)
  }
  if (missing(model)) {
    stop("`model` must be a model index or name.", call. = FALSE)
  }
  if (!is.numeric(model) && !is.character(model)) {
    stop("`model` must be a model index or name.", call. = FALSE)
  }
  if (length(model) != 1L || is.na(model)) {
    stop("`model` must be a single model index or name.", call. = FALSE)
  }

  if (is.numeric(model)) {
    if (model < 1L || model > length(platform$models) || model != as.integer(model)) {
      stop("Model index is out of range.", call. = FALSE)
    }

    return(platform$models[[as.integer(model)]])
  }

  if (!model %in% names(platform$models)) {
    stop("Model was not found: ", model, call. = FALSE)
  }

  platform$models[[model]]
}
