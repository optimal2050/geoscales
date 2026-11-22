# A small example GeoScale

A synthetic 3-geoframe hierarchy used in examples and tests. It
deliberately reproduces three awkward features of real region tables:

## Usage

``` r
geoscale_example()
```

## Value

A
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
with 7 leaves and geoframes `country`/`state`/`zone`/`cell`.

## Details

- a code (`"N1"`) reused at more than one geoframe, so bare codes are
  ambiguous and every lookup must name its geoframe;

- a non-nesting pair of geoframes — zone `"ZB"` draws leaves from two
  different states (and two different countries), so `state` and `zone`
  do not form a tree;

- a leaf (`"ROW"`) with no code at any coarser geoframe (partial
  coverage).

## Examples

``` r
gs <- geoscale_example()
gs
#> GeoScale: example 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned leaf 
#> Geoframes (4, coarsest first):
#>   - country (2)  [1 leaf region(s) unassigned]
#>     - state (3)  [1 leaf region(s) unassigned]
#>       - zone (3)  [1 leaf region(s) unassigned]
#>         - cell (7)
#> Leaves: 7
#> Weights: km2, pop (default: km2)
geoscale_nests(gs, "state", "zone")   # FALSE - they cross-cut
#> [1] FALSE
#> attr(,"offenders")
#> [1] "ZB"
```
