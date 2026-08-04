# Regions present at a level

Regions present at a level

## Usage

``` r
geo_regions(x, level)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- level:

  A single level name.

## Value

A character vector of region codes, in the object's canonical order.

## Examples

``` r
gs <- geoscale_example()
geo_regions(gs, "state")
#> [1] "N1" "N2" "S1"
```
