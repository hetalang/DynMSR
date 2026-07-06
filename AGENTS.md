# Instructions for AI agents

## Project identity

**DynMSR** is an R toolkit for working with models stored in the **DynMS**
format. DynMS is the canonical, language-independent intermediate
representation for Systems Biology and Systems Pharmacology models.

DynMSR must be positioned as an interoperability toolkit between DynMS and the
R modeling ecosystem. Do not describe or design it as only:

* a Heta importer;
* a deSolve wrapper;
* a simulator.

Heta is one optional frontend that can produce DynMS. DynMSR must work with
DynMS JSON files independently of Heta.

Target direction:

```text
Heta or other frontend -> DynMS JSON -> DynMSR -> deSolve / mrgsolve / future R backends
```

Initial backend priorities:

```text
DynMS JSON -> deSolve C code -> compiled shared library -> deSolve model
DynMS JSON -> mrgsolve C code -> compiled shared library -> mrgsolve model
```

## Architecture

Keep the implementation staged. Do not collapse reading, validation,
normalization, code generation, compilation, and simulation into one converter.

Preferred pipeline:

```text
dynms_read()
  -> dynms_validate_schema()
  -> dynms_validate_semantic()
  -> dynms_normalize()
  -> dynms_write_mrgsolve(filepath, model)
```

Important function boundaries:

* `dynms_read(path)` is a small reader only. It uses
  `jsonlite::fromJSON(path, simplifyVector = FALSE)` and returns the raw R
  list. It must not validate or normalize.
* `dynms_validate_schema(raw_platform)` validates raw DynMS JSON against the
  bundled schema. It may accept a file path or a raw list returned by
  `dynms_read()`. It validates DynMS documents, not the schema itself.
* `dynms_validate_semantic(raw_platform)` is a public placeholder for future
  model-level checks. Do not add behavior until semantic rules are deliberately
  designed.
* `dynms_normalize(raw_platform)` returns a plain R list. Do not add S3 classes
  such as `dynms_platform` until there is a concrete dispatch need.
* `dynms_write_mrgsolve(filepath, model)` writes mrgsolve source for one
  normalized model, not a whole platform. Callers choose `platform$models[[i]]`.

Core parsing and generation should be R-native. Generate backend code from
prepared R data structures. Do not write a C program that reads JSON and emits
C.

## Package layout

Follow a traditional CRAN R package layout and keep concerns separated:

```text
R/
  read.R
  validate_schema.R
  validate_semantic.R
  normalize.R
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
  examples/
    index.json
    *.json

tests/
  testthat/
```

The exact files may change, but keep reading, validation, normalization,
backend export, compilation, and simulation separate.

Do not assume a specific example filename in `inst/examples`. Examples used by
tests or documentation must be listed in `inst/examples/index.json`. Do not
scan the examples directory at test time. Unit tests may use inline temporary
fixtures or explicit fixture files for error cases.

## Dependencies

Prefer stable CRAN packages and avoid unnecessary dependencies.

Recommended packages:

* `jsonlite` for JSON reading/writing.
* `jsonvalidate` for JSON Schema validation.
* `whisker` for Mustache templates.
* `deSolve` for the first simulation backend.
* `mrgsolve` for the second backend.
* `testthat` for tests.
* `withr` for temporary files and controlled environments.
* `fs` or `processx` only when they remove real complexity.

Do not require Node.js, npm, or `heta-compiler` for the core package.

## JSON and schema handling

Always parse DynMS JSON with:

```r
jsonlite::fromJSON(path, simplifyVector = FALSE)
```

DynMS documents are tree-like model descriptions, not tables; automatic data
frame simplification can corrupt structure.

Use the bundled local schema at `inst/schema/dynms.schema.json` for normal
operation. The source of that vendored schema is recorded in
`inst/schema/dynms.schema.source.json`.

Developers may refresh the local schema manually with:

```sh
Rscript tools/update-dynms-schema.R
```

The update script is a development tool only. Do not run it during package
installation, examples, tests, or CRAN checks. Normal package use must not
require internet access. If downloading or reading a local schema source fails,
the existing bundled schema must remain unchanged.

JSON Schema validation should cover structural rules such as required fields,
types, enums, patterns, and object/array shape. R semantic validation should
cover model-level rules such as duplicate identifiers, missing references,
unsupported expressions, and backend limitations.

## Backend generation

Keep backend assumptions out of the core DynMS parser.

For generated code:

* Prepare template data in R.
* Template data should preserve the normalized model shape. Add backend helper
  fields to existing objects instead of creating parallel collections such as
  `dynamic_states`, `static_states`, or `time_events`.
* Convert MathJSON expressions to backend expressions in R before rendering.
  Do not implement expression conversion in Mustache templates.
* Keep templates logic-light.
* Prefer `whisker` for Mustache-style templates.
* Make generated files reproducible.
* Use temporary directories unless a public function explicitly promises an
  output path.

For deSolve, target compiled C compatible with `R CMD SHLIB`, `dyn.load()`, and
deSolve's compiled model interface.

For mrgsolve, generate mrgsolve model source and keep compilation/loading logic
backend-specific. Use package-internal template path constants initialized with
`system.file(..., mustWork = TRUE)`; do not expose path helper functions unless
there is a real public API need.

## CRAN compatibility

Preserve CRAN compatibility from the beginning:

* No internet access during installation, examples, tests, or checks.
* No required Node.js, npm, Heta, or external compiler frontend.
* Write generated files only under temporary directories unless explicitly
  requested by the function contract.
* Guard optional backend tests and examples with availability checks such as
  `testthat::skip_if_not_installed("deSolve")`.
* Keep examples small and fast.

## Public API

Prefer explicit names:

```r
dynms_read()
dynms_validate_schema()
dynms_validate_semantic()
dynms_normalize()
dynms_export_desolve()
dynms_write_mrgsolve()
dynms_compile()
dynms_simulate()
```

Avoid ambiguous public names such as `import()`, `convert()`, `compile()`, or
`run()`. Use internal helpers for backend-specific implementation details.

## Testing

Test layers independently:

1. JSON reading.
2. Schema validation.
3. Semantic validation.
4. Normalization.
5. Code generation.
6. Compilation.
7. deSolve simulation.
8. mrgsolve export.

Prefer small models such as one-compartment decay, two-state conversion,
parameterized models, and models with observables.

Generated code tests should not rely only on snapshots. Where feasible, test
behavior with small models. Optional backend or compiler tests must skip safely
when required tools are unavailable.

Run local tests with:

```sh
Rscript -e "pkgload::load_all('.'); testthat::test_dir('tests/testthat')"
```

## Documentation

All documentation, comments, and code comments must be in English.

Use `roxygen2` for public function documentation and for generating
`NAMESPACE` and `man/*.Rd`. Documentation should live in `#'` blocks next to
functions in `R/*.R`.

Do not edit generated `man/*.Rd` files or `NAMESPACE` by hand unless explicitly
fixing generated output. Regenerate with:

```sh
Rscript -e "roxygen2::roxygenise()"
```

Keep the README concise and user-oriented.

## Heta integration

Heta support is optional. If added, it must:

* detect whether Heta tooling is available;
* check version compatibility where relevant;
* fail gracefully when not installed;
* stay separate from core DynMS parsing;
* not run during CRAN checks unless explicitly enabled.

## Non-goals for the initial version

Do not try to build everything at once. The initial version should not become:

* a full modeling platform;
* a replacement for Heta;
* a replacement for deSolve or mrgsolve;
* a universal simulator;
* a GUI application;
* an AI agent framework.

## Agent rules

When modifying the project:

* Keep changes small and testable.
* Add or update focused tests with behavior changes.
* Preserve the staged architecture and CRAN constraints above.
* Do not make Heta or Node.js required.
* Do not assume DynMS always comes from Heta.
* Do not hard-code paths outside the package or temporary directories.
* Use clear error messages.
* Do not modify `inst/schema/dynms.schema.json` or example JSON files in
  `inst/examples` unless explicitly asked. Updating `inst/examples/index.json`
  is appropriate when the listed examples change.

## Related projects

* DynMS specification:
  https://hetalang.github.io/hetacompiler/dynms.html
* heta-compiler:
  https://github.com/hetalang/heta-compiler
* HetaImporter.jl:
  https://github.com/hetalang/HetaImporter.jl
