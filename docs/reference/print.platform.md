# Print a DynMS platform

## Description

Displays the DynMS version and a compact summary of each model in a
platform.

## Usage

```r
# S3 method for platform
print(x, ...)
```

## Arguments

* `x`: A DynMS platform object.
* `...`: Unused.

## Value

`x`, invisibly.

## Examples

```r
platform <- dynms_load(dynms_lib("first-order-decay"))
print(platform)
```
