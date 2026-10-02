
#' Compile a DynMS model with mrgsolve
#'
#' Generates an mrgsolve model source file and compiles it with `mrgsolve`.
#' The `mrgsolve` package is optional and is required only when this function is
#' called.
#'
#' @param model A model list, such as one element of `platform$models`.
#' @param filepath Path where the intermediate mrgsolve model source should be
#'   written. If omitted, a temporary `.mod` file is created.
#' @param observables Optional character vector of additional model symbols to
#'   return from mrgsolve. Dynamic states and symbols already listed in the
#'   DynMS model's `observables` are skipped. Every requested symbol must exist
#'   as a DynMS constant, dynamic state, static state, or assignment. Symbols
#'   renamed for mrgsolve are returned under their generated backend names.
#' @param ... Additional arguments passed to [mrgsolve::mread()].
#'
#' @return A compiled mrgsolve model object.
#' @export
build_mrgsolve <- function(
  model, filepath = tempfile(fileext = ".mod"), observables = NULL, ...
) {
  check_mrgsolve_model(model, "build_mrgsolve")
  capture <- prepare_mrgsolve_observable_capture(model, observables)
  dots <- list(...)
  if ("capture" %in% names(dots)) {
    stop(
      "Use `observables` instead of the mrgsolve-specific `capture` argument.",
      call. = FALSE
    )
  }

  if (!requireNamespace("mrgsolve", quietly = TRUE)) {
    stop(
      paste(
        "Package `mrgsolve` is required to compile DynMS models with mrgsolve.",
        "Install it with `install.packages(\"mrgsolve\")`.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  path <- write_mrgsolve(model, filepath)
  do.call(
    mrgsolve::mread,
    c(
      list(
        model = tools::file_path_sans_ext(basename(path)),
        project = dirname(path),
        file = basename(path),
        capture = capture
      ),
      dots
    )
  )
}

prepare_mrgsolve_observable_capture <- function(model, observables) {
  if (is.null(observables)) {
    return(character())
  }
  if (!is.character(observables) || anyNA(observables) || any(!nzchar(observables))) {
    stop("`observables` must be a character vector of non-empty identifiers.", call. = FALSE)
  }

  observables <- unique(observables)
  identifiers <- c(
    collect_identifiers(model$constants, "id"),
    collect_identifiers(model$dynamic, "id"),
    collect_identifiers(model$static, "id"),
    collect_identifiers(model$assignments, "id")
  )
  unknown <- setdiff(observables, identifiers)
  if (length(unknown) > 0L) {
    stop(
      "`observables` contains identifier(s) that do not exist in the model: ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }

  dynamic <- collect_identifiers(model$dynamic, "id")
  existing <- vapply(model$observables %||% list(), `[[`, character(1), "symbol")
  capture <- setdiff(observables, c(dynamic, existing))
  identifier_map <- build_mrgsolve_identifier_map(model)
  unname(vapply(capture, function(identifier) {
    if (identifier %in% names(identifier_map)) {
      unname(identifier_map[[identifier]])
    } else {
      identifier
    }
  }, character(1)))
}
