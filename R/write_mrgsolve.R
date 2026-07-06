.dynms_mrgsolve_template_path <- system.file(
  "templates",
  "mrgsolve-model.cpp.mustache",
  package = "DynMSR",
  mustWork = TRUE
)

#' Write an mrgsolve model file
#'
#' Generates mrgsolve C++ model source from a normalized DynMS model.
#'
#' @param filepath Path where the generated model source should be written.
#' @param model A normalized DynMS model list, such as one element of
#'   `dynms_normalize(raw)$models`.
#'
#' @return `filepath`, invisibly.
#' @export
dynms_write_mrgsolve <- function(filepath, model) {
  if (!is.character(filepath) || length(filepath) != 1L || is.na(filepath)) {
    stop("`filepath` must be a single output file path.", call. = FALSE)
  }
  if (!is.list(model)) {
    stop("`model` must be a normalized DynMS model represented as an R list.", call. = FALSE)
  }

  data <- prepare_mrgsolve_template_data(model)
  template <- readLines(.dynms_mrgsolve_template_path, warn = FALSE)
  code <- whisker::whisker.render(paste(template, collapse = "\n"), data)

  output_dir <- dirname(filepath)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  writeLines(code, filepath, useBytes = TRUE)
  invisible(filepath)
}

prepare_mrgsolve_template_data <- function(model) {
  data <- model

  constants <- unname(model$constants)
  states <- unname(model$states)
  assignments <- unname(model$assignments)
  derivatives <- unname(model$derivatives)
  events <- unname(model$events)
  observables <- unname(model$observables)

  dynamic_state_ids <- vapply(
    Filter(function(x) !isTRUE(x$static), states),
    `[[`,
    character(1),
    "id"
  )
  dynamic_index <- stats::setNames(seq_along(dynamic_state_ids), dynamic_state_ids)

  time_event_ids <- vapply(
    Filter(function(x) identical(x$trigger$type, "time"), events),
    `[[`,
    character(1),
    "id"
  )
  time_event_index <- stats::setNames(seq_along(time_event_ids), time_event_ids)

  data$constants <- lapply(constants, prepare_mrgsolve_constant)
  data$states <- lapply(states, prepare_mrgsolve_state)
  data$assignments <- lapply(assignments, prepare_mrgsolve_assignment)
  data$derivatives <- lapply(derivatives, prepare_mrgsolve_derivative)
  data$events <- lapply(
    seq_along(events),
    function(i) prepare_mrgsolve_event(events[[i]], dynamic_index, time_event_index, i)
  )
  data$observables <- lapply(observables, prepare_mrgsolve_observable, dynamic_index = dynamic_index)
  data$has_events <- length(events) > 0L
  data$has_captured_observables <- any(vapply(data$observables, `[[`, logical(1), "captured"))

  data
}

prepare_mrgsolve_constant <- function(constant) {
  constant$value_expr <- dynms_value_to_mrgsolve(constant$value)
  constant$title <- constant$title %||% "-"
  constant
}

prepare_mrgsolve_state <- function(state) {
  static <- isTRUE(state$static)
  numeric_initial <- is.numeric(state$initial)

  state$static <- static
  state$dynamic <- !static
  state$initial_value <- if (numeric_initial) dynms_number_to_c(state$initial) else "0.0"
  state$initial_expr <- dynms_value_to_mrgsolve(state$initial)
  state$has_expression_initial <- !static && !numeric_initial
  state$title <- state$title %||% "-"

  state
}

prepare_mrgsolve_assignment <- function(assignment) {
  assignment$rhs_expr <- dynms_expression_to_mrgsolve(assignment$rhs)
  assignment$title <- assignment$title %||% "-"
  assignment
}

prepare_mrgsolve_derivative <- function(derivative) {
  derivative$rhs_expr <- dynms_expression_to_mrgsolve(derivative$rhs)
  derivative
}

prepare_mrgsolve_event <- function(event, dynamic_index, time_event_index, event_number) {
  is_time <- identical(event$trigger$type, "time")
  trigger <- event$trigger

  event$title <- event$title %||% "-"
  event$active_value <- if (isFALSE(event$active)) "0" else "1"
  event$is_time <- is_time
  event$is_non_time <- !is_time
  event$time_index <- if (is_time) unname(time_event_index[[event$id]]) else ""
  event$actions <- lapply(
    seq_along(event$actions),
    function(i) prepare_mrgsolve_event_action(event$actions[[i]], dynamic_index, event_number, i)
  )

  event$trigger <- trigger
  if (is_time) {
    event$trigger$start_expr <- dynms_value_to_mrgsolve(trigger$start)
    event$trigger$has_period <- !is.null(trigger$period)
    event$trigger$period_expr <- if (!is.null(trigger$period)) dynms_value_to_mrgsolve(trigger$period) else ""
    event$trigger$has_stop <- !is.null(trigger$stop)
    event$trigger$stop_expr <- if (!is.null(trigger$stop)) dynms_value_to_mrgsolve(trigger$stop) else ""
  } else {
    event$trigger$initial_pull <- if (isTRUE(trigger$atStart)) "false" else "true"
    event$trigger$trigger_expr <- dynms_expression_to_mrgsolve(trigger$rhs)
    event$trigger$trigger_suffix <- if (identical(trigger$type, "crossing")) " >= 0.0" else ""
  }

  event
}

prepare_mrgsolve_event_action <- function(action, dynamic_index, event_number, action_number) {
  dynamic <- action$state %in% names(dynamic_index)

  action$rhs_expr <- dynms_expression_to_mrgsolve(action$rhs)
  action$dynamic <- dynamic
  action$static <- !dynamic
  action$cmt <- if (dynamic) unname(dynamic_index[[action$state]]) else ""
  action$event_var <- paste0("evt_", event_number, "_", action_number, "_")

  action
}

prepare_mrgsolve_observable <- function(observable, dynamic_index) {
  observable$captured <- !(observable$symbol %in% names(dynamic_index))
  observable$title <- observable$title %||% "-"
  observable
}

dynms_value_to_mrgsolve <- function(value) {
  if (is.numeric(value)) {
    return(dynms_number_to_c(value))
  }

  dynms_expression_to_mrgsolve(value)
}

dynms_expression_to_mrgsolve <- function(expression) {
  dynms_mathjson_to_c(expression$expr)
}

dynms_mathjson_to_c <- function(node) {
  if (is.numeric(node)) {
    return(dynms_number_to_c(node))
  }
  if (is.character(node) && length(node) == 1L) {
    return(node)
  }
  if (is.list(node) && !is.null(node$num)) {
    return(node$num)
  }
  if (is.list(node) && !is.null(node$sym)) {
    return(node$sym)
  }
  if (is.list(node) && !is.null(node$fn)) {
    return(dynms_mathjson_to_c(node$fn))
  }
  if (!is.list(node) || length(node) == 0L || !is.character(node[[1]])) {
    stop("Unsupported MathJSON node in mrgsolve export.", call. = FALSE)
  }

  op <- node[[1]]
  args <- lapply(node[-1], dynms_mathjson_to_c)

  switch(
    op,
    Abs = dynms_call_c("fabs", args),
    Add = dynms_infix_c(args, "+"),
    And = dynms_infix_c(args, "&&"),
    Arccos = dynms_call_c("acos", args),
    Arccot = dynms_paren_c(paste0("atan(1.0 / ", args[[1]], ")")),
    Arccsc = dynms_paren_c(paste0("asin(1.0 / ", args[[1]], ")")),
    Arcsec = dynms_paren_c(paste0("acos(1.0 / ", args[[1]], ")")),
    Arcsin = dynms_call_c("asin", args),
    Arctan = dynms_call_c("atan", args),
    Ceil = dynms_call_c("ceil", args),
    Cos = dynms_call_c("cos", args),
    Cot = dynms_paren_c(paste0("1.0 / tan(", args[[1]], ")")),
    Csc = dynms_paren_c(paste0("1.0 / sin(", args[[1]], ")")),
    Divide = dynms_infix_c(args, "/"),
    Equal = dynms_infix_c(args, "=="),
    Exp = dynms_call_c("exp", args),
    Factorial = dynms_call_c("tgamma", list(paste0("(", args[[1]], " + 1.0)"))),
    Floor = dynms_call_c("floor", args),
    Greater = dynms_infix_c(args, ">"),
    GreaterEqual = dynms_infix_c(args, ">="),
    If = dynms_if_c(args),
    Lb = dynms_call_c("log2", args),
    Less = dynms_infix_c(args, "<"),
    LessEqual = dynms_infix_c(args, "<="),
    Lg = dynms_call_c("log10", args),
    Ln = dynms_call_c("log", args),
    Log = dynms_log_c(args),
    Max = dynms_call_c("fmax", args),
    Min = dynms_call_c("fmin", args),
    Multiply = dynms_infix_c(args, "*"),
    Negate = dynms_paren_c(paste0("-", args[[1]])),
    Not = dynms_paren_c(paste0("!", args[[1]])),
    NotEqual = dynms_infix_c(args, "!="),
    Or = dynms_infix_c(args, "||"),
    Power = dynms_call_c("pow", args),
    Root = dynms_root_c(args),
    Sec = dynms_paren_c(paste0("1.0 / cos(", args[[1]], ")")),
    Sign = dynms_paren_c(paste0("((", args[[1]], " > 0) - (", args[[1]], " < 0))")),
    Sin = dynms_call_c("sin", args),
    Sqrt = dynms_call_c("sqrt", args),
    Square = dynms_call_c("pow", list(args[[1]], "2.0")),
    Tan = dynms_call_c("tan", args),
    Which = dynms_if_c(args),
    Xor = dynms_infix_c(args, "!="),
    stop("Unsupported MathJSON operator for mrgsolve export: ", op, call. = FALSE)
  )
}

dynms_number_to_c <- function(x) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x)) {
    stop("Expected a single numeric value.", call. = FALSE)
  }

  format(x, scientific = FALSE, trim = TRUE, digits = 17)
}

dynms_paren_c <- function(x) {
  paste0("(", x, ")")
}

dynms_infix_c <- function(args, operator) {
  dynms_paren_c(paste(args, collapse = paste0(" ", operator, " ")))
}

dynms_call_c <- function(name, args) {
  paste0(name, "(", paste(args, collapse = ", "), ")")
}

dynms_if_c <- function(args) {
  if (length(args) != 3L) {
    stop("MathJSON `If`/`Which` requires exactly three arguments.", call. = FALSE)
  }

  dynms_paren_c(paste0(args[[1]], " ? ", args[[2]], " : ", args[[3]]))
}

dynms_log_c <- function(args) {
  if (length(args) == 1L) {
    return(dynms_call_c("log", args))
  }
  if (length(args) == 2L) {
    return(dynms_paren_c(paste0("log(", args[[1]], ") / log(", args[[2]], ")")))
  }

  stop("MathJSON `Log` requires one or two arguments.", call. = FALSE)
}

dynms_root_c <- function(args) {
  if (length(args) == 1L) {
    return(dynms_call_c("sqrt", args))
  }
  if (length(args) == 2L) {
    return(dynms_call_c("pow", list(args[[2]], paste0("1.0 / ", args[[1]]))))
  }

  stop("MathJSON `Root` requires one or two arguments.", call. = FALSE)
}
