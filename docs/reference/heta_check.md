# Check Heta compiler availability

## Description

Checks whether the `heta` command is available, can report its version with
`heta --version`, and satisfies the bundled DynMSR compatibility rule.

## Usage

```r
heta_check()
```

## Value

A list with `available`, `supported`, `command`, `version`,
`supported_version`, `installation_url`, `output`, and `message` fields.

## Examples

```r
heta_check()
```
