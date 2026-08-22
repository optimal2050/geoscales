# Subset a Geoscale by region

Keeps only the atoms belonging to `region` at `geoframe`, and rebuilds
the member vocabularies accordingly. Geometry, when attached, is subset
in step.

## Usage

``` r
filter_geoscale(x, geoframe, region, drop_empty_geoframes = FALSE)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- geoframe:

  Geoframe that `region` belongs to.

- region:

  Character vector of region codes to keep.

- drop_empty_geoframes:

  Drop geoframes left with no codes at all.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Examples

``` r
gs <- geoscale_example()
filter_geoscale(gs, "country", "N")
#> Geoscale: example 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom 
#> Geoframes (4, coarsest first):
#>   - country (1)
#>     - state (2)
#>       - zone (2)
#>         - atom (4)
#> Atoms: 4
#> Weights: km2, pop (default: km2)
```
