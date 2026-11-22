# The parts of a GeoScale and which of them may change

Lists the parts of a
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
as a tree: its properties, the columns of the leaftable, the geometry
and the hidden geoframes. Each part carries one of three marks, defined
by the identity of the object
([`geoscale_id()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_id.md)),
which is computed from the leaf column, the geoframe names and the
region codes:

## Usage

``` r
geoscale_tree(x)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Value

A data.frame of class `scale_tree`, one row per part: `part`, the
`parent` property it belongs to (`""` for a property), its `kind`,
`shape`, `mark`, the `verb` that changes it and a `note`. Printing it
draws the tree.

## Details

- `fixed`: the part enters the identity. Changing it gives another
  geoscale; the route is to build a new one with
  [`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md).

- `derived`: the part is computed from another one and is never set.

- `mutable`: the part can change and the geoscale stays the same one.
  The function that changes it is named where there is one.

The marks describe the object; they are not enforced on assignment.
[`str()`](https://rdrr.io/r/utils/str.html) on a `GeoScale` prints the
same tree.

## See also

[`geoscale_id()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_id.md),
[`hide_geoframes_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/hide_geoframes_geoscale.md)

## Examples

``` r
geoscale_tree(geoscale_example())
#> <GeoScale> example@e4024622
#> ├─ leaftable   data.frame [7 x 6]            one row per leaf
#> │  ├─ cell     leaf column          fixed
#> │  ├─ country  frame                fixed
#> │  ├─ state    frame                fixed
#> │  ├─ zone     frame                fixed
#> │  ├─ km2      weight               mutable  geoscale_add_weight()
#> │  └─ pop      weight               mutable  geoscale_add_weight()
#> ├─ geoframes   chr [4]              fixed    country, state, zone, cell
#> ├─ members     list [4]             derived  from leaftable: country 2, state 3, zone 3, cell 7
#> ├─ leaf        chr [1]              fixed    cell
#> ├─ meta        list [5]             mutable  name, desc, weights, default_weight, row_permuted
#> ├─ attributes  data.frame [0 x 10]  mutable  attach_attributes_scale()
#> ├─ aliases     data.frame [0 x 4]   mutable  attach_aliases_scale()
#> ├─ labels      data.frame [0 x 4]   mutable  attach_labels_geoscale()
#> ├─ geometry    NULL                 mutable  attach_geometry_geoscale()
#> └─ hidden      chr [0]              mutable  hide_geoframes_geoscale()
tr <- geoscale_tree(geoscale_example())
tr$part[tr$mark == "fixed"]
#> [1] "cell"      "country"   "state"     "zone"      "geoframes" "leaf"     
```
