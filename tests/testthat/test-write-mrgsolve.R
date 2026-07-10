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
