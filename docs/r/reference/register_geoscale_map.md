# Register / look up a direct spatial crosswalk

A registered map short-circuits the atom-layer derivation in
[`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
(and thereby
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md))
for one pair of resolutions – for cases where the exact correspondence
is known (hand-audited crosswalks, official concordance tables).

## Usage

``` r
register_geoscale_map(from, to, map, gs = NULL)

get_geoscale_map(from, to, gs = NULL)

list_geoscale_maps()
```

## Arguments

- from, to:

  The pair the map applies to: geoframe names (with `gs` naming the
  object), Geoscale names, or
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  objects (their names are used).

- map:

  A `data.frame` shaped like a
  [`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
  result: the two label columns named after `from` and `to`, plus
  `n_from`, `n_overlap`, `w` and `w_from`. `NULL` removes a previously
  registered map.

- gs:

  Optional
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  (or its name) scoping a within-object map, so `"state" -> "zone"` maps
  of two different objects do not collide. Cross-object maps need no
  scope.

## Value

Invisibly, the registry key. `get_geoscale_map()` returns the registered
map (or `NULL`); `list_geoscale_maps()` a `data.frame` of registry keys.

## Examples

``` r
gs <- geoscale_example()
fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
                   n_overlap = 1L, w = 1, w_from = 1)
register_geoscale_map("state", "zone", fake, gs = gs)
list_geoscale_maps()
#>                   key
#> 1 example:state->zone
get_geoscale_map("state", "zone", gs = gs)
#>   state zone n_from n_overlap w w_from
#> 1    N1   ZC      1         1 1      1
register_geoscale_map("state", "zone", NULL, gs = gs)  # remove
clear_geoscale_maps()
```
