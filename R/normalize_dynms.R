#' Normalize a DynMS object
#'
#' Converts raw DynMS content into a stable internal representation used by
#' backend exporters.
#'
#' @param x An R list representing a DynMS object.
#'
#' @return An R list with normalized DynMS platform content.
#' @export
dynms_normalize <- function(x) {
  if (!is.list(x)) {
    stop("`x` must be a DynMS object represented as an R list.", call. = FALSE)
  }

  models <- x$models
  if (!is.list(models) || length(models) == 0L) {
    stop("DynMS object must contain at least one model in `models`.", call. = FALSE)
  }

  list(
    version = x$dynms %||% x$version %||% NA_character_,
    models = lapply(models, normalize_model)
  )
}

normalize_model <- function(model) {
  if (!is.list(model)) {
    stop("Each DynMS model must be an object.", call. = FALSE)
  }

  id <- model$id %||% model$name
  if (is.null(id) || !is.character(id) || length(id) != 1L || !nzchar(id)) {
    stop("Each DynMS model must have a non-empty `id` or `name`.", call. = FALSE)
  }

  states <- normalize_named_collection(model$states %||% list(), "states")
  parameters <- normalize_named_collection(
    model$parameters %||% model$constants %||% list(),
    "parameters"
  )

  list(
    id = id,
    states = states,
    parameters = parameters,
    assignments = normalize_named_collection(model$assignments %||% list(), "assignments"),
    odes = model$odes %||% model$derivatives %||% model$equations %||% list(),
    outputs = normalize_outputs(model$outputs %||% model$observables %||% list()),
    events = model$events %||% list(),
    raw = model
  )
}

normalize_outputs <- function(x) {
  if (!is.list(x)) {
    stop("Model field `outputs` must be a list.", call. = FALSE)
  }

  if (length(x) == 0L) {
    return(list())
  }

  items <- lapply(x, function(item) {
    if (!is.list(item)) {
      stop("Each item in `outputs` must be an object.", call. = FALSE)
    }

    id <- item$id %||% item$name %||% item$symbol
    if (is.null(id) || !is.character(id) || length(id) != 1L || !nzchar(id)) {
      stop("Each item in `outputs` must have a non-empty `id`, `name`, or `symbol`.", call. = FALSE)
    }

    item$id <- id
    item
  })

  ids <- vapply(items, `[[`, character(1), "id")
  duplicated_ids <- unique(ids[duplicated(ids)])
  if (length(duplicated_ids) > 0L) {
    stop(
      "Duplicate identifiers in `outputs`: ",
      paste(duplicated_ids, collapse = ", "),
      call. = FALSE
    )
  }

  names(items) <- ids
  items
}

normalize_named_collection <- function(x, field) {
  if (!is.list(x)) {
    stop("Model field `", field, "` must be a list.", call. = FALSE)
  }

  if (length(x) == 0L) {
    return(list())
  }

  items <- lapply(seq_along(x), function(i) {
    item <- x[[i]]
    if (!is.list(item)) {
      stop("Each item in `", field, "` must be an object.", call. = FALSE)
    }

    id <- item$id %||% item$name
    if (is.null(id) || !is.character(id) || length(id) != 1L || !nzchar(id)) {
      stop("Each item in `", field, "` must have a non-empty `id` or `name`.", call. = FALSE)
    }

    item$id <- id
    item
  })

  ids <- vapply(items, `[[`, character(1), "id")
  duplicated_ids <- unique(ids[duplicated(ids)])
  if (length(duplicated_ids) > 0L) {
    stop(
      "Duplicate identifiers in `", field, "`: ",
      paste(duplicated_ids, collapse = ", "),
      call. = FALSE
    )
  }

  names(items) <- ids
  items
}
