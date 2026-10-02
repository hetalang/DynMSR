# DynMSR

Toolkit for working with DynMS models in R.

[![Heta project](https://img.shields.io/badge/%CD%B1-Heta_project-blue)](https://hetalang.github.io/)
[![GitHub issues](https://img.shields.io/badge/issues-GitHub-blue.svg)](https://github.com/hetalang/DynMSR/issues/)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/hetalang/DynMSR/blob/master/LICENSE.md)
[![Autotests](https://github.com/hetalang/DynMSR/actions/workflows/autotests.yml/badge.svg)](https://github.com/hetalang/DynMSR/actions/workflows/autotests.yml)

**DynMSR** provides tools for reading, validating, normalizing, converting,
compiling, and eventually simulating models stored in the DynMS format. DynMSR
is an interoperability toolkit between DynMS and the R modeling ecosystem.

## Main features

- Read and validate DynMS models
- Optional import workflows from Heta & SBML via the DynMS intermediate format
- Convert DynMS models to **mrgsolve**
- Convert DynMS models to **deSolve** (experimental)
- Compile generated C code for fast simulation

## Installation

> Currently not available on CRAN. You can install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("hetalang/DynMSR")
```

## Quick start

```r
library(DynMSR)

# Load the DynMS JSON file as a platform
platform <- dynms_load("x.json")

# Select the first model in the platform
model <- get_model(platform, 1)

# Build a compiled mrgsolve model object
mrgsolve_model <- build_mrgsolve(model)

# Run a simulation with the mrgsolve model
library(mrgsolve)
res <- mrgsim(mrgsolve_model)
```

## mrgsolve limitations

The mrgsolve backend does not use root finding for DynMS state-event triggers.
It detects a trigger during integration, but processes the generated event at
an output record. Consequently, a state update may be delayed by up to one
output interval (`delta`). This limitation does not apply to DynMS time events,
whose scheduled times are passed directly to mrgsolve.

For a closer step-based approximation, use a smaller output interval:

```r
res <- mrgsolve::mrgsim(mrgsolve_model, delta = 0.01)
```

Reducing `delta` makes the event-delay bound smaller but increases the number
of output records; it does not reproduce the exact root-crossing time. Reducing
the solver's `hmax` can improve integration accuracy, but does not by itself
move event processing off the output grid. Very small `hmax` values may also
require increasing mrgsolve's `maxsteps`.

## Optional Heta integration

Heta is an optional DynMS producer; it is not required to read or validate
DynMS JSON files. The supported compiler range and integration-test pin are
defined in `inst/config/heta-compiler.json`. Follow the official
[Heta installation instructions](https://hetalang.github.io/hetacompiler/installation.html)
to install the compiler.

## Reproducibility reports

This section presents automated DynMS simulation checks for the `main` branch.
Each selected SBML Semantic Test Suite case is converted with Heta, loaded by
DynMSR, simulated with mrgsolve, and compared with its reference time course.

| Test set | Simulation check | Latest `main` |
| --- | --- | --- |
| sbmlteam/sbml-test-suite | SBML L2V5 → Heta → DynMSR/mrgsolve | [![SBML L2V5 DynMS simulation](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FDynMSR%2Freports%2Fdynms-simulation%2Fbranches%2Fmain%2Fl2v5%2Fbadge.json)](https://hetalang.github.io/format-conversion-test-suite/report/?ref=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FDynMSR%2Freports%2Fdynms-simulation%2Fbranches%2Fmain%2Fl2v5%2Freport.json) |
| sbmlteam/sbml-test-suite | SBML L3V1 → Heta → DynMSR/mrgsolve | [![SBML L3V1 DynMS simulation](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FDynMSR%2Freports%2Fdynms-simulation%2Fbranches%2Fmain%2Fl3v1%2Fbadge.json)](https://hetalang.github.io/format-conversion-test-suite/report/?ref=https%3A%2F%2Fraw.githubusercontent.com%2Fhetalang%2FDynMSR%2Freports%2Fdynms-simulation%2Fbranches%2Fmain%2Fl3v1%2Freport.json) |

The machine-readable compatibility rule, test pin, and installation URL are stored in
`inst/config/heta-compiler.json`. A future GitHub Actions Heta integration job
must install that exact version; the standard package-check matrix must remain
independent of Heta.

## Development

Run the local test suite with:

```sh
Rscript -e "pkgload::load_all('.'); testthat::test_dir('tests/testthat')"
```

Heta integration tests are disabled by default. They require the compiler
version configured in `inst/config/heta-compiler.json` and can be enabled with:

```sh
Rscript -e "Sys.setenv(DYNMSR_RUN_HETA_INTEGRATION = 'true'); pkgload::load_all('.'); testthat::test_dir('tests/testthat')"
```

Regenerate roxygen2 documentation, including `NAMESPACE` and `man/*.Rd`, with:

```sh
Rscript -e "roxygen2::roxygenise()"
```

The bundled DynMS JSON Schema is stored in `inst/schema/dynms.schema.json`.
Its upstream source URL is recorded in `inst/config/dynms.schema.source.json`.

To refresh the local schema copy during development:

```sh
Rscript tools/update-dynms-schema.R
```

If the upstream URL is not reachable from the current network, `source` can be
temporarily changed to a local schema file path in
`inst/config/dynms.schema.source.json`.

This is a manual developer step. Package installation, examples, and tests use
the bundled local schema and do not download files from the internet.

## Related projects

- [DynMS](https://hetalang.github.io/hetacompiler/dynms.html) — model representation format and specification (currently part of the **heta-compiler**)
- [heta-compiler](https://github.com/hetalang/heta-compiler) — compiler from Heta to DynMS and other formats
- [HetaImporter.jl](https://github.com/hetalang/HetaImporter.jl) - Julia package to read DynMS and Heta models and convert them to use in Julia
