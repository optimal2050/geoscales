# Levels of a Geoscale

The hierarchy names, ordered coarsest first. The last entry is the atom
level — the finest regions, which every other level groups.

## Usage

``` r
geoscale_levels(x, finest = FALSE)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- finest:

  Return only the finest (atom) level.

## Value

A character vector of level names, or a single name when
`finest = TRUE`.

## Examples

``` r
gs <- geoscale_example()
geoscale_levels(gs)
#> [1] "country" "state"   "zone"    "atom"   
geoscale_levels(gs, finest = TRUE)
#> [1] "atom"
```
