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
