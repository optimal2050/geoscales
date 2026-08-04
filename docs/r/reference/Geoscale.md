# Geoscale (S7 class)

A nested spatial partition: a flat table of weighted leaf regions
("atoms") plus the ordered hierarchy of levels that groups them.

## Usage

``` r
Geoscale(leaves, levels, members, geometry = NULL, meta = list())
```

## Arguments

- leaves:

  `data.frame` with a unique `region` key column, one column per level
  in `levels`, and one or more numeric weight columns.

- levels:

  Ordered character vector of level names (coarsest first); each name
  must appear as a column in `leaves`.

- members:

  Named list; `members[[lvl]]` is the full ordered set of codes present
  at level `lvl`. Must equal the non-`NA` values of `leaves[[lvl]]` as a
  set.

- geometry:

  Optional `sfc` (or `NULL`) with one geometry per row of `leaves`, in
  the same order.

- meta:

  Named list of attributes (`name`, `desc`, `weights`, `default_weight`,
  `crs`, `source`, `labels`).

## Value

A `Geoscale` object.

## Details

Construct with
[`geoscale_from_leaves()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaves.md)
(the general escape hatch),
[`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
(from a parent-child mapping), or
[`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md)
(from a data source such as Natural Earth).

## See also

[`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geo_recast.md),
[`geo_filter()`](https://optimal2050.github.io/geoscales/r/reference/geo_filter.md),
[`geo_share()`](https://optimal2050.github.io/geoscales/r/reference/geo_share.md)
