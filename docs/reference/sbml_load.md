# Load an SBML file as a DynMS platform

## Description

Builds one SBML file through Heta compiler with the DynMS export enabled,
reads the generated DynMS JSON file, and returns a DynMS platform object.

## Usage

```r
sbml_load(
  path,
  output_dir = NULL,
  debug = FALSE,
  units_check = FALSE,
  log_mode = NULL,
  declaration = NULL,
  log_level = NULL,
  skip_updates = FALSE
)
```

## Arguments

* `path`: Path to an SBML file.
* `output_dir`: Optional directory for compiler output, passed to
[heta_load()](./heta_load.md).
* `debug`: If `TRUE`, passed to [heta_load()](./heta_load.md).
* `units_check`: If `TRUE`, passed to [heta_load()](./heta_load.md).
* `log_mode`: Log file saving mode, passed to [heta_load()](./heta_load.md).
* `declaration`: Declaration file path without extension, passed to
[heta_load()](./heta_load.md).
* `log_level`: Log level, passed to [heta_load()](./heta_load.md).
* `skip_updates`: If `TRUE`, passed to [heta_load()](./heta_load.md).

## Details

Requires a compatible `heta-compiler` installation. The generated DynMS
export is written to a temporary directory and removed after loading unless
`output_dir` is supplied.

## Value

A platform list. Use [get_model()](./get_model.md) or ordinary list access such as
`platform$models[[1]]` to select one model.

## Examples

```r
sbml_path <- "path/to/your/model.xml"
platform <- sbml_load(sbml_path)
model <- get_model(platform, 1)
compiled <- build_mrgsolve(model, quiet = TRUE)
simulation <- mrgsolve::mrgsim_df(compiled, end = 24, delta = 0.1)
```
