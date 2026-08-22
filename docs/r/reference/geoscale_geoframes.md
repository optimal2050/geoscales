# Geoframes of a Geoscale

The hierarchy names, ordered coarsest first. The last entry is the atom
geoframe — the finest regions, which every other geoframe groups.

## Usage

``` r
geoscale_geoframes(x, finest = FALSE)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- finest:

  Return only the finest (atom) geoframe.

## Value

A character vector of geoframe names, or a single name when
`finest = TRUE`.

## Examples

``` r
gs <- geoscale_example()
geoscale_geoframes(gs)
#> [1] "country" "state"   "zone"    "atom"   
geoscale_geoframes(gs, finest = TRUE)
#> [1] "atom"
```
