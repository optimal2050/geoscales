# Geoframes of a GeoScale

The hierarchy names, ordered coarsest first. The last entry is the atom
geoframe — the finest regions, which every other geoframe groups.

## Usage

``` r
geoscale_geoframes(x, finest = FALSE)

# S3 method for class 'GeoScale'
names(x)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

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
