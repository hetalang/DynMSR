# DynMSR 0.1.2

- Added support for DynMS 0.2.2 alongside the existing 0.2.1 support.
  Heta integration is tested with heta-compiler 0.12.2 and 0.12.3.
- Added validation of DynMS 0.2.2 `scenarios`. Scenario execution is not yet implemented.
- Fixed event action ordering in `write_mrgsolve()`: all right-hand sides are
  evaluated from the pre-event state before any assignments are applied.
- Corrected one-argument MathJSON `Log` in mrgsolve code generation to use
  base 10. Explicit-base logarithms continue to use change of base.

# DynMSR 0.1.1

- Added `dynms_lib()` and three bundled DynMS models: first-order decay,
  two-state conversion, and repeated dosing. These provide small working
  examples for loading, code generation, and simulation.
- `heta_build()` now requires explicit project and output directories. All Heta
  compiler output is written below the supplied output directory.
- `heta_load()` and `sbml_load()` accept an optional output directory. When it
  is omitted, their intermediate compiler output is kept in a temporary
  directory and removed after loading.
- `write_mrgsolve()` now requires an explicit output file path. `build_mrgsolve()`
  continues to manage its temporary source file automatically.
- Added examples for all public functions and expanded optional `mrgsolve`
  examples to include a simulation.

# DynMSR 0.1.0

Initial CRAN release.

- Read, validate, and load DynMS JSON models into R.
- Work with platforms that contain one or more models.
- Load Heta projects through an optional compatible `heta-compiler` installation.
- Load SBML models through an optional compatible `heta-compiler` installation.
- Generate and build `mrgsolve` simulation models from DynMS models.
