# Recast data keyed by a pair of regions

Aggregate a table whose rows are region *pairs* – transmission
corridors, trade flows, commuting matrices – to a coarser geoframe. Both
endpoints are mapped through the hierarchy, pairs that land inside a
single target region become internal and are dropped, and the rest are
aggregated by rule.

## Usage

``` r
recast_pairs(
  x,
  gs,
  to,
  from = NULL,
  src = "src",
  dst = "dst",
  values = NULL,
  rule = NULL,
  weight = NULL,
  na_rm = FALSE,
  directed = TRUE,
  drop_internal = TRUE,
  collect = NULL
)
```

## Arguments

- x:

  The data: a data.frame, tibble, data.table, or arrow
  table/dataset/query with two endpoint columns.

- gs:

  The
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  the endpoints are keyed in.

- to:

  Target geoframe name, coarser than `from`.

- from:

  Geoframe the endpoint codes belong to. `NULL` (default) is the finest
  (atom) geoframe.

- src, dst:

  The endpoint columns. Default `"src"` and `"dst"`.

- values:

  Value columns to aggregate. `NULL` (default) is every numeric column
  that is not an endpoint, the weight, or a geoframe.

- rule:

  Aggregation rule, as in
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md):
  one name for all value columns, or a named vector per column.

- weight:

  Name of a column of `x` to weight by, for `weighted_mean`. `NULL`
  (default) uses a `weight` column if present; without one the weights
  are equal and `weighted_mean` is a plain mean.

- na_rm:

  Read an `NA` value as "this pair says nothing" rather than as an
  unknown that makes the whole group `NA` (default `FALSE`). Only an
  all-`NA` group stays `NA`.

- directed:

  Keep the orientation of each pair (default `TRUE`). `FALSE` sorts the
  endpoints, so `A->B` and `B->A` aggregate together.

- drop_internal:

  Drop pairs whose endpoints land in the same target region (default
  `TRUE`). `FALSE` keeps them as self-pairs.

- collect:

  For lazy inputs: materialise (`TRUE`) or return the query (default).

## Value

One row per (endpoint pair x identifier combination), the endpoint
columns keeping their input names and holding `to`-level codes. In the
input's class; lazy in, lazy out.

## Details

A pair table cannot be recast with
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
which maps one key column. Mapping the two endpoints separately would
leave the internal pairs in place, where they would be read as a region
trading with itself.

Aggregation only: the target must be coarser than the source. Splitting
one corridor across the pairs of its members has no unique answer.

The result is not completed to a target vocabulary. Completing pairs
would cross-join every target region with every other, which is
quadratic in the region count and almost entirely empty.

## See also

[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
[`recast_from_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md)

## Examples

``` r
gs <- geoscale_example()
lines <- data.frame(
  src = c("A1", "A3", "A1"),
  dst = c("A2", "A5", "A5"),
  capacity = c(100, 200, 300)
)
# A1-A2 is internal to state N1 and is dropped; the other two survive
recast_pairs(lines, gs, to = "state", rule = "sum")
#> Warning: 1 pair(s) fall inside a single `state` region and were dropped as internal
#>   src dst capacity
#> 1  N1  S1      300
#> 2  N2  S1      200
```
