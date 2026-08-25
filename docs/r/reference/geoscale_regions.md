# Regions present at a geoframe (the members)

The required-geoframe rule applies to arguments that take region CODES
(codes repeat across geoframes, so nothing is ever inferred from a bare
code); `geoframe` here only selects the output, so it may default to the
finest geoframe (the atoms) — the twin of
`timescales::calendar_timeslices(x, timeframe = NULL)`.

## Usage

``` r
geoscale_regions(x, geoframe = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- geoframe:

  A single geoframe name, or `NULL` (default) for the finest geoframe.

## Value

A character vector of region codes, in the object's canonical order.

## Examples

``` r
gs <- geoscale_example()
geoscale_regions(gs, "state")
#> [1] "N1" "N2" "S1"
geoscale_regions(gs)          # the atoms
#> [1] "A1"  "A2"  "A3"  "A4"  "A5"  "A6"  "ROW"
```
