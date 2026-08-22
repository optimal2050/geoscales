# Collapse a Geoscale to a coarser geoframe

Returns a new
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
whose atom layer is `geoframe`, dropping every finer geoframe. Weights
are summed over the collapsed atoms.

## Usage

``` r
prune_geoscale(x, geoframe)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- geoframe:

  The geoframe to become the new atom layer.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Examples

``` r
prune_geoscale(geoscale_example(), "state")
#> Geoscale: example 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom 
#> Geoframes (2, coarsest first):
#>   - country (2)
#>     - state (3)
#> Atoms: 3
#> Weights: km2, pop (default: km2)
```
