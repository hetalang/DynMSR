# Build a Heta project

## Description

Runs `heta build` for a Heta project directory. The arguments map directly
to Heta compiler CLI options, for example `units_check = TRUE` adds
`--units-check`.

## Usage

```r
heta_build(
  dir,
  output_dir,
  source = NULL,
  type = NULL,
  debug = FALSE,
  units_check = FALSE,
  log_mode = NULL,
  declaration = NULL,
  log_level = NULL,
  skip_updates = FALSE,
  export = NULL
)
```

## Arguments

* `dir`: Project working directory passed as the final CLI argument.
* `output_dir`: Directory for all compiler output. Required. Use
`output_dir = dir` to place output under the project directory.
* `source`: Path to the main source file, passed as `--source`.
* `type`: Source file type, passed as `--type`.
* `debug`: If `TRUE`, add `--debug`.
* `units_check`: If `TRUE`, add `--units-check`.
* `log_mode`: Log file saving mode, passed as `--log-mode`. Use `"always"`
to write `build.log` after a successful build.
* `declaration`: Declaration file path without extension, passed as
`--declaration`.
* `log_level`: Log level, passed as `--log-level`.
* `skip_updates`: If `TRUE`, add `--skip-updates`.
* `export`: Export format specification, passed as `--export`.

## Details

Requires a `heta` command that satisfies DynMSR's bundled compatibility
rule. Use [heta_check()](./heta_check.md) to inspect availability and the supported version
range before building. Compiler output paths are placed under `output_dir`:
`dist/`, `meta/`, and, when selected by `log_mode`, `build.log`. The output
directory must be supplied explicitly and remains available after the build.

## Value

Invisibly returns a list with the command, arguments, exit status,
captured output, and `output_dir`.

## Examples

```r
project_dir <- "path/to/your/heta-project"
output_dir <- tempfile("dynmsr-heta-output-")
heta_build(project_dir, output_dir, export = "SBML",
           log_mode = "always")
```
