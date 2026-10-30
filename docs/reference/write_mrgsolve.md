# Write an mrgsolve model file

## Description

Generates mrgsolve source from one DynMS model.

## Usage

```r
write_mrgsolve(model, filepath)
```

## Arguments

* `model`: A model list, such as one element of `platform$models`.
* `filepath`: Path where the generated model source should be written.

## Details

The exporter warns and ignores unsupported DynMS features: algebraic dynamic
states, `stopSimulation`, and state-event trigger `detection`. Algebraic
states are emitted as ordinary ODE states; state-event conditions are
evaluated in generated code without root finding. The current exporter
evaluates state-event conditions in `$ODE`, which mrgsolve may call at
internal trial times. The resulting state update can therefore occur at an
output record before or after the true threshold crossing. Smaller `delta` or `hmax` values can sometimes make the approximation closer, but cannot
reproduce the exact root-crossing time or guarantee which side of the
threshold an event will be placed.
Identifiers reserved by mrgsolve are renamed with an `_rnm_` suffix. Further
numeric suffixes are added when needed to avoid collisions. The exporter
emits one warning and records the complete mapping in the generated model.
The DynMS time symbol `t` is emitted as `SOLVERTIME` in `$ODE` and as `TIME` in other blocks.

## Value

The path to the generated model file.

## Examples

```r
model <- get_model(dynms_load(dynms_lib("first-order-decay")), 1)
path <- tempfile(fileext = ".mod")
write_mrgsolve(model, path)
unlink(path)
```
