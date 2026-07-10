
#' Compile a DynMS model with mrgsolve
#'
#' Generates an mrgsolve model source file and compiles it with `mrgsolve`.
#' The `mrgsolve` package is optional and is required only when this function is
#' called.
#'
#' @param model A model list, such as one element of `platform$models`.
#' @param filepath Path where the intermediate mrgsolve model source should be
#'   written. If omitted, a temporary `.mod` file is created.
#' @param ... Additional arguments passed to [mrgsolve::mread()].
#'
#' @return A compiled mrgsolve model object.
#' @export
build_mrgsolve <- function(model, filepath = tempfile(fileext = ".mod"), ...) {
  check_mrgsolve_model(model, "build_mrgsolve")

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
  mrgsolve::mread(
    model = tools::file_path_sans_ext(basename(path)),
    project = dirname(path),
    file = basename(path),
    ...
  )
}
