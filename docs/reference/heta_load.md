# Load a Heta project as a DynMS platform

## Description

Builds a Heta project with the DynMS export enabled, reads the generated
DynMS JSON file, and returns a DynMS platform object.

## Usage

```r
heta_load(
  dir,
  output_dir = NULL,
  source = NULL,
  type = NULL,
  debug = FALSE,
  units_check = FALSE,
  log_mode = NULL,
  declaration = NULL,
  log_level = NULL,
  skip_updates = FALSE
)
```

## Arguments

* `dir`: Heta project working directory.
* `output_dir`: Optional directory for compiler output. If omitted, a
temporary directory is used and removed after loading.
* `source`: Path to the main source file, passed to [heta_build()](./heta_build.md).
* `type`: Source file type, passed to [heta_build()](./heta_build.md).
* `debug`: If `TRUE`, passed to [heta_build()](./heta_build.md).
* `units_check`: If `TRUE`, passed to [heta_build()](./heta_build.md).
* `log_mode`: Log file saving mode, passed to [heta_build()](./heta_build.md). Use
`"always"` to write `build.log` after a successful build.
* `declaration`: Declaration file path without extension, passed to
[heta_build()](./heta_build.md).
* `log_level`: Log level, passed to [heta_build()](./heta_build.md).
* `skip_updates`: If `TRUE`, passed to [heta_build()](./heta_build.md).

## Details

Requires a compatible `heta-compiler` installation. Compiler output is
placed under `output_dir` in `dist/`, `meta/`, and, when selected by
`log_mode`, `build.log`. When `output_dir` is omitted, a temporary directory
is removed after loading.

## Value

A platform list. Use [get_model()](./get_model.md) or ordinary list access such as
`platform$models[[1]]` to select one model.

## Examples

```r
platform <- heta_load("path/to/your/heta-project")
model <- get_model(platform, 1)
compiled <- build_mrgsolve(model, quiet = TRUE)
simulation <- mrgsolve::mrgsim_df(compiled, end = 24, delta = 0.1)
```
