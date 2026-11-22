# Geoframes of a GeoScale

The hierarchy names, ordered coarsest first. The last entry is the leaf
geoframe — the finest regions, which every other geoframe groups.

## Usage

``` r
geoscale_geoframes(x, finest = FALSE, visible = NULL)

# S3 method for class 'GeoScale'
names(x)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

- finest:

  Return only the finest (leaf) geoframe; with `visible = TRUE`, the
  finest visible one.

- visible:

  `NULL` (default) returns every geoframe. `TRUE` returns those shown in
  plots, `FALSE` those hidden from them (see
  [`hide_geoframes_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/hide_geoframes_geoscale.md)).

## Value

A character vector of geoframe names, or a single name when
`finest = TRUE`.

## Examples

``` r
gs <- geoscale_example()
geoscale_geoframes(gs)
#> [1] "country" "state"   "zone"    "cell"   
geoscale_geoframes(gs, finest = TRUE)
#> [1] "cell"
```
