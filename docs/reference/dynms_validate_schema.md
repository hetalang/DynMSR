# Validate a DynMS document against the JSON Schema

## Description

Validates a DynMS document against a JSON Schema. The document can be passed
as a file path or as the raw R list returned by [dynms_read()](./dynms_read.md). Validation
selects a bundled local schema using the document's `dynms` version. It uses
the `ajv` engine because the bundled schemas use modern JSON Schema features.

## Usage

```r
dynms_validate_schema(x, error = FALSE)
```

## Arguments

* `x`: Path to a DynMS JSON file, or the raw R list returned by
[dynms_read()](./dynms_read.md).
* `error`: Whether schema validation errors should be raised as one R
error after all available issues are collected.

## Value

A list with `valid`, `errors`, and `warnings` fields.

## Examples

```r
validation <- dynms_validate_schema(dynms_lib("first-order-decay"))
validation$valid
```
