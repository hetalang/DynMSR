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

  expect_match(code, "if (0 > 0.0) {", fixed = TRUE)
  expect_s4_class(build_mrgsolve(model, quiet = TRUE), "mrgmod")
})

test_that("mrgsolve export rejects reserved identifiers", {
  model <- list(
    constants = list(list(id = "TIME")),
    dynamic = list(list(id = "F_CENTRAL")),
    static = list(),
    assignments = list(),
    timeEvents = list(),
    events = list(),
    observables = list()
  )

  error <- tryCatch(
    prepare_mrgsolve_template_data(model),
    error = identity
  )

  expect_s3_class(error, "error")
  expect_match(conditionMessage(error), "`constants[1].id` (`TIME`) is a reserved word.", fixed = TRUE)
  expect_match(
    conditionMessage(error),
    "`dynamic[1].id` (`F_CENTRAL`) matches reserved pattern `F_{CMT}`.",
    fixed = TRUE
  )
})

test_that("mrgsolve export rejects reserved event action targets", {
  model <- list(
    constants = list(),
    dynamic = list(),
    static = list(),
    assignments = list(),
    timeEvents = list(list(
      id = "dose",
      actions = list(list(state = "RATE"))
    )),
    events = list(),
    observables = list()
  )

  error <- tryCatch(
    prepare_mrgsolve_template_data(model),
    error = identity
  )

  expect_s3_class(error, "error")
  expect_match(
    conditionMessage(error),
    "`timeEvents[1].actions[1].state` (`RATE`) is a reserved word.",
    fixed = TRUE
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

test_that("write_mrgsolve rejects a platform", {
  platform <- list(models = list(list(id = "model")))

  expect_error(write_mrgsolve(platform), "expects one model, not a platform")
})

test_that("build_mrgsolve rejects a platform before requiring mrgsolve", {
  platform <- list(models = list(list(id = "model")))

  expect_error(build_mrgsolve(platform), "expects one model, not a platform")
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
