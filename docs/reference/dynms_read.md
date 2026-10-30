# Read a DynMS JSON file

## Description

Reads a DynMS JSON file into an R list. DynMS documents are parsed with
`jsonlite::fromJSON(..., simplifyVector = FALSE)` to preserve the document
structure.

## Usage

```r
dynms_read(path)
```

## Arguments

* `path`: Path to a DynMS JSON file.

## Value

An R list parsed from JSON.

## Examples

```r
path <- dynms_lib("first-order-decay")
dynms_read(path)
```
