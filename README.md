# DynMSR

Toolkit for working with DynMS models in R.

[![Heta project](https://img.shields.io/badge/%CD%B1-Heta_project-blue)](https://hetalang.github.io/)
[![GitHub issues](https://img.shields.io/github/issues/hetalang/dynmsr.svg)](https://GitHub.com/hetalang/dynmsr/issues/)
[![GitHub license](https://img.shields.io/github/license/hetalang/dynmsr.svg)](https://github.com/hetalang/dynmsr/blob/master/LICENSE)
[![Autotests](https://github.com/hetalang/dynmsr/workflows/Autotests/badge.svg)](https://github.com/hetalang/dynmsr/actions)

**DynMSR** provides tools for reading, validating, normalizing, converting,
compiling, and eventually simulating models stored in the DynMS format. DynMSR
is an interoperability toolkit between DynMS and the R modeling ecosystem.

## Planned features

- Read and validate DynMS models
- Convert DynMS models to **deSolve**
- Convert DynMS models to **mrgsolve**
- Compile generated C code for fast simulation
- Optional import workflows from Heta via the DynMS intermediate format

## Installation

> Currently not available on CRAN. You can install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("hetalang/DynMSR")
```

## Example

```r
library(DynMSR)

# Read the DynMS JSON file as an R list
raw_platform <- dynms_read("model.dynms.json")

# Validate the raw platform object against the bundled DynMS schema
dynms_validate_schema(raw_platform)

# Validate model-level consistency, such as internal identifier references
dynms_validate_semantic(raw_platform)

# Normalize the raw list into DynMSR's internal representation
platform <- dynms_normalize(raw_platform)
dynms_model <- platform$models[[1]]

# Future API target:
# desolve_model <- dynms_export_desolve(dynms_model)
# mrgsolve_model <- dynms_export_mrgsolve(dynms_model)
```

## Development

The bundled DynMS JSON Schema is stored in `inst/schema/dynms.schema.json`.
Its upstream source URL is recorded in `inst/schema/dynms.schema.source.json`.

To refresh the local schema copy during development:

```sh
Rscript tools/update-dynms-schema.R
```

If the upstream URL is not reachable from the current network, `source` can be
temporarily changed to a local schema file path in
`inst/schema/dynms.schema.source.json`.

This is a manual developer step. Package installation, examples, and tests use
the bundled local schema and do not download files from the internet.

## Related projects

- [DynMS](https://hetalang.github.io/hetacompiler/dynms.html) — model representation format and specification (currently part of the **heta-compiler**)
- [heta-compiler](https://github.com/hetalang/heta-compiler) — compiler from Heta to DynMS and other formats
- [HetaImporter.jl](https://github.com/hetalang/HetaImporter.jl) - Julia package to read DynMS and Heta models and convert them to use in Julia
