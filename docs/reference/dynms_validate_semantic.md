# Validate DynMS semantic consistency

## Description

Validates backend-independent semantic consistency of a schema-valid raw
DynMS platform object. Unlike schema validation, this function collects all
currently known semantic issues before returning. It does not validate the
document structure; use [dynms_validate_schema()](./dynms_validate_schema.md) first when the input has
not already passed schema validation.

## Usage

```r
dynms_validate_semantic(raw_platform, error = FALSE)
```

## Arguments

* `raw_platform`: Raw DynMS platform object, typically returned by
[dynms_read()](./dynms_read.md).
* `error`: Whether semantic validation errors should be raised as one R
error after all issues are collected.

## Value

A list with `valid`, `errors`, and `warnings` fields.

## Examples

```r
raw_platform <- dynms_read(dynms_lib("first-order-decay"))
validation <- dynms_validate_semantic(raw_platform)
validation$valid
```
