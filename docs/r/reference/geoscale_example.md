# A small example Geoscale

A synthetic 3-geoframe hierarchy used in examples and tests. It
deliberately reproduces three awkward features of real region tables:

## Usage

``` r
geoscale_example()
```

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
with 7 atoms and geoframes `country`/`state`/`zone`/`atom`.

## Details

- a code (`"N1"`) reused at more than one geoframe, so bare codes are
  ambiguous and every lookup must name its geoframe;

- a non-nesting pair of geoframes — zone `"ZB"` draws atoms from two
  different states (and two different countries), so `state` and `zone`
  do not form a tree;

- an atom (`"ROW"`) with no code at any coarser geoframe (partial
  coverage).

## Examples

``` r
gs <- geoscale_example()
gs
#> Geoscale: example 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom 
#> Geoframes (4, coarsest first):
#>   - country (2)  [1 atom(s) unassigned]
#>     - state (3)  [1 atom(s) unassigned]
#>       - zone (3)  [1 atom(s) unassigned]
#>         - atom (7)
#> Atoms: 7
#> Weights: km2, pop (default: km2)
geoscale_nests(gs, "state", "zone")   # FALSE - they cross-cut
#> [1] FALSE
#> attr(,"offenders")
#> [1] "ZB"
```
