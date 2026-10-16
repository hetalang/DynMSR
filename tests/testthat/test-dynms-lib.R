test_that("dynms_lib lists and locates bundled DynMS examples", {
  names <- dynms_lib()

  expect_gt(length(names), 0L)
  expect_identical(anyDuplicated(names), 0L)

  paths <- vapply(names, dynms_lib, character(1))
  expect_true(all(file.exists(paths)))
  expect_true(all(vapply(paths, function(path) inherits(dynms_load(path), "platform"), logical(1))))
})

test_that("dynms_lib validates the requested example name", {
  expect_error(dynms_lib("unknown"), "Unknown bundled DynMS example")
  expect_error(dynms_lib(c("first-order-decay", "repeated-dose")), "single bundled")
})

test_that("bundled DynMS examples compile and run with mrgsolve", {
  testthat::skip_if_not_installed("mrgsolve")

  for (name in dynms_lib()) {
    model <- get_model(dynms_load(dynms_lib(name)), 1)
    compiled <- build_mrgsolve(model, quiet = TRUE)
    simulation <- mrgsolve::mrgsim_df(compiled, end = 0.1, delta = 0.1)

    expect_s4_class(compiled, "mrgmod")
    expect_true(is.data.frame(simulation), info = name)
    expect_true("time" %in% names(simulation), info = name)
  }
})
