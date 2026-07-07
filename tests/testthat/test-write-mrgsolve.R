test_that("dynms_write_mrgsolve writes to an explicit file path", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  raw <- dynms_read(system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR"))
  model <- dynms_normalize(raw)$models[[1]]
  path <- tempfile(fileext = ".mod")
  on.exit(unlink(path), add = TRUE)

  result <- dynms_write_mrgsolve(model, path)

  expect_identical(result, path)
  expect_true(file.exists(path))
  expect_gt(file.info(path)$size, 0)
})

test_that("dynms_write_mrgsolve creates a temporary file when filepath is omitted", {
  index <- jsonlite::fromJSON(
    system.file("examples", "index.json", package = "DynMSR"),
    simplifyVector = FALSE
  )
  raw <- dynms_read(system.file(index$locationBase, index$examples[[1]]$file, package = "DynMSR"))
  model <- dynms_normalize(raw)$models[[1]]

  path <- dynms_write_mrgsolve(model)
  on.exit(unlink(path), add = TRUE)

  expect_type(path, "character")
  expect_length(path, 1L)
  expect_true(file.exists(path))
  expect_match(basename(path), "\\.mod$")
  expect_gt(file.info(path)$size, 0)
})
