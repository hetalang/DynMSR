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
  constants <- unname(model$constants)
  states <- unname(model$states)
  assignments <- unname(model$assignments)
  derivatives <- unname(model$derivatives)
  events <- unname(model$events)
  observables <- unname(model$observables)

  dynamic_states <- Filter(function(x) !isTRUE(x$static), states)
  static_states <- Filter(function(x) isTRUE(x$static), states)
  dynamic_index <- stats::setNames(seq_along(dynamic_states), vapply(dynamic_states, `[[`, character(1), "id"))

  time_event_ids <- vapply(
    Filter(function(x) identical(x$trigger$type, "time"), events),
    `[[`,
    character(1),
    "id"
  )
  time_event_index <- stats::setNames(seq_along(time_event_ids), time_event_ids)

  captured_observables <- prepare_mrgsolve_observables(observables, dynamic_index)

  list(
    id = model$id,
    constants = lapply(constants, prepare_mrgsolve_constant),
    dynamic_states = lapply(dynamic_states, prepare_mrgsolve_dynamic_state),
    dynamic_expression_initials = Filter(
      function(x) !is.null(x),
      lapply(dynamic_states, prepare_mrgsolve_dynamic_expression_initial)
    ),
    static_states = lapply(static_states, prepare_mrgsolve_static_state),
    assignments = lapply(assignments, prepare_mrgsolve_assignment),
    derivatives = lapply(derivatives, prepare_mrgsolve_derivative),
    events = lapply(
      seq_along(events),
      function(i) prepare_mrgsolve_event(events[[i]], dynamic_index, time_event_index, i)
    ),
    time_events = lapply(
      Filter(function(x) identical(x$trigger$type, "time"), events),
      prepare_mrgsolve_time_event,
      time_event_index = time_event_index
    ),
    non_time_events = lapply(
      Filter(function(x) !identical(x$trigger$type, "time"), events),
      prepare_mrgsolve_non_time_event
    ),
    captured_observables = captured_observables,
    has_captured_observables = length(captured_observables) > 0L,
    has_events = length(events) > 0L
  )
}

prepare_mrgsolve_constant <- function(constant) {
  list(
    id = constant$id,
    value = dynms_value_to_mrgsolve(constant$value),
    title = constant$title %||% "-"
  )
}

prepare_mrgsolve_dynamic_state <- function(state) {
  list(
    id = state$id,
    initial_value = if (is.numeric(state$initial)) dynms_number_to_c(state$initial) else "0.0",
    title = state$title %||% "-"
  )
}

prepare_mrgsolve_dynamic_expression_initial <- function(state) {
  if (is.numeric(state$initial)) {
    return(NULL)
  }

  list(id = state$id, initial_expr = dynms_value_to_mrgsolve(state$initial))
}

prepare_mrgsolve_static_state <- function(state) {
  list(
    id = state$id,
    title = state$title %||% "-",
    initial_expr = dynms_value_to_mrgsolve(state$initial)
  )
}

prepare_mrgsolve_assignment <- function(assignment) {
  list(
    id = assignment$id,
    rhs_expr = dynms_expression_to_mrgsolve(assignment$rhs),
    title = assignment$title %||% "-"
  )
}

prepare_mrgsolve_derivative <- function(derivative) {
  list(
    state = derivative$state,
    rhs_expr = dynms_expression_to_mrgsolve(derivative$rhs)
  )
}

prepare_mrgsolve_time_event <- function(event, time_event_index) {
  list(
    id = event$id,
    start_expr = dynms_value_to_mrgsolve(event$trigger$start),
    time_index = unname(time_event_index[[event$id]])
  )
}

prepare_mrgsolve_non_time_event <- function(event) {
  list(
    id = event$id,
    initial_pull = if (isTRUE(event$trigger$atStart)) "false" else "true",
    trigger_expr = dynms_expression_to_mrgsolve(event$trigger$rhs),
    trigger_suffix = if (identical(event$trigger$type, "crossing")) " >= 0.0" else ""
  )
}

prepare_mrgsolve_event <- function(event, dynamic_index, time_event_index, event_number) {
  is_time <- identical(event$trigger$type, "time")
  trigger <- event$trigger

  list(
    id = event$id,
    title = event$title %||% "-",
    active_value = if (isFALSE(event$active)) "0" else "1",
    is_time = is_time,
    is_non_time = !is_time,
    time_index = if (is_time) unname(time_event_index[[event$id]]) else "",
    actions = lapply(
      seq_along(event$actions),
      function(i) prepare_mrgsolve_event_action(event$actions[[i]], dynamic_index, event_number, i)
    ),
    has_period = is_time && !is.null(trigger$period),
    period_expr = if (!is.null(trigger$period)) dynms_value_to_mrgsolve(trigger$period) else "",
    has_stop = is_time && !is.null(trigger$stop),
    stop_expr = if (!is.null(trigger$stop)) dynms_value_to_mrgsolve(trigger$stop) else ""
  )
}

prepare_mrgsolve_event_action <- function(action, dynamic_index, event_number, action_number) {
  dynamic <- action$state %in% names(dynamic_index)

  list(
    state = action$state,
    rhs_expr = dynms_expression_to_mrgsolve(action$rhs),
    dynamic = dynamic,
    static = !dynamic,
    cmt = if (dynamic) unname(dynamic_index[[action$state]]) else "",
    event_var = paste0("evt_", event_number, "_", action_number, "_")
  )
}

prepare_mrgsolve_observables <- function(observables, dynamic_index) {
  lapply(
    Filter(function(x) !(x$symbol %in% names(dynamic_index)), observables),
    function(observable) {
      list(symbol = observable$symbol, title = observable$title %||% "-")
    }
  )
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
