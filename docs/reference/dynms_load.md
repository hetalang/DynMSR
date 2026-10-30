# Load a DynMS platform

## Description

Reads a DynMS JSON file, validates it against the bundled schema for its
`dynms` version, runs backend-independent semantic validation, and returns a
platform list.

## Usage

```r
dynms_load(path)
```

## Arguments

* `path`: Path to a DynMS JSON file.

## Details

Schema and semantic validation are both attempted before loading fails.
Validation messages are reported with `message()`, followed by one final
error when any validation issue is found.
DynMSR currently supports only expressions with `format: "math-json"`.

## Value

A platform list. Use `platform$models[[i]]` to select one model for
backend-specific operations.

## Examples

```r
platform <- dynms_load(dynms_lib("two-state-conversion"))
platform
```
