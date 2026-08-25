# Core spatial geoframes

Recommended geoframe names, ordered coarsest first. Analogue of
[`timescales::CORE_TIMEFRAMES`](https://optimal2050.github.io/timescales/r/reference/CORE_TIMEFRAMES.html).

## Usage

``` r
CORE_GEOFRAMES
```

## Format

A character vector of length 6.

## Details

These are guidance only.
[`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md)
accepts any syntactically valid geoframe name; see
[`is_valid_geoframe()`](https://optimal2050.github.io/geoscales/r/reference/is_valid_geoframe.md).

## Examples

``` r
CORE_GEOFRAMES
#> [1] "GLOBE"     "CONTINENT" "COUNTRY"   "STATE"     "ZONE"      "CELL"     
```
