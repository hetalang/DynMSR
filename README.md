# DynMSR

An R toolkit for systems-biology and systems-pharmacology models in
[Heta](https://hetalang.github.io/hetacompiler/),
[SBML](https://sbml.org/), and
[DynMS](https://hetalang.github.io/hetacompiler/dynms/description.html) formats.

[![Heta project](https://img.shields.io/badge/%CD%B1-Heta_project-blue)](https://hetalang.github.io/)
[![GitHub issues](https://img.shields.io/badge/issues-GitHub-blue.svg)](https://github.com/hetalang/DynMSR/issues/)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/hetalang/DynMSR/blob/master/LICENSE.md)
[![Autotests](https://github.com/hetalang/DynMSR/actions/workflows/autotests.yml/badge.svg)](https://github.com/hetalang/DynMSR/actions/workflows/autotests.yml)

**DynMSR** helps you take a Heta project, an SBML model, or a DynMS JSON file
and run it from R. It provides one convenient interface between these model
formats and simulation backends: load a model, select it, and build it for
simulation. DynMS (Dynamic Model Specification) is a lightweight, portable
intermediate representation for dynamical simulation models. DynMS files are
read directly; Heta projects and SBML files are converted to DynMS with
`heta-compiler` first.

```text
Heta project ── heta-compiler ──> DynMS JSON ───────┐
SBML file ───── heta-compiler ──> DynMS JSON ───────┼──> DynMSR ──> R backend
DynMS JSON ─────────────────────────────────────────┘
```

## Main features

- Load [Heta](https://hetalang.github.io/hetacompiler/) projects through
  `heta-compiler` and DynMS.
- Load [SBML](https://sbml.org/) files through `heta-compiler` and DynMS.
- Load and validate DynMS JSON models.
- Generate and build an **mrgsolve** backend from a DynMS model.

## Installation

> Currently not available on CRAN. You can install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("hetalang/DynMSR")
```

## Heta project quick start

DynMSR can also build a Heta project and load its DynMS export. This workflow,
as well as `sbml_load()`, requires a compatible `heta-compiler` installation.
DynMSR is currently tested with `heta-compiler` version **0.12.2**. The
supported version range and integration-test version are recorded in
`inst/config/heta-compiler.json`.

Install the compiler by following the [official Heta installation
instructions](https://hetalang.github.io/hetacompiler/installation.html),
selecting version 0.12.2. Then create an empty directory, such as
`heta-quick-start`, and save this file as `heta-quick-start/index.heta`:

```heta
comp1 @Compartment .= 1;

A @Species { compartment: comp1 } .= 10;
B @Species { compartment: comp1 } .= 0;
r1 @Reaction { actors: A => 2B } := k1 * A * comp1;

k1 @Const = 1.2e-1;
```

The model describes a reaction in which one unit of `A` produces two units of
`B`.

```r
library(DynMSR)

# heta_check()
platform <- heta_load("path/to/heta-quick-start")
model <- get_model(platform, 1)

# install.packages("mrgsolve")
require(mrgsolve)
mrgsolve_model <- build_mrgsolve(model)
result <- mrgsim(mrgsolve_model, end = 100, delta = 1)
plot(result)
```

## SBML quick start

With `heta-compiler` installed as above, create a file named
`sbml-quick-start.xml` with this SBML Level 2 Version 5 model. Like the Heta
example, it describes the reaction `A → 2B`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sbml xmlns="http://www.sbml.org/sbml/level2/version5" level="2" version="5">
  <model id="simple_conversion">
    <listOfCompartments>
      <compartment id="comp1" size="1"/>
    </listOfCompartments>
    <listOfSpecies>
      <species id="A" compartment="comp1" initialAmount="10"/>
      <species id="B" compartment="comp1" initialAmount="0"/>
    </listOfSpecies>
    <listOfParameters>
      <parameter id="k1" value="0.12"/>
    </listOfParameters>
    <listOfReactions>
      <reaction id="r1" reversible="false">
        <listOfReactants>
          <speciesReference species="A"/>
        </listOfReactants>
        <listOfProducts>
          <speciesReference species="B" stoichiometry="2"/>
        </listOfProducts>
        <kineticLaw>
          <math xmlns="http://www.w3.org/1998/Math/MathML"><apply><times/><ci>k1</ci><ci>A</ci></apply></math>
        </kineticLaw>
      </reaction>
    </listOfReactions>
  </model>
</sbml>
```

Load and simulate the model from R:

```r
library(DynMSR)

platform <- sbml_load("path/to/sbml-quick-start.xml")
model <- get_model(platform, 1)

require(mrgsolve)
mrgsolve_model <- build_mrgsolve(model)
result <- mrgsim(mrgsolve_model, end = 100, delta = 1)
plot(result)
```

## DynMS quick start

Use this path when you already have a DynMS JSON document.

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

## Backends

DynMSR treats **mrgsolve** and **deSolve** as backend targets in
its architecture: the same loaded DynMS model is intended to support either
backend without changing the core loader or validator. The mrgsolve backend is
available now. The deSolve backend is planned, but is not yet implemented and
cannot currently be used for code generation or simulation.

### mrgsolve

The mrgsolve backend does not use root finding for DynMS state-event triggers.
The current exporter evaluates such conditions in `$ODE`; mrgsolve may call
that block at internal trial times rather than only at output records.
Consequently, the generated state update can occur at an output record before
or after the true threshold crossing. This limitation does not apply to DynMS
time events, whose scheduled times are passed directly to mrgsolve.

For a closer step-based approximation, use a smaller output interval:

```r
res <- mrgsolve::mrgsim(mrgsolve_model, delta = 0.01)
```

Reducing `delta` and limiting `hmax` can sometimes make the approximation
closer, but neither reproduces the exact root-crossing time nor guarantees
which side of the threshold an event will be placed. A robust step-based
implementation would evaluate and latch state-event conditions in `$TABLE`,
where they run on the output grid, rather than in `$ODE`.

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

Heta integration tests are disabled by default. They require
`heta-compiler` version 0.12.2 and can be enabled with:

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

Heta is an optional DynMS producer; it is not required to read or validate
DynMS JSON files. The supported compiler range and integration-test version
are defined in `inst/config/heta-compiler.json`.

This is a manual developer step. Package installation, examples, and tests use
the bundled local schema and do not download files from the internet.

## Related projects

- [heta-compiler](https://github.com/hetalang/heta-compiler) — compiler from Heta to DynMS and other formats
- [SBML](https://sbml.org/) — Systems Biology Markup Language
- [DynMS](https://hetalang.github.io/hetacompiler/dynms/description.html) — lightweight, portable intermediate representation for dynamical simulation models
- [mrgsolve](https://mrgsolve.org/) — R package for model specification and simulation
- [deSolve](https://cran.r-project.org/package=deSolve) — R package for solving differential equations
- [HetaImporter.jl](https://github.com/hetalang/HetaImporter.jl) - Julia package to read DynMS and Heta models and convert them to use in Julia
