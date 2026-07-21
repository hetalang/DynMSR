indexed_examples <- function(group = "examples") {
  index_path <- system.file("examples", "index.json", package = "DynMSR")
  index <- jsonlite::fromJSON(index_path, simplifyVector = FALSE)

  if (!group %in% names(index)) {
    stop("Unknown indexed example group: ", group, call. = FALSE)
  }

  index[[group]]
}

indexed_example_paths <- function(group = "examples") {
  index_path <- system.file("examples", "index.json", package = "DynMSR")
  index <- jsonlite::fromJSON(index_path, simplifyVector = FALSE)
  examples <- indexed_examples(group)

  vapply(
    examples,
    function(example) {
      system.file(index$locationBase, example$file, package = "DynMSR")
    },
    character(1)
  )
}
