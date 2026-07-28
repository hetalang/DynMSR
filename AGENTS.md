# Instructions for AI agents

## Project direction

**DynMSR** is an R interoperability toolkit for models stored in the **DynMS**
format. Treat DynMS as a language-independent intermediate representation for
Systems Biology and Systems Pharmacology models.

Do not narrow the project to a Heta importer, a deSolve wrapper, or a simulator.
Heta is one optional DynMS producer; DynMSR must also work with DynMS JSON files
that come from other frontends.

The intended flow is:

```text
Heta or other frontend -> DynMS JSON -> DynMSR -> deSolve / mrgsolve / future R backends
```

Keep the initial scope focused on DynMS loading, validation, platform/model
objects, backend code generation, and backend-specific build helpers.

## Architecture

Keep the implementation staged. Do not collapse reading, schema validation,
semantic validation, platform construction, backend preparation, code
generation, compilation, and simulation into one converter.

Core boundaries:

* `dynms_read(path)` is a small JSON reader only. It must parse with
  `jsonlite::fromJSON(path, simplifyVector = FALSE)` and must not validate,
  construct platform objects, or prepare backend data.
* `dynms_load(path)` is the normal user-facing DynMS loader. It may read,
  validate, and construct a `platform`.
* `dynms_validate_schema()` validates DynMS documents against the bundled local
  schema, not the schema itself.
* `dynms_validate_semantic()` is for backend-independent model checks. Add new
  semantic rules deliberately, collect all relevant issues where practical, and
  cover them with focused tests. DynMSR currently supports only
  `format: "math-json"` expressions; schema-valid line-expression formats must
  fail semantic validation with a clear message.
* `new_platform()` is an internal constructor for light S3 markers:
  top-level `platform` and per-model `model`. Do not put backend preparation
  there.

After loading, `platform` and `model` are the primary working objects. Backend
functions operate on one `model`; if a `platform` is passed, fail clearly and
tell the user to select a model first, for example with `platform$models[[1]]`
or `get_model(platform, 1)`.

Core parsing and generation should be R-native. Generate backend code from R
data structures; do not write a C program that reads DynMS JSON and emits C.

Identifier renaming is a staged transformation:

* backend-specific code decides which identifiers need renaming and constructs
  the mapping;
* the internal backend-independent `rename_model_identifiers()` applies an
  explicit mapping to a copy of one model, including definitions, MathJSON
  references, event-action targets, and observables;
* backend writers consume the renamed copy and retain the mapping for warnings
  and generated-source documentation.

Do not mutate the loaded model during backend preparation. Keep
`rename_model_identifiers()` internal unless a concrete public workflow
requires exposing it.

## Public API

Use names that reflect the layer where the function belongs.

Use the `dynms_` prefix for DynMS-format operations such as reading, loading,
and validation. Use backend-specific names for operations that start from a
single `model`, such as `write_mrgsolve()` and `build_mrgsolve()`.

`write_*()` functions write backend source files. `build_*()` functions may
generate temporary source, compile or load backend code, and return a usable
backend object.

Avoid ambiguous public names such as `import()`, `convert()`, `compile()`,
`simulate()`, `models()`, or `run()`. Keep new public helpers out of the API
unless there is a concrete user workflow that needs them.

Keep S3 classes `platform` and `model` as light object markers for now.

Do not add a public general `dynms_normalize()` unless a real
backend-independent normal form is deliberately designed and documented.
Backend-specific preparation and rename-policy construction should remain
backend-specific. Reusable structural transformations may be internal
backend-independent helpers.

## Backend generation

Keep backend assumptions out of the core DynMS parser.

For generated code:

* Prepare template data in R inside the relevant backend writer/builder.
* Apply backend-specific identifier mappings before expression conversion and
  template rendering. Do not embed backend rename mappings in generic
  MathJSON-to-code converters.
* Preserve the model shape where practical. Prefer helper fields on existing
  objects over parallel backend-only collections.
* Convert MathJSON expressions to backend expressions in R before rendering.
* Keep templates logic-light and generated files reproducible.
* Use temporary directories unless a public function explicitly promises an
  output path.

For deSolve, target compiled C compatible with `R CMD SHLIB`, `dyn.load()`, and
deSolve's compiled model interface.

For mrgsolve, generate mrgsolve model source and keep compilation/loading logic
backend-specific. Template paths should remain package-internal unless there is
a real public API need. Construct reserved-identifier mappings from
`inst/templates/reserved-words.json`, apply them with
`rename_model_identifiers()`, emit one informative warning, and record the
mapping in the generated source. Use deterministic names: prefer an `_rnm_`
suffix, add numeric suffixes to resolve collisions, and use a safe prefix when
an mrgsolve compartment-dependent reserved pattern would still match.

The DynMS symbol `t` is the global time symbol, not a model identifier. The
schema must reject `t` wherever the shared identifier definition is used. In
mrgsolve expressions, render `t` as `SOLVERTIME` in `$ODE` and as `TIME` in
other blocks; keep this context-specific rule out of general identifier
renaming.

If an mrgsolve model requests `dynamic[].algebraic = true`,
`stopSimulation = true`, or an explicit state-event `detection` mode, generate
the model while emitting an informative warning that the feature is ignored or
approximated. Keep these limitations documented in `write_mrgsolve()`. For time
events, schedule repetitions only when the evaluated `period` is positive.

## Schema, examples, and CRAN constraints

Normal package use must rely on the bundled schema and must not require internet
access. The schema update script is a manual development tool only; do not run
it during installation, examples, tests, or checks. If schema refresh fails, the
existing bundled schema must remain unchanged.

`constants[].value` is numeric-only. Keep that type rule in schema validation;
do not reintroduce constant-expression handling in semantic validation or
backend preparation.

Do not assume a specific example filename. Examples used by tests or
documentation must be listed in `inst/examples/index.json`; do not scan the
examples directory at test time.

Preserve CRAN compatibility:

* no internet access during installation, examples, tests, or checks;
* no required Node.js, npm, Heta, or external compiler frontend in the core
  package;
* generated files go under temporary directories unless explicitly requested by
  the function contract;
* optional backend tests and examples must skip safely when required packages or
  tools are unavailable;
* examples stay small and fast.

Prefer stable CRAN packages and avoid dependencies that do not remove real
complexity.

## Testing

Test each layer independently: reading, schema validation, semantic validation,
platform construction, identifier remapping, expression conversion, code
generation, backend build helpers, and public API behavior.

Package tests should cover DynMSR implementation details and use external
benchmark suites only for interoperability or reference behavior. Keep
implementation-specific regressions in this package.

Validation and error-handling tests should cover invalid JSON or source data,
missing fields, duplicate identifiers, unknown references, unsupported model
constructs, invalid argument combinations, and stable informative errors.
Unsupported features must not be silently ignored. Backend features that are
intentionally ignored while generation continues must produce an informative
warning and be documented in the relevant public writer.

Backend tests should check generated code structure, state and parameter
ordering, backend-specific declarations, temporary file behavior, compilation,
and dynamic loading when the relevant backend is available.

Prefer small fixtures such as one-compartment decay, two-state conversion,
parameterized models, and models with observables. Generated code tests should
not rely only on snapshots; where feasible, test behavior with small models.

Every fixed bug should receive a minimal regression test.

Run local tests with:

```sh
Rscript -e "pkgload::load_all('.'); testthat::test_dir('tests/testthat')"
```

## Documentation

All documentation, comments, and code comments must be in English.

Use roxygen2 for public function documentation and generated `NAMESPACE` and
`man/*.Rd` files. Do not edit generated documentation by hand unless explicitly
fixing generated output. Regenerate with:

```sh
Rscript -e "roxygen2::roxygenise()"
```

Keep the README concise and user-oriented.

## Heta integration

Heta support is optional and must stay separate from core DynMS parsing. If Heta
workflows are changed, they must detect unavailable tooling, fail gracefully,
avoid CRAN-time execution unless explicitly enabled, and must not make Node.js,
npm, or heta-compiler core package requirements.

## Agent rules

When modifying the project:

* Keep changes small and testable.
* Add or update focused tests with behavior changes.
* Preserve the staged architecture and CRAN constraints above.
* Do not assume DynMS always comes from Heta.
* Do not hard-code paths outside the package or temporary directories.
* Use clear error messages.
* Do not modify `inst/schema/dynms.schema.json` or example JSON files in
  `inst/examples` unless explicitly asked. Updating `inst/examples/index.json`
  is appropriate when listed examples change.
