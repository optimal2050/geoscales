# Subset a Geoscale by region

Keeps only the atoms belonging to `region` at `level`, and rebuilds the
member vocabularies accordingly. Geometry, when attached, is subset in
step.

## Usage

``` r
filter_geoscale(x, level, region, drop_empty_levels = FALSE)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- level:

  Level that `region` belongs to.

- region:

  Character vector of region codes to keep.

- drop_empty_levels:

  Drop levels left with no codes at all.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Examples

``` r
gs <- geoscale_example()
filter_geoscale(gs, "country", "N")
#> Geoscale: example 
#> Description: Synthetic example: reused code, non-nesting level pair, and an unassigned atom 
#> Levels (4, coarsest first):
#>   - country (1)
#>     - state (2)
#>       - zone (2)
#>         - atom (4)
#> Atoms: 4
#> Weights: km2, pop (default: km2)
```
