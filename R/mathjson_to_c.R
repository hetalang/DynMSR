# C specific helpers for converting DynMS MathJSON to C code

dynms_mathjson_to_c <- function(node, time_symbol = "t") {
  if (is.numeric(node)) {
    return(dynms_number_to_c(node))
  }
  if (is.character(node) && length(node) == 1L) {
    return(dynms_symbol_to_c(node, time_symbol))
  }
  if (is.list(node) && !is.null(node$num)) {
    return(dynms_extended_number_to_c(node$num))
  }
  if (is.list(node) && !is.null(node$sym)) {
    return(dynms_symbol_to_c(node$sym, time_symbol))
  }
  if (is.list(node) && !is.null(node$str)) {
    return(dynms_string_to_c(node$str))
  }
  if (is.list(node) && !is.null(node$fn)) {
    return(dynms_mathjson_to_c(node$fn, time_symbol))
  }
  if (!is.list(node) || length(node) == 0L || !is.character(node[[1]])) {
    stop("Unsupported MathJSON node in C export.", call. = FALSE)
  }

  op <- node[[1]]
  args <- lapply(
    node[-1],
    dynms_mathjson_to_c,
    time_symbol = time_symbol
  )

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
    Negate = dynms_paren_c(paste0("-(", args[[1]], ")")),
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
    stop("Unsupported MathJSON operator for C export: ", op, call. = FALSE)
  )
}

dynms_symbol_to_c <- function(symbol, time_symbol) {
  if (identical(symbol, "t")) {
    return(time_symbol)
  }
  if (identical(symbol, "True")) {
    return("true")
  }
  if (identical(symbol, "False")) {
    return("false")
  }
  if (identical(symbol, "ExponentialE")) {
    return("exp(1.0)")
  }
  if (identical(symbol, "Pi")) {
    return("acos(-1.0)")
  }

  symbol
}

dynms_extended_number_to_c <- function(value) {
  switch(
    value,
    "NaN" = "std::numeric_limits<double>::quiet_NaN()",
    "+Infinity" = "std::numeric_limits<double>::infinity()",
    "-Infinity" = "-std::numeric_limits<double>::infinity()",
    stop("Unsupported MathJSON extended number: ", value, call. = FALSE)
  )
}

dynms_string_to_c <- function(value) {
  if (!is.character(value) || length(value) != 1L) {
    stop("MathJSON `str` must contain one string.", call. = FALSE)
  }

  as.character(jsonlite::toJSON(value, auto_unbox = TRUE))
}

dynms_number_to_c <- function(x) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x)) {
    stop("Expected a single numeric value.", call. = FALSE)
  }

  value <- format(x, scientific = FALSE, trim = TRUE, digits = 17)
  if (!grepl("[.eE]", value)) {
    value <- paste0(value, ".0")
  }
  value
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
