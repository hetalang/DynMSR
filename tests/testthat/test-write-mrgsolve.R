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
