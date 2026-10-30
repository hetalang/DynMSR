# Get one model from a platform

## Description

Selects one model from a DynMS platform by numeric index or by name.

## Usage

```r
get_model(platform, model)
```

## Arguments

* `platform`: A platform object returned by [dynms_load()](./dynms_load.md),
[heta_load()](./heta_load.md), or [sbml_load()](./sbml_load.md).
* `model`: A single model index or model name.

## Value

A model list.

## Examples

```r
dynms_path <- dynms_lib("repeated-dose")
platform <- dynms_load(dynms_path)
model <- get_model(platform, 1)
```
