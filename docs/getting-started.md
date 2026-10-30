# Getting started with DynMSR

DynMSR loads models from DynMS JSON and prepares individual models for R
simulation backends. DynMS JSON can come from any compatible frontend; Heta and
SBML are optional sources that require `heta-compiler`.

## Load and select a model

The package includes small DynMS examples. The first-order decay example can
be loaded without external tools or network access:

```r
library(DynMSR)

platform <- dynms_load(dynms_lib("first-order-decay"))
model <- get_model(platform, 1)
model
#> <DynMS model: first_order_decay>
#>   Dynamic states (1): amount
#>   Static states (0): none
#>   Constants (2): ke, volume
#>   Assignments (1): concentration
#>   Time events (0): none
#>   Events (0): none
#>   Observables (2): amount, concentration
```

For your own DynMS document, pass its file path to `dynms_load()` instead.
A platform may contain several models; select one before calling a backend
function.

## Generate or build an mrgsolve model

`write_mrgsolve()` writes backend source to a path you choose. `build_mrgsolve()`
compiles a model when the optional `mrgsolve` package is installed. The
following commands are shown without running a compiler during vignette builds:

```r
source_file <- tempfile(fileext = ".mod")
write_mrgsolve(model, source_file)

compiled <- build_mrgsolve(model)
simulation <- mrgsolve::mrgsim_df(compiled, end = 24, delta = 1)
```
