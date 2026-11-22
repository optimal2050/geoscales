# Build a GeoScale from a flat table of leaf regions

The general constructor. Takes a wide `data.frame` with one row per leaf
(the finest region) and one column per geoframe, and returns a
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Usage

``` r
geoscale_from_leaftable(
  leaftable,
  geoframes,
  leaf = NULL,
  weights = NULL,
  default_weight = NULL,
  members = NULL,
  geometry = NULL,
  labels = NULL,
  hidden = NULL,
  name = "",
  desc = "",
  row_order = c("nested", "given"),
  ...
)
```

## Arguments

- leaftable:

  `data.frame` with one row per leaf, one column per name in
  `geoframes`, and optionally numeric weight columns.

- geoframes:

  Ordered character vector of geoframe names, **coarsest first**. Each
  must be a column of `leaftable`.

- leaf:

  Name of the leaf column, the column that identifies the leaves.
  Defaults to the finest geoframe (the last entry of `geoframes`), which
  must then be complete and unique. Name another column when the leaves
  are finer than the finest geoframe.

- weights:

  Character vector naming the weight columns. Defaults to all numeric
  columns that are neither geoframes nor reserved names.

- default_weight:

  The weight used when a caller does not name one. Defaults to the first
  entry of `weights`.

- members:

  Optional named list giving the ordered code vocabulary per geoframe.
  Derived from `leaftable` when `NULL` (first-appearance order).

- geometry:

  Optional `sfc` with one geometry per row of `leaftable`.

- labels:

  Optional table of display names with columns `geoframe`, `region`,
  `label` and optionally `variant`; see
  [`attach_labels_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_labels.md).

- hidden:

  Optional names of geoframes to leave out of plots; see
  [`hide_geoframes_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/hide_geoframes_geoscale.md).

- name, desc:

  Short name and description.

- row_order:

  `"nested"` (default) sorts the rows by geoframe, coarsest first, each
  in its member order (unassigned codes last; `geometry` follows);
  `"given"` keeps the rows as supplied.

- ...:

  Further named entries merged into `meta` (e.g. `crs`, `source`).

## Value

A
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Details

Blank strings (`""`) in geoframe columns are normalised to `NA`, meaning
"this leaf has no code at this geoframe" — partial coverage is normal in
real region tables.

## Examples

``` r
df <- data.frame(
  country = c("C1", "C1", "C1", "C2"),
  zone    = c("Z1", "Z1", "Z2", "Z3"),
  cell    = c("A1", "A2", "A3", "A4"),
  km2     = c(100, 200, 300, 400)
)
geoscale_from_leaftable(df, geoframes = c("country", "zone", "cell"))
#> GeoScale: <unnamed> 
#> Geoframes (3, coarsest first):
#>   - country (2)
#>     - zone (3)
#>       - cell (4)
#> Leaves: 4
#> Weights: km2 (default: km2)
```
