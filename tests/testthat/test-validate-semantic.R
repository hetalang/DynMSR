index <- jsonlite::fromJSON(
  system.file("examples", "index.json", package = "DynMSR"),
  simplifyVector = FALSE
)

test_that("dynms_validate_semantic succeeds for all indexed valid examples", {
  paths <- vapply(
    index$examples,
    function(example) {
      system.file(index$locationBase, example$file, package = "DynMSR")
    },
    character(1)
  )

  results <- lapply(paths, function(path) {
    raw <- dynms_read(path)
    dynms_validate_semantic(raw)
  })

  expect_true(all(vapply(results, `[[`, logical(1), "valid")))
  expect_true(all(vapply(results, function(result) length(result$errors) == 0L, logical(1))))
  expect_true(all(vapply(results, function(result) length(result$warnings) == 0L, logical(1))))
})

test_that("dynms_validate_semantic reports messages for all indexed semantic error examples", {
  paths <- vapply(
    index$semanticErrorsExamples,
    function(example) {
      system.file(index$locationBase, example$file, package = "DynMSR")
    },
    character(1)
  )

  results <- lapply(paths, function(path) {
    raw <- dynms_read(path)
    expect_true(dynms_validate_schema(raw)$valid)
    dynms_validate_semantic(raw)
  })

  expect_true(all(!vapply(results, `[[`, logical(1), "valid")))
  expect_true(all(vapply(results, function(result) length(result$errors) > 0L, logical(1))))
  expect_true(all(vapply(
    results,
    function(result) all(nzchar(vapply(result$errors, `[[`, character(1), "message"))),
    logical(1)
  )))
})

test_that("dynms_validate_semantic rejects duplicate state ids across dynamic and static", {
  raw <- list(
    dynms = "0.2.0",
    models = list(
      list(
        id = "model",
        constants = list(),
        dynamic = list(list(id = "A", initial = 1)),
        static = list(list(id = "A", initial = 2)),
        assignments = list(),
        derivatives = list(),
        events = list(),
        observables = list()
      )
    )
  )

  result <- dynms_validate_semantic(raw)
  messages <- vapply(result$errors, `[[`, character(1), "message")

  expect_false(result$valid)
  expect_true(any(grepl(
    "Duplicate state identifier across `dynamic` and `static`: A",
    messages,
    fixed = TRUE
  )))
})
