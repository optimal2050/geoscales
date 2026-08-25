# Data structures

## The Geoscale object

A `Geoscale` is an S7 object with five properties:

``` r

gs <- geoscale_example()
S7::prop_names(gs)
#> [1] "leaftable" "geoframes" "members"   "geometry"  "meta"
```

| property | type | holds |
|----|----|----|
| `@leaftable` | `data.frame` | one row per **atom**: one column per geoframe, the unique `region` key, weight columns |
| `@geoframes` | `character` | the hierarchy, ordered coarsest first |
| `@members` | named `list` | the ordered code vocabulary at each geoframe |
| `@geometry` | `sfc` or `NULL` | optional atom polygons, aligned to leaftable rows |
| `@meta` | `list` | `name`, `desc`, `weights`, `default_weight`, `crs`, `source`, `labels` |

Everything else — parent/child tables, ancestry, shares, dissolved
shapes — is derived on demand; nothing is cached on the object.

## The leaftable

``` r

geoscale_leaftable(gs)
#>   country state zone atom  km2 pop region
#> 1       N    N1   N1   A1  100  10     A1
#> 2       N    N1   N1   A2  200  90     A2
#> 3       N    N2   ZB   A3  300  30     A3
#> 4       N    N2   ZB   A4  400  70     A4
#> 5       S    S1   ZB   A5  500  50     A5
#> 6       S    S1   ZC   A6  600  50     A6
#> 7    <NA>  <NA> <NA>  ROW 1000   0    ROW
```

Each row is one atom. The `region` column is the **authored node ID**
(unique, non-missing); geoframe columns may hold `NA` — an atom with no
code at a coarser geoframe (a rest-of-world row, offshore areas) simply
does not participate at that resolution, and `na_action=` decides what
recasts do about it.

## Geoframes, members, ranks

``` r

geoscale_geoframes(gs)
#> [1] "country" "state"   "zone"    "atom"
geoscale_geoframes(gs, finest = TRUE)   # the atom geoframe
#> [1] "atom"
geoscale_regions(gs, "state")           # the members at one geoframe
#> [1] "N1" "N2" "S1"
geoscale_rank(gs, c("zone", "atom"))    # positions, coarsest = 1
#> [1] 3 4
```

Geoframe names must be syntactically valid column names;
`CORE_GEOFRAMES` is recommended vocabulary, not enforcement:

``` r

CORE_GEOFRAMES
#> [1] "GLOBE"     "CONTINENT" "COUNTRY"   "STATE"     "ZONE"      "CELL"
is_valid_geoframe(c("COUNTRY", "reg32", "", "2bad"))
#> [1]  TRUE  TRUE FALSE FALSE
```

Navigation is derived on demand from the leaftable — and because
geoframes may cross-cut, ancestry is computed atom-mediated, never as a
transitive closure:

``` r

geoscale_parents(gs, "zone", "ZB", to = "state")   # cross-cut: two parents
#> [1] "N2" "S1"
geoscale_ancestors(gs, "atom", "A5")
#>   geoframe region
#> 1  country      S
#> 2    state     S1
#> 3     zone     ZB
geoscale_descendants(gs, "country", "N")
#>   geoframe region
#> 1    state     N1
#> 2    state     N2
#> 3     zone     N1
#> 4     zone     ZB
#> 5     atom     A1
#> 6     atom     A2
#> 7     atom     A3
#> 8     atom     A4
head(geoscale_ancestry(gs), 4)
#>   parent_geoframe parent child_geoframe child
#> 1         country      N           atom    A1
#> 2         country      N           atom    A2
#> 3         country      N           atom    A3
#> 4         country      N           atom    A4
```

## Weights and meta

``` r

geoscale_weights(gs)
#> [1] "km2" "pop"
gs@meta[c("name", "weights", "default_weight")]
#> $name
#> [1] "example"
#> 
#> $weights
#> [1] "km2" "pop"
#> 
#> $default_weight
#> [1] "km2"
```

`meta$name` is load-bearing: conversion and attach name their working
columns after the object
([`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
label columns,
[`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)’s
`"<name>."` prefixes), so both require a named Geoscale.
[`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
derives a default name from the geoframes;
[`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md)
takes `name=`.

## What the validator guarantees

Construction (any layer:
[`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md),
[`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md),
[`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md))
enforces:

- `region` present, character, unique, no missing/empty values;
- every geoframe present as a leaftable column; members exactly the
  non-`NA` values of that column, in a stable order;
- weights numeric, finite, non-negative, with a positive sum;
  `default_weight` one of the declared weights;
- geometry, when attached, aligned 1:1 with leaftable rows (see
  [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md);
  the CRS is recorded in `meta$crs`);
- a warning (not an error) when geoframes look ordered finer-to-coarser
  — order carries meaning: aggregation direction follows it.

The old argument names `leaves=`/`levels=` are rejected with a pointer
to the current spelling.

## The registries

Three package-level registries change behavior explicitly — the only way
anything global changes:

**Rules** map value-column names to their aggregation rule (there is no
fallback — unregistered columns without `rule=` error):

``` r

GEOSCALE_RULES
#> [1] "sum"           "weighted_mean" "mean"          "copy"         
#> [5] "sd"
register_geoscale_rule("capacity", "sum")
register_geoscale_rule("eff", "weighted_mean", weight = "pop")
get_geoscale_rule("eff")
#> $rule
#> [1] "weighted_mean"
#> 
#> $weight
#> [1] "pop"
list_geoscale_rules()
#>      param          rule weight
#> 1 capacity           sum   <NA>
#> 2      eff weighted_mean    pop
clear_geoscale_rules()
```

**Maps** hold exact crosswalks that short-circuit the atom-layer
derivation in
[`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
— for hand-audited concordances:

``` r

fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
                   n_overlap = 1L, w = 1, w_from = 1)
register_geoscale_map("state", "zone", fake, gs = gs)
list_geoscale_maps()
#>                   key
#> 1 example:state->zone
get_geoscale_map("state", "zone", gs = gs)
#>   state zone n_from n_overlap w w_from
#> 1    N1   ZC      1         1 1      1
clear_geoscale_maps()
```

**Providers** are named map sources (`fetch` functions returning a wide
`sf`/`data.frame`); the package ships one:

``` r

list_geoscale_providers()
#>           name                                          desc
#> 1 naturalearth Natural Earth admin-0/admin-1 (rnaturalearth)
get_geoscale_provider("naturalearth")$desc
#> [1] "Natural Earth admin-0/admin-1 (rnaturalearth)"
```

## Where to next?

- [Concepts](https://optimal2050.github.io/geoscales/r/articles/concepts.md)
  — why the structures look this way.
- [Data
  manipulation](https://optimal2050.github.io/geoscales/r/articles/data-manipulation.md)
  — the verbs over these structures.
- [Building from Natural
  Earth](https://optimal2050.github.io/geoscales/r/articles/from-naturalearth.md)
  — providers in practice.
