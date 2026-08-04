# Build a Geoscale from a flat table of leaf regions

The general constructor. Takes a wide `data.frame` with one row per atom
(the finest region) and one column per level, and returns a
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Usage

``` r
geoscale_from_leaves(
  leaves,
  levels,
  key = NULL,
  weights = NULL,
  default_weight = NULL,
  members = NULL,
  geometry = NULL,
  name = "",
  desc = "",
  ...
)
```

## Arguments

- leaves:

  `data.frame` with one row per atom, one column per name in `levels`,
  and optionally numeric weight columns.

- levels:

  Ordered character vector of level names, **coarsest first**. Each must
  be a column of `leaves`.

- key:

  Name of the column holding the unique atom key. Defaults to `"region"`
  if present, otherwise the finest level (the last entry of `levels`),
  which is copied into a `region` column.

- weights:

  Character vector naming the weight columns. Defaults to all numeric
  columns that are neither levels nor reserved names.

- default_weight:

  The weight used when a caller does not name one. Defaults to the first
  entry of `weights`.

- members:

  Optional named list giving the ordered code vocabulary per level.
  Derived from `leaves` when `NULL` (first-appearance order).

- geometry:

  Optional `sfc` with one geometry per row of `leaves`.

- name, desc:

  Short name and description.

- ...:

  Further named entries merged into `meta` (e.g. `crs`, `source`).

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Details

Blank strings (`""`) in level columns are normalised to `NA`, meaning
"this atom has no code at this level" — partial coverage is normal in
real region tables.

## Examples

``` r
df <- data.frame(
  country = c("C1", "C1", "C1", "C2"),
  zone    = c("Z1", "Z1", "Z2", "Z3"),
  atom    = c("A1", "A2", "A3", "A4"),
  km2     = c(100, 200, 300, 400)
)
geoscale_from_leaves(df, levels = c("country", "zone", "atom"))
#> Geoscale: <unnamed> 
#> Levels (3, coarsest first):
#>   - country (2)
#>     - zone (3)
#>       - atom (4)
#> Atoms: 4
#> Weights: km2 (default: km2)
```
