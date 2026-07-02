# Instructions for AI agents

## Project overview

This repository contains **DynMSR**, an R toolkit for working with models stored in the **DynMS** format.

DynMS is intended to be a language-independent model representation format for Systems Biology and Systems Pharmacology. DynMSR is the R implementation/toolkit that reads, validates, converts, compiles, and eventually simulates DynMS models using R modeling backends.

The package should not be treated as a Heta-only package. Heta is one possible frontend that can generate DynMS, but DynMSR must work with DynMS files independently of Heta.

Conceptual pipeline:

```text
Heta or other frontend
        |
        v
    DynMS JSON
        |
        v
      DynMSR
        |
        +--> deSolve
        +--> mrgsolve
        +--> future R backends
```

## Naming and positioning

* Specification / format: **DynMS**
* R package: **DynMSR**
* Repository name: `DynMSR`
* Project description: **Toolkit for working with DynMS models in R**

Avoid positioning DynMSR as:

* a Heta importer only;
* a deSolve wrapper only;
* a simulator only.

DynMSR should be positioned as an interoperability toolkit between DynMS and the R modeling ecosystem.

## Main goals

DynMSR should provide tools to:

1. Read DynMS JSON files.
2. Validate raw DynMS documents against a JSON Schema.
3. Validate semantic consistency of raw DynMS documents.
4. Normalize DynMS content into internal R list structures.
5. Export DynMS models to R modeling backends.
6. Generate C code for compiled backends where needed.
7. Compile generated code using R tooling.
8. Load compiled models into R.
9. Later, run simulations through a unified R interface.

## Initial scope

The first practical target is:

```text
DynMS JSON -> deSolve C code -> compiled shared library -> deSolve model
```

The second target is:

```text
DynMS JSON -> mrgsolve C code -> compiled shared library -> mrgsolve model
```

Heta support must remain optional.

## Recommended architecture

Use a staged architecture instead of direct JSON-to-C generation.

Preferred pipeline:

```text
dynms_read()
    |
    v
dynms_validate_schema()
    |
    v
dynms_validate_semantic()
    |
    v
dynms_normalize()
    |
    v
backend-specific exporter
    |
    +--> dynms_export_desolve()
    +--> dynms_export_mrgsolve()
```

Recommended internal stages:

1. Raw JSON parsing.
2. JSON Schema validation.
3. Semantic validation.
4. Conversion to internal R list representation.
5. Backend-specific code generation.
6. Compilation/loading if applicable.

Do not put all logic into one large converter function.

`dynms_read()` must remain a small reader: it reads a JSON file with
`jsonlite::fromJSON(..., simplifyVector = FALSE)` and returns the raw R list.
It should not validate or normalize.

`dynms_validate_schema(raw_platform)` validates a raw DynMS document against the bundled
JSON Schema. It may accept either a file path or the raw R list returned by
`dynms_read()`. It does not validate the schema itself.

`dynms_validate_semantic(raw_platform)` is currently a placeholder for future
model-level integrity checks. Keep it in the public API, but do not add behavior
until semantic rules are intentionally implemented.

`dynms_normalize(raw_platform)` returns a plain R list. Do not add an S3 class
such as `dynms_platform` until there is a concrete need for S3 methods or
class-based dispatch.

## Suggested file structure

```text
R/
  read.R
  validate_schema.R
  validate_semantic.R
  normalize_dynms.R
  export_desolve.R
  export_mrgsolve.R
  generate_c_desolve.R
  compile.R
  simulate.R
  utils.R

inst/
  schema/
    dynms.schema.json
    dynms.schema.source.json
  templates/
    desolve_model.c.mustache
  examples/
    index.json
    *.json

tests/
  testthat/
    test-read.R
    test-validate-schema.R
    test-normalize.R
    test-generate-desolve-c.R
    test-export-desolve.R
    test-generate-mrgsolve-c.R
    test-export-mrgsolve.R
```

This structure may change, but keep the separation between reading, validation, normalization, export, compilation, and simulation.
The structure must follow the traditional CRAN R package layout.

Do not assume a specific example filename in `inst/examples`. User-provided
example files may change. Example files that should be used by tests or
documentation must be listed in `inst/examples/index.json`; do not scan the
folder at test time. Unit tests may also use inline temporary JSON fixtures for
schema-level platform documents.

## R dependencies

Prefer stable CRAN packages.

Recommended packages:

* `jsonlite` for reading and writing JSON.
* `jsonvalidate` for JSON Schema validation.
* `whisker` for Mustache-style templates.
* `deSolve` for the first simulation backend.
* `mrgsolve` for the second backend.
* `testthat` for tests.
* `withr` for temporary files and controlled environments.
* `fs` may be used for filesystem utilities if useful.
* `processx` may be used if robust external process execution becomes necessary.

Avoid unnecessary dependencies.

Do not require Node.js, npm, or heta-compiler for the core package.

## JSON handling

Use `jsonlite::fromJSON(..., simplifyVector = FALSE)` when reading DynMS files.

Reason: DynMS is closer to an AST/configuration tree than to tabular data. Automatic conversion of arrays to data frames may cause unexpected behavior.

Example:

```r
model <- jsonlite::fromJSON(path, simplifyVector = FALSE)
```

## JSON Schema validation

Use `jsonvalidate` for JSON Schema validation.

DynMSR should validate the raw DynMS JSON before attempting conversion or code generation.
The package must use the bundled local schema at `inst/schema/dynms.schema.json`
during normal operation.

The bundled schema is a vendored copy of an upstream schema. Its source URL is
recorded in `inst/schema/dynms.schema.source.json`. To refresh the local copy,
developers may run:

```sh
Rscript tools/update-dynms-schema.R
```

This update script is a manual development tool. Do not run it during package
installation, examples, tests, or CRAN checks. Do not require internet access
for normal package use.

The `source` field may be an `http(s)` URL or a local file path for development
environments where the upstream URL is not reachable. The script must leave the
existing local schema untouched if the download or local-file read fails.

Recommended flow:

```text
DynMS JSON file
    |
    v
dynms_read()
    |
    v
raw R list
    |
    v
dynms_validate_schema(raw_platform)
    |
    v
dynms_validate_semantic(raw_platform)
    |
    v
dynms_normalize(raw_platform)
```

JSON Schema should check structural rules:

* required fields;
* types;
* enums;
* patterns;
* array/object structure.

R semantic validation should check model-level rules:

* duplicate identifiers;
* missing state references;
* invalid parameter references;
* unsupported expressions;
* backend-specific limitations.

## Code generation strategy

The generator should be written in R.

Do not write a C program that reads JSON and generates C code.

Preferred approach:

```text
DynMS JSON -> R list/object -> prepared template data -> C code text
```

The generated C code is backend-specific output.

Most generation logic should live in R, while the C template should stay as simple as possible.

## Template engine

Prefer `whisker` for templates.

Reason:

* available on CRAN;
* simple;
* stable;
* suitable for code generation;
* encourages logic-less templates.

Template data should be prepared in R before rendering.

Avoid putting complex logic into templates.

Possible example:

```mustache
{{#parameters}}
double {{name}} = {{value}};
{{/parameters}}

{{#equations}}
ydot[{{index}}] = {{rhs}};
{{/equations}}
```

## deSolve backend

The first backend should generate C code compatible with compiled `deSolve` models.

Target pipeline:

```text
DynMS model
    |
    v
generated C source
    |
    v
R CMD SHLIB or equivalent compilation
    |
    v
dyn.load()
    |
    v
deSolve simulation object/interface
```

The public API may start with:

```r
raw_platform <- dynms_read("model.dynms.json")
dynms_validate_schema(raw_platform)
dynms_validate_semantic(raw_platform)
platform <- dynms_normalize(raw_platform)
model <- platform$models[[1]]
```

Later, backend-specific APIs should use explicit names such as:

```r
desolve_model <- dynms_export_desolve(model)
```

Function names are still experimental. Prefer explicit names for public API.

## mrgsolve backend

The second backend should export DynMS models to `mrgsolve`.

Target pipeline:

```text
DynMS model -> mrgsolve model source -> mrgsolve compilation/loading
```

Keep mrgsolve-specific assumptions out of the core DynMS parser.

## Heta integration

Heta support is optional and should not be required for normal DynMSR usage.

Future Heta pipeline:

```text
Heta source -> heta-compiler -> DynMS JSON -> DynMSR
```

If Heta integration is added, it should:

* detect whether `heta` is available;
* check for `heta` version compatibility;
* fail gracefully if not installed;
* not run during CRAN checks unless explicitly enabled;
* not require Node.js for core package installation.

## CRAN compatibility

Keep CRAN compatibility in mind from the beginning.

Important rules:

* Do not require internet access during installation, examples, or tests.
* Do not require heta-compiler to be installed for package checks.
* Do not require Node.js for package checks.
* Avoid writing outside temporary directories.
* Use `tempdir()` or `withr::local_tempdir()` for generated files.
* Guard optional examples with availability checks.
* Keep examples small and fast.
* Include at least one small DynMS example file in `inst/examples`.

Optional features should be skipped safely in tests when required external tools are unavailable.

Example:

```r
testthat::skip_if_not_installed("deSolve")
```

or for external executables:

```r
if (!heta_available()) {
  testthat::skip("heta-compiler is not available")
}
```

## Public API principles

Prefer clear names over short names.

Recommended naming style:

```r
dynms_read()
dynms_validate_schema()
dynms_validate_semantic()
dynms_normalize()
dynms_export_desolve()
dynms_export_mrgsolve()
dynms_compile()
dynms_simulate()
```

Avoid ambiguous names like:

```r
import()
convert()
compile()
run()
```

unless they are internal helpers.

Use internal helper functions for backend-specific work.

## Implementation sequence (preliminary)

### Phase 1 — Minimal DynMS reader

* Create package skeleton.
* Add `dynms_read()`.
* Read JSON using `jsonlite`.
* Return a raw R list.
* Do not validate or normalize in `dynms_read()`.
* Add minimal tests.

### Phase 2 — Validation

* Add DynMS JSON Schema file.
* Add `dynms_validate_schema(raw_platform)`.
* Use `jsonvalidate`.
* Add tests for valid and invalid DynMS files.

### Phase 2b — Semantic validation placeholder

* Add `dynms_validate_semantic(raw_platform)`.
* Keep it as a documented no-op placeholder until semantic rules are designed.

### Phase 3 — Normalization

* Add `dynms_normalize()`.
* Convert raw DynMS list into a stable internal plain-list representation.
* Resolve model list access.
* Normalize identifiers, states, parameters, equations, outputs.
* Do not add S3 classes until there is a concrete use for class-based behavior.

### Phase 4 — deSolve C generation

* Add a simple C template.
* Add `dynms_export_desolve()`.
* Generate C code from a minimal ODE model.
* Test generated text against expected output.
* Do not compile in the first test if avoidable.

### Phase 5 — Compilation

* Add code compilation via R-compatible tools.
* Compile generated C into a shared library.
* Load the library.
* Add tests guarded by platform/compiler availability.

### Phase 6 — Heta integration

* Add optional detection of heta-compiler.
* Add a helper for converting Heta to DynMS if useful.
* Keep this optional and separate from the core package.

### Phase 7 — deSolve simulation wrapper

* Add a small wrapper around `deSolve`.
* Run a simple simulation.
* Compare output with expected values for a trivial model.

### Phase 8 — mrgsolve export

* Add `dynms_export_mrgsolve()`.
* Generate mrgsolve model code.
* Add tests guarded by `mrgsolve` availability.


## Testing strategy

Test layers independently.

Recommended tests:

1. JSON reading.
2. Schema validation.
3. Normalization.
4. Semantic validation.
5. C code generation.
6. Compilation.
7. deSolve simulation.
8. mrgsolve export.

Generated code tests should not rely only on snapshot text. Where possible, test behavior using small models.

Use very small models:

* one-compartment decay;
* two-state conversion;
* model with parameters;
* model with outputs/observables.

## Documentation

All documentation, comments, and code comments must be written in English.

Use `roxygen2` for public function documentation and `NAMESPACE` generation.
Documentation should live in `#'` blocks next to the functions in `R/*.R`.
Do not edit generated `man/*.Rd` files or `NAMESPACE` by hand unless explicitly
fixing roxygen output; regenerate them with `roxygen2::roxygenise()`.

README should remain concise and user-oriented.

## Related projects

* DynMS specification:
  https://hetalang.github.io/hetacompiler/dynms.html

* heta-compiler:
  https://github.com/hetalang/heta-compiler

* HetaImporter.jl:
  https://github.com/hetalang/HetaImporter.jl

## Design principles

* DynMS is the canonical intermediate representation.
* DynMSR should work without Heta.
* Heta is an optional frontend, not a required dependency.
* Keep the core package small.
* Prefer R-native implementation for parsing and generation.
* Generate backend code rather than embedding backend logic everywhere.
* Separate format validation from semantic validation.
* Separate model representation from backend export.
* Avoid premature large framework design.

## Non-goals for the initial version

Do not implement everything at once.

Initial version should not try to be:

* a full modeling platform;
* a replacement for Heta;
* a replacement for deSolve or mrgsolve;
* a universal simulator;
* a GUI application;
* an AI agent framework.

## Notes for agents

When modifying the project:

* Keep changes small and testable.
* Prefer adding tests with each new feature.
* Keep tests independent from directory scans in `inst/examples`; use
  `inst/examples/index.json` for example discovery or inline temporary files
  for stable fixtures.
* Do not introduce Node.js unless explicitly requested.
* Do not make Heta a required dependency.
* Do not assume DynMS always comes from Heta.
* Do not modify `inst/schema/dynms.schema.json` or example JSON files in
  `inst/examples` unless the user explicitly asks for changes there. Updating
  `inst/examples/index.json` is appropriate when the example list changes.
* Do not hard-code paths outside the package or temporary directories.
* Do not generate files in the user working directory unless explicitly requested by the function contract.
* Keep generated files reproducible.
* Use clear error messages.
* Preserve CRAN compatibility where possible.
