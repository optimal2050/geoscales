# Register / look up a direct spatial crosswalk

A registered map short-circuits the atom-layer derivation in
[`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
or
[`geoscale_map_between()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map_between.md)
(and thereby
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md))
for one pair of resolutions – for cases where the exact correspondence
is known (hand-audited crosswalks, official concordance tables).

## Usage

``` r
register_geoscale_map(gs, from, to, map)

register_geoscale_map_between(from, to, map)

get_geoscale_map(gs, from, to)

get_geoscale_map_between(from, to)

list_geoscale_maps()
```

## Arguments

- gs:

  The
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  the geoframes belong to, or its name.

- from, to:

  For the within-object functions, geoframe names of `gs`. For the
  `_between` functions, two
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  objects or their names.

- map:

  A `data.frame` shaped like a
  [`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
  result: the two label columns named after the geoframes (or
  Geoscales), plus `n_from`, `n_overlap`, `w` and `w_from`. `NULL`
  removes a previously registered map.

## Value

Invisibly, the registry key. The `get_` functions return the registered
map (or `NULL`); `list_geoscale_maps()` a `data.frame` of registry keys.

## Details

`register_geoscale_map()` and `get_geoscale_map()` handle a pair of
geoframes of one Geoscale; the map is scoped to that object, so
`"state" -> "zone"` maps of two different objects do not collide.
`register_geoscale_map_between()` and `get_geoscale_map_between()`
handle a pair of Geoscales.

## Examples

``` r
gs <- geoscale_example()
fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
                   n_overlap = 1L, w = 1, w_from = 1)
register_geoscale_map(gs, "state", "zone", fake)
list_geoscale_maps()
#>                   key
#> 1 example:state->zone
get_geoscale_map(gs, "state", "zone")
#>   state zone n_from n_overlap w w_from
#> 1    N1   ZC      1         1 1      1
register_geoscale_map(gs, "state", "zone", NULL)  # remove
clear_geoscale_maps()
```
