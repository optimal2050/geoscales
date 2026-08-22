# Regions present at a geoframe (the members)

Regions present at a geoframe (the members)

## Usage

``` r
geoscale_regions(x, geoframe)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- geoframe:

  A single geoframe name.

## Value

A character vector of region codes, in the object's canonical order.

## Examples

``` r
gs <- geoscale_example()
geoscale_regions(gs, "state")
#> [1] "N1" "N2" "S1"
```
