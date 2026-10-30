# Compile a DynMS model with mrgsolve

## Description

Generates an mrgsolve model source file and compiles it with `mrgsolve`.
The `mrgsolve` package is optional and is required only when this function is
called.

## Usage

```r
build_mrgsolve(model, filepath = NULL, observables = NULL, ...)
```

## Arguments

* `model`: A model list, such as one element of `platform$models`.
* `filepath`: Optional path for the intermediate mrgsolve model source.
If omitted, it is written to a temporary file.
* `observables`: Optional character vector of additional model symbols to
return from mrgsolve. Dynamic states and symbols already listed in the
DynMS model's `observables` are skipped. Every requested symbol must exist
as a DynMS constant, dynamic state, static state, or assignment. Symbols
renamed for mrgsolve are returned under their generated backend names.
* `...`: Additional arguments passed to [mrgsolve::mread()](https://rdrr.io/pkg/mrgsolve/man/mread.html).

## Value

A compiled mrgsolve model object.

## Examples

```r
if (requireNamespace("mrgsolve", quietly = TRUE)) {
  model <- get_model(dynms_load(dynms_lib("repeated-dose")), 1)
  compiled <- build_mrgsolve(model, observables = "ke", quiet = TRUE)
  simulation <- mrgsolve::mrgsim_df(compiled, end = 48, delta = 0.1)
}
```
