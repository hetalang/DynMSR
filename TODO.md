# DynMSR TODO

This list records unfinished scope for the first public release. DynMSR uses
DynMS as a language-independent intermediate representation; Heta is an
optional DynMS producer, not a core dependency.

1. Provide a **deSolve** backend (planned) that generates compiled C compatible
  with the deSolve interface, builds it, and returns a usable backend object.
  **Complexity: high. Status: planned.**

2. Handle mrgsolve state-event detection for models without dynamic states.
   The current trigger check runs in `$ODE`, which is not called for these
   models, so conditional events such as `issues/01779` do not fire.
   **Status: planned.**

3. Check the DynMS version supported by heta-compiler before building a Heta
   project, once a future compiler release exposes that version through its
   CLI. Until then, check the version of the exported DynMS document during
   loading; the compiler's DynMS version cannot be checked before the build.
   **Status: waiting for heta-compiler support.**
