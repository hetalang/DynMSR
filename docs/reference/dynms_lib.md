# Locate bundled DynMS examples

## Description

Returns the available example names or the path to one bundled DynMS JSON
file. Use [dynms_load()](./dynms_load.md) to load the selected example.

## Usage

```r
dynms_lib(name = NULL)
```

## Arguments

* `name`: Name of a bundled example. If `NULL`, returns all available
names.

## Value

If `name` is `NULL`, a character vector of example names. Otherwise,
the path to the selected DynMS JSON file.

## Examples

```r
dynms_lib()
platform <- dynms_load(dynms_lib("first-order-decay"))
```
