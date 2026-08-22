# Ancestry between all geoframe pairs

Every `(coarser, finer)` code pair that shares at least one atom, for
all geoframe pairs.

## Usage

``` r
geoscale_ancestry(x)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Value

A `data.frame` with columns `parent_geoframe`, `parent`,
`child_geoframe`, `child`.

## Details

Computed **atom-mediated**, directly from `@leaftable` — deliberately
not as a transitive closure of
[`geoscale_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_family.md).
`timeslices` can use a closure because time geoframes genuinely nest;
spatial geoframes cross-cut, and a closure then manufactures false
relationships. In the example Geoscale, zone `ZB` straddles both
countries, so closing `country -> state -> zone -> atom` would wrongly
report country `N` as an ancestor of atom `A5`, which lies in country
`S`.

For geoframes that do not nest this relation is *overlap*, not
containment — test a given pair with
[`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md).

Geoframe columns are retained because region codes are not unique across
geoframes: in the example, `"N1"` exists at both `state` and `zone`, so
a bare `(parent, child)` pair would read as a self-loop.

## Examples

``` r
head(geoscale_ancestry(geoscale_example()))
#>   parent_geoframe parent child_geoframe child
#> 1         country      N           atom    A1
#> 2         country      N           atom    A2
#> 3         country      N           atom    A3
#> 4         country      N           atom    A4
#> 5         country      N          state    N1
#> 6         country      N          state    N2
```
