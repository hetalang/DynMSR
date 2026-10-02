test_that("write_mrgsolve writes to an explicit file path", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  raw <- dynms_read(system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR"))
  model <- new_platform(raw)$models[[1]]
  path <- tempfile(fileext = ".mod")
  on.exit(unlink(path), add = TRUE)

  result <- write_mrgsolve(model, path)

  expect_identical(result, path)
  expect_true(file.exists(path))
  expect_gt(file.info(path)$size, 0)
})

test_that("write_mrgsolve creates a temporary file when filepath is omitted", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  raw <- dynms_read(system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR"))
  model <- new_platform(raw)$models[[1]]

  path <- write_mrgsolve(model)
  on.exit(unlink(path), add = TRUE)

  expect_type(path, "character")
  expect_length(path, 1L)
  expect_true(file.exists(path))
  expect_match(basename(path), "\\.mod$")
  expect_gt(file.info(path)$size, 0)
})

test_that("mrgsolve time event EVID values start at 10", {
  model <- list(
    id = "time-events",
    constants = list(),
    dynamic = list(),
    static = list(),
    assignments = list(),
    timeEvents = list(
      list(
        id = "first",
        trigger = list(type = "time", start = 1),
        actions = list()
      ),
      list(
        id = "second",
        trigger = list(type = "time", start = 2),
        actions = list()
      )
    ),
    events = list(),
    observables = list()
  )

  data <- prepare_mrgsolve_template_data(model)

  expect_identical(data$timeEvents[[1]]$time_index_, 10L)
  expect_identical(data$timeEvents[[2]]$time_index_, 11L)
})

test_that("mrgsolve time events repeat only for positive periods", {
  testthat::skip_if_not_installed("mrgsolve")

  model <- list(
    id = "one-shot-period",
    constants = list(list(id = "k", value = 1)),
    dynamic = list(list(
      id = "A",
      initial = 1,
      derivative = list(expr = 0, format = "math-json")
    )),
    static = list(),
    assignments = list(),
    timeEvents = list(list(
      id = "event",
      trigger = list(type = "time", start = 1, period = 0),
      actions = list()
    )),
    events = list(),
    observables = list()
  )
  path <- write_mrgsolve(model)
  on.exit(unlink(path), add = TRUE)
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_match(code, "if (0.0 > 0.0) {", fixed = TRUE)
  expect_s4_class(build_mrgsolve(model, quiet = TRUE), "mrgmod")
})

test_that("mrgsolve export captures static states and assignments", {
  expression <- function(expr) list(expr = expr, format = "math-json")
  model <- list(
    id = "captured-values",
    constants = list(list(id = "k", value = 2)),
    dynamic = list(list(id = "A", initial = 1, derivative = expression(0))),
    static = list(list(id = "V", initial = 3)),
    assignments = list(list(id = "rate_value", rhs = expression("k"))),
    timeEvents = list(),
    events = list(),
    observables = list(
      list(symbol = "A"),
      list(symbol = "V"),
      list(symbol = "rate_value")
    )
  )
  path <- write_mrgsolve(model)
  on.exit(unlink(path), add = TRUE)
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_match(code, "$CAPTURE @annotated", fixed = TRUE)
  expect_match(code, "V : -", fixed = TRUE)
  expect_match(code, "rate_value : -", fixed = TRUE)
  expect_false(grepl("A : -", code, fixed = TRUE))
  expect_true(dynms_validate_semantic(list(dynms = "0.2.1", models = list(model)))$valid)
})

test_that("mrgsolve export renames reserved identifiers and references", {
  expression <- function(expr) list(expr = expr, format = "math-json")
  model <- list(
    id = "renaming",
    constants = list(
      list(id = "TIME", value = 1),
      list(id = "TIME_rnm_", value = 2),
      list(id = "TIME_rnm_1", value = 3)
    ),
    dynamic = list(list(
      id = "F_CENTRAL",
      initial = 1,
      derivative = expression(list("Add", "TIME", "F_CENTRAL", "t"))
    )),
    static = list(),
    assignments = list(list(id = "RATE", rhs = expression("TIME"))),
    timeEvents = list(list(
      id = "dose",
      trigger = list(type = "time", start = 1),
      actions = list(list(
        state = "F_CENTRAL",
        rhs = expression(list("Add", "F_CENTRAL", "t"))
      ))
    )),
    events = list(),
    observables = list(
      list(symbol = "F_CENTRAL"),
      list(symbol = "RATE")
    )
  )
  original <- model
  path <- tempfile(fileext = ".mod")
  on.exit(unlink(path), add = TRUE)
  messages <- character()

  withCallingHandlers(
    write_mrgsolve(model, path),
    warning = function(warning) {
      messages <<- c(messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_length(messages, 1L)
  expect_match(messages, "`TIME` -> `TIME_rnm_2`", fixed = TRUE)
  expect_match(messages, "`F_CENTRAL` -> `rnm_F_CENTRAL_rnm_`", fixed = TRUE)
  expect_match(messages, "`RATE` -> `RATE_rnm_`", fixed = TRUE)
  expect_match(code, "- `TIME` -> `TIME_rnm_2`", fixed = TRUE)
  expect_match(code, "TIME_rnm_2 : 1", fixed = TRUE)
  expect_match(code, "TIME_rnm_1 : 3", fixed = TRUE)
  expect_match(code, "rnm_F_CENTRAL_rnm_ : 1", fixed = TRUE)
  expect_match(code, "RATE_rnm_", fixed = TRUE)
  expect_match(code, "SOLVERTIME", fixed = TRUE)
  expect_match(code, "(rnm_F_CENTRAL_rnm_ + TIME)", fixed = TRUE)
  expect_identical(model, original)
})

test_that("mrgsolve export reserves generated compartment identifiers", {
  model <- list(
    constants = list(
      list(id = "dxdt_CENTRAL", value = 1),
      list(id = "CENTRAL_0", value = 2)
    ),
    dynamic = list(),
    static = list(),
    assignments = list(),
    timeEvents = list(),
    events = list()
  )

  mapping <- build_mrgsolve_identifier_map(model)

  expect_identical(
    unname(mapping[c("dxdt_CENTRAL", "CENTRAL_0")]),
    c("rnm_dxdt_CENTRAL_rnm_", "CENTRAL_0_rnm_")
  )
})

test_that("mrgsolve export warns about ignored DynMS features", {
  expression <- function(expr) list(expr = expr, format = "math-json")
  model <- list(
    id = "unsupported-features",
    constants = list(),
    dynamic = list(list(id = "A", initial = 1, derivative = expression(0), algebraic = TRUE)),
    static = list(),
    assignments = list(),
    timeEvents = list(list(
      id = "time-stop",
      trigger = list(type = "time", start = 1),
      actions = list(),
      stopSimulation = TRUE
    )),
    events = list(list(
      id = "root-stop",
      trigger = list(type = "crossing", rhs = expression(0), detection = "root"),
      actions = list(),
      stopSimulation = TRUE
    )),
    observables = list()
  )
  path <- tempfile(fileext = ".mod")
  on.exit(unlink(path), add = TRUE)
  messages <- character()

  withCallingHandlers(
    write_mrgsolve(model, path),
    warning = function(warning) {
      messages <<- c(messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )

  expect_true(file.exists(path))
  expect_length(messages, 1L)
  expect_match(messages, "dynamic[1].algebraic", fixed = TRUE)
  expect_match(messages, "timeEvents[1].stopSimulation", fixed = TRUE)
  expect_match(messages, "events[1].stopSimulation", fixed = TRUE)
  expect_match(messages, "events[1].trigger.detection", fixed = TRUE)
})

test_that("mrgsolve export converts extended MathJSON numbers", {
  model <- list(
    id = "extended-numbers",
    constants = list(list(id = "k", value = 1)),
    dynamic = list(),
    static = list(list(id = "x", initial = 0)),
    assignments = list(list(
      id = "value",
      rhs = list(
        expr = list("Add", list(num = "NaN"), list(num = "+Infinity"), list(num = "-Infinity")),
        format = "math-json"
      )
    )),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  path <- write_mrgsolve(model)
  on.exit(unlink(path), add = TRUE)
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_match(code, "std::numeric_limits<double>::quiet_NaN()", fixed = TRUE)
  expect_match(code, "std::numeric_limits<double>::infinity()", fixed = TRUE)
  expect_match(code, "-std::numeric_limits<double>::infinity()", fixed = TRUE)
})

test_that("mrgsolve export quotes MathJSON strings", {
  expect_identical(dynms_mathjson_to_c(list(str = "a \"quoted\" string")), '"a \\"quoted\\" string"')
})

test_that("mrgsolve export converts MathJSON boolean literals", {
  expect_identical(dynms_mathjson_to_c("True"), "true")
  expect_identical(dynms_mathjson_to_c(list(sym = "False")), "false")
})

test_that("mrgsolve export converts MathJSON ExponentialE", {
  expect_identical(dynms_mathjson_to_c("ExponentialE"), "exp(1.0)")
  expect_identical(dynms_mathjson_to_c(list(sym = "ExponentialE")), "exp(1.0)")
})

test_that("mrgsolve export converts Pi and safely negates negative values", {
  expect_identical(dynms_mathjson_to_c("Pi"), "acos(-1.0)")
  expect_identical(dynms_mathjson_to_c(list(sym = "Pi")), "acos(-1.0)")
  expect_identical(dynms_mathjson_to_c(list("Negate", -2)), "(-(-2.0))")
})

test_that("mrgsolve export renders numeric literals as doubles", {
  expect_identical(dynms_number_to_c(1), "1.0")
  expect_identical(dynms_number_to_c(-2), "-2.0")
  expect_identical(dynms_number_to_c(0.001), "0.001")
  expect_identical(
    dynms_mathjson_to_c(list("Divide", 1, 1000)),
    "(1.0 / 1000.0)"
  )
})

test_that("mrgsolve export converts multibranch MathJSON Which", {
  expression <- list(
    "Which",
    list("Greater", "a", 0), 1,
    list("LessEqual", "a", 0), 2,
    "True", list(num = "NaN")
  )

  expect_identical(
    dynms_mathjson_to_c(expression),
    "((a > 0.0) ? 1.0 : ((a <= 0.0) ? 2.0 : (true ? std::numeric_limits<double>::quiet_NaN() : std::numeric_limits<double>::quiet_NaN())))"
  )
})

test_that("mrgsolve export evaluates multibranch Which initial values", {
  testthat::skip_if_not_installed("mrgsolve")
  expression <- function(expr) list(expr = expr, format = "math-json")
  model <- list(
    id = "which-initial-values",
    constants = list(),
    dynamic = list(list(id = "A", initial = 0, derivative = expression(0))),
    static = list(
      list(id = "a", initial = expression(list("If", "True", 1, list(num = "NaN")))),
      list(id = "b", initial = expression(list(
        "Which",
        list("Greater", "a", 0), 1,
        list("LessEqual", "a", 0), 2,
        "True", list(num = "NaN")
      )))
    ),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  compiled <- build_mrgsolve(model, observables = c("a", "b"), quiet = TRUE)
  simulation <- mrgsolve::mrgsim_df(compiled, end = 0.1, delta = 0.1)

  expect_equal(simulation$a[[1]], 1)
  expect_equal(simulation$b[[1]], 1)
})

test_that("mrgsolve export preserves rational dynamic derivatives", {
  testthat::skip_if_not_installed("mrgsolve")

  model <- list(
    id = "rational-rate-rule",
    constants = list(),
    dynamic = list(list(
      id = "S4",
      initial = 0.001,
      derivative = list(expr = list("Divide", 1, 1000), format = "math-json")
    )),
    static = list(),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  compiled <- build_mrgsolve(model, quiet = TRUE)
  simulation <- mrgsolve::mrgsim_df(compiled, end = 0.06, delta = 0.06)

  expect_equal(simulation$S4[[2]], 0.00106, tolerance = 1e-10)
})

test_that("write_mrgsolve rejects a platform", {
  platform <- list(models = list(list(id = "model")))

  expect_error(write_mrgsolve(platform), "expects one model, not a platform")
})

test_that("build_mrgsolve rejects a platform before requiring mrgsolve", {
  platform <- list(models = list(list(id = "model")))

  expect_error(build_mrgsolve(platform), "expects one model, not a platform")
})

test_that("build_mrgsolve rejects mrgsolve-specific capture arguments", {
  model <- list(
    id = "capture-validation",
    constants = list(list(id = "k", value = 1)),
    dynamic = list(list(
      id = "S1", initial = 1, derivative = list(expr = 0, format = "math-json")
    )),
    static = list(list(id = "S2", initial = 2)),
    assignments = list(list(id = "rate_value", rhs = list(expr = "k", format = "math-json"))),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  expect_error(
    build_mrgsolve(model, capture = "S2"),
    "Use `observables` instead"
  )
})

test_that("build_mrgsolve prepares requested observables", {
  model <- list(
    id = "observable-validation",
    constants = list(list(id = "k", value = 1)),
    dynamic = list(list(
      id = "S1", initial = 1, derivative = list(expr = 0, format = "math-json")
    )),
    static = list(list(id = "S2", initial = 2)),
    assignments = list(list(id = "rate_value", rhs = list(expr = "k", format = "math-json"))),
    timeEvents = list(),
    events = list(),
    observables = list(list(symbol = "S2"))
  )

  expect_identical(
    prepare_mrgsolve_observable_capture(
      model, c("S1", "S2", "rate_value", "k", "rate_value")
    ),
    c("rate_value", "k")
  )
  expect_error(
    prepare_mrgsolve_observable_capture(model, "S5"),
    "identifier.*do not exist.*S5"
  )
  expect_error(
    prepare_mrgsolve_observable_capture(model, ""),
    "non-empty identifiers"
  )
})

test_that("build_mrgsolve captures renamed reserved identifiers", {
  testthat::skip_if_not_installed("mrgsolve")

  model <- list(
    id = "reserved-capture",
    constants = list(),
    dynamic = list(),
    static = list(
      list(id = "time", initial = 10),
      list(id = "Time", initial = 11),
      list(id = "TIME", initial = 12)
    ),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  expect_identical(
    prepare_mrgsolve_observable_capture(model, c("time", "Time", "TIME")),
    c("time_rnm_", "Time", "TIME_rnm_")
  )
  compiled <- build_mrgsolve(
    model,
    observables = c("time", "Time", "TIME"),
    quiet = TRUE
  )
  simulation <- mrgsolve::mrgsim_df(compiled, end = 0, delta = 1)

  expect_equal(simulation$time_rnm_[[1]], 10)
  expect_equal(simulation$Time[[1]], 11)
  expect_equal(simulation$TIME_rnm_[[1]], 12)
})

test_that("build_mrgsolve captures requested static states", {
  testthat::skip_if_not_installed("mrgsolve")
  model <- list(
    id = "capture-static",
    constants = list(list(id = "k", value = 1)),
    dynamic = list(list(
      id = "S1", initial = 1, derivative = list(expr = 0, format = "math-json")
    )),
    static = list(list(id = "S2", initial = 0.0002)),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  compiled <- build_mrgsolve(model, observables = c("S1", "S2"), quiet = TRUE)

  expect_identical(mrgsolve::outvars(compiled)$capture, "S2")
})

test_that("build_mrgsolve captures requested constants", {
  testthat::skip_if_not_installed("mrgsolve")
  model <- list(
    id = "capture-constant",
    constants = list(list(id = "k", value = 2.5)),
    dynamic = list(list(
      id = "S1", initial = 1, derivative = list(expr = 0, format = "math-json")
    )),
    static = list(),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  compiled <- build_mrgsolve(model, observables = "k", quiet = TRUE)

  expect_identical(mrgsolve::outvars(compiled)$capture, "k")
})

test_that("build_mrgsolve evaluates assignments without dynamic states", {
  testthat::skip_if_not_installed("mrgsolve")
  model <- list(
    id = "assignment-only",
    constants = list(list(id = "k", value = 2)),
    dynamic = list(),
    static = list(),
    assignments = list(list(
      id = "value", rhs = list(expr = list("Multiply", "k", 3), format = "math-json")
    )),
    timeEvents = list(),
    events = list(),
    observables = list()
  )
  compiled <- build_mrgsolve(model, observables = "value", quiet = TRUE)
  simulation <- mrgsolve::mrgsim_df(compiled, end = 0.1, delta = 0.1)

  expect_identical(mrgsolve::outvars(compiled)$capture, "value")
  expect_equal(simulation$value, c(6, 6))
})

test_that("build_mrgsolve compiles a model when mrgsolve is available", {
  testthat::skip_if_not_installed("mrgsolve")

  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  raw <- dynms_read(system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR"))
  model <- new_platform(raw)$models[[1]]

  compiled <- build_mrgsolve(model, quiet = TRUE)

  expect_s4_class(compiled, "mrgmod")
})

test_that("build_mrgsolve compiles extended MathJSON numbers", {
  testthat::skip_if_not_installed("mrgsolve")

  model <- list(
    id = "extended-numbers",
    dynamic = list(list(
      id = "x",
      initial = 1,
      derivative = list(
        expr = list("Add", list(num = "NaN"), list(num = "+Infinity"), list(num = "-Infinity")),
        format = "math-json"
      )
    )),
    constants = list(list(id = "k", value = 1)),
    static = list(),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )
  compiled <- build_mrgsolve(model, quiet = TRUE)

  expect_s4_class(compiled, "mrgmod")
})

test_that("build_mrgsolve compiles renamed identifiers and time symbols", {
  testthat::skip_if_not_installed("mrgsolve")

  expression <- function(expr) list(expr = expr, format = "math-json")
  model <- list(
    id = "renamed-build",
    constants = list(list(id = "TIME", value = 1)),
    dynamic = list(list(
      id = "F_CENTRAL",
      initial = 1,
      derivative = expression(list("Add", "RATE", "t"))
    )),
    static = list(),
    assignments = list(list(
      id = "RATE",
      rhs = expression(list("Multiply", "TIME", "F_CENTRAL"))
    )),
    timeEvents = list(list(
      id = "dose",
      trigger = list(type = "time", start = 1),
      actions = list(list(
        state = "F_CENTRAL",
        rhs = expression(list("Add", "F_CENTRAL", "t"))
      ))
    )),
    events = list(),
    observables = list(list(symbol = "RATE"))
  )

  expect_warning(
    compiled <- build_mrgsolve(model, quiet = TRUE),
    "mrgsolve export renamed reserved identifiers",
    fixed = TRUE
  )
  expect_s4_class(compiled, "mrgmod")
})
