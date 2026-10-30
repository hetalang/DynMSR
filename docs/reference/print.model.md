# Print a DynMS model

## Description

Displays a compact inventory of model components and their identifiers.

## Usage

```r
# S3 method for model
print(x, ...)
```

## Arguments

* `x`: A DynMS model object.
* `...`: Unused.

## Value

`x`, invisibly.

## Examples

```r
model <- get_model(dynms_load(dynms_lib("first-order-decay")), 1)
print(model)
```
