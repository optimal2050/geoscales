# Core spatial levels

Recommended level names, ordered coarsest first. Analogue of
[`timescales::CORE_TIMEFRAMES`](https://optimal2050.github.io/timescales/r/reference/CORE_TIMEFRAMES.html).

## Usage

``` r
CORE_LEVELS
```

## Format

A character vector of length 6.

## Details

These are guidance only.
[`geoscale_from_leaves()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaves.md)
accepts any syntactically valid level name; see
[`is_valid_level()`](https://optimal2050.github.io/geoscales/r/reference/is_valid_level.md).

## Examples

``` r
CORE_LEVELS
#> [1] "GLOBE"     "CONTINENT" "COUNTRY"   "STATE"     "ZONE"      "CELL"     
```
