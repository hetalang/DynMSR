# DynMS R

Toolkit to work with DynMS in R

[![Heta project](https://img.shields.io/badge/%CD%B1-Heta_project-blue)](https://hetalang.github.io/)
[![GitHub issues](https://img.shields.io/github/issues/hetalang/dynmsr.svg)](https://GitHub.com/hetalang/dynmsr/issues/)
[![GitHub license](https://img.shields.io/github/license/hetalang/dynmsr.svg)](https://github.com/hetalang/dynmsr/blob/master/LICENSE)
[![Autotests](https://github.com/hetalang/dynmsr/workflows/Autotests/badge.svg)](https://github.com/hetalang/dynmsr/actions)

**DynMS R** provides tools for reading, validating, converting, compiling, and simulating models stored in the DynMS format. It aims to make DynMS models interoperable with the R modeling ecosystem while providing a common interface for model manipulation and analysis.

## Planned features

- Read and validate DynMS models
- Convert DynMS models to **deSolve**
- Convert DynMS models to **mrgsolve**
- Compile generated C code for fast simulation
- Import models from Heta via the DynMS intermediate format

## Installation

> Currently not available on CRAN. You can install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("hetalang/DynMSR")
```

## Example

```r
library(DynMSR)

# Load and validate DynMS models from the file
platform <- dynms_read("model.dynms.json")
dynms_model <- platform$models[[1]]

# Convert the DynMS model to C code, compile and load it into DESolve model
desolve_model <- get_desolve(dynms_model)
```

## Related projects

- [DynMS](https://hetalang.github.io/hetacompiler/dynms.html) — model representation format and specification (currently part of the **heta-compiler**)
- [heta-compiler](https://github.com/hetalang/heta-compiler) — compiler from Heta to DynMS and other formats
- [HetaImporter.jl](https://github.com/hetalang/HetaImporter.jl) - Julia package to read DynMS and Heta models and convert them to use in Julia
