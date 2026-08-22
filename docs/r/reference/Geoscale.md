# Geoscale (S7 class)

A nested spatial partition: a flat table of weighted leaf regions
("atoms") plus the ordered hierarchy of geoframes that groups them.

## Usage

``` r
Geoscale(leaftable, geoframes, members, geometry = NULL, meta = list())
```

## Arguments

- leaftable:

  `data.frame` with a unique `region` key column, one column per
  geoframe in `geoframes`, and one or more numeric weight columns.

- geoframes:

  Ordered character vector of geoframe names (coarsest first); each name
  must appear as a column in `leaftable`.

- members:

  Named list; `members[[lvl]]` is the full ordered set of codes present
  at geoframe `lvl`. Must equal the non-`NA` values of
  `leaftable[[lvl]]` as a set.

- geometry:

  Optional `sfc` (or `NULL`) with one geometry per row of `leaftable`,
  in the same order.

- meta:

  Named list of attributes (`name`, `desc`, `weights`, `default_weight`,
  `crs`, `source`, `labels`).

## Value

A `Geoscale` object.

## Details

Construct with
[`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md)
(the general escape hatch),
[`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
(from a parent-child mapping), or
[`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md)
(from a data source such as Natural Earth).

## See also

[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
[`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md),
[`geoscale_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_share.md)
