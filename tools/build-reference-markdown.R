#!/usr/bin/env Rscript

# Build Markdown reference and vignette pages for the Heta documentation site.
# Run from the DynMSR package root after installing the development tools below.

if (!requireNamespace("roxygen2", quietly = TRUE)) {
  stop("Install roxygen2 to generate man/*.Rd before building Markdown pages.")
}

if (!requireNamespace("Rd2md", quietly = TRUE)) {
  stop("Install Rd2md to convert Rd help pages to Markdown.")
}

if (!requireNamespace("knitr", quietly = TRUE) ||
    !requireNamespace("pkgload", quietly = TRUE)) {
  stop("Install knitr and pkgload to render the vignette from the current package source.")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) {
  stop("Usage: Rscript tools/build-reference-markdown.R [output-directory]")
}
output_dir <- if (length(args)) args[[1L]] else "docs/reference"

roxygen2::roxygenise()
rd_files <- list.files("man", pattern = "\\.Rd$", full.names = TRUE)
if (!length(rd_files)) stop("No Rd files found in man/.")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
topics <- tools::file_path_sans_ext(basename(rd_files))

for (i in seq_along(rd_files)) {
  md <- Rd2md::as_markdown(Rd2md::read_rdfile(rd_files[[i]]))

  # Rd2md wraps generated Markdown links in backticks. Resolve package topics
  # to the pages built here and keep other R help references as plain code.
  links <- regmatches(md, gregexpr("`\\[[^]]+\\]\\([^)]*\\)`", md,
                                perl = TRUE))[[1L]]
  for (link in unique(links)) {
    label <- sub("^`\\[([^]]+)\\]\\(([^)]*)\\)`$", "\\1", link)
    target <- sub("^`\\[([^]]+)\\]\\(([^)]*)\\)`$", "\\2", link)
    replacement <- if (target %in% topics) {
      paste0("[", label, "](./", target, ".md)")
    } else if (grepl("^https?://", target)) {
      paste0("[", label, "](", target, ")")
    } else {
      paste0("`", label, "`")
    }
    md <- gsub(link, replacement, md, fixed = TRUE)
  }

  md <- gsub("`or ", "` or ", md, fixed = TRUE)
  md <- gsub("`in ", "` in ", md, fixed = TRUE)
  md <- sub("\\n+$", "", md)
  writeLines(md, file.path(output_dir, paste0(topics[[i]], ".md")),
             useBytes = TRUE)
}

index <- c("# DynMSR reference", "", "Function documentation generated from DynMSR's roxygen comments.", "")
index <- c(index, sprintf("- [%s](./%s.md)", topics, topics))
writeLines(index, file.path(output_dir, "index.md"), useBytes = TRUE)

message("Built ", length(rd_files), " reference pages in ", output_dir)

vignette_source <- "vignettes/getting-started.Rmd"
if (!file.exists(vignette_source)) stop("Vignette not found: ", vignette_source)

pkgload::load_all(".", quiet = TRUE)
knit_file <- tempfile(fileext = ".md")
invisible(knitr::knit(vignette_source, output = knit_file, quiet = TRUE))
lines <- readLines(knit_file, warn = FALSE, encoding = "UTF-8")
frontmatter_end <- which(lines == "---")
if (length(frontmatter_end) < 2L || frontmatter_end[[1L]] != 1L) {
  stop("Expected YAML frontmatter in ", vignette_source)
}
lines <- lines[-seq_len(frontmatter_end[[2L]])]
lines <- lines[c(TRUE, !(lines[-1L] == "" & lines[-length(lines)] == ""))]
lines <- sub("^``` r$", "```r", lines)
lines <- c("# Getting started with DynMSR", lines)
vignette_target <- file.path(dirname(output_dir), "getting-started.md")
writeLines(lines, vignette_target, useBytes = TRUE)
unlink(knit_file)
message("Built vignette page in ", vignette_target)
