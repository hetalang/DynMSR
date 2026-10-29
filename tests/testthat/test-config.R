test_that("Heta compiler configuration has filled fields", {
  path <- system.file("config", "heta-compiler.json", package = "DynMSR", mustWork = TRUE)
  config <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  fields <- c("package", "supportedVersion", "installationUrl")

  expect_named(config, fields)
  for (field in fields) {
    value <- config[[field]]
    expect_type(value, "character")
    expect_length(value, 1L)
    expect_true(nzchar(trimws(value)), info = field)
  }
  expect_identical(config$package, "heta-compiler")
  expect_match(config$supportedVersion, "^\\^[0-9]+\\.[0-9]+\\.[0-9]+$")
  expect_match(config$installationUrl, "^https://")
})

test_that("every configured DynMS version has a bundled schema", {
  path <- system.file("config", "dynms.json", package = "DynMSR", mustWork = TRUE)
  config <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  versions <- config$versions

  expect_named(config, "versions")
  expect_type(versions, "list")
  expect_gt(length(versions), 0L)
  expect_false(anyDuplicated(names(versions)) > 0L)

  for (version in names(versions)) {
    expect_match(version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
    entry <- versions[[version]]
    expect_named(entry, c("source", "target"), info = version)

    for (field in c("source", "target")) {
      value <- entry[[field]]
      expect_type(value, "character")
      expect_length(value, 1L)
      expect_true(nzchar(trimws(value)), info = paste(version, field))
    }

    expect_match(entry$target, "^inst/schema/[^/]+\\.json$", info = version)
    schema_path <- system.file(
      sub("^inst/", "", entry$target),
      package = "DynMSR",
      mustWork = TRUE
    )
    schema <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
    expect_identical(schema$properties$dynms$const, version)
    expect_true(is.function(jsonvalidate::json_validator(schema_path, engine = "ajv")))
  }
})
