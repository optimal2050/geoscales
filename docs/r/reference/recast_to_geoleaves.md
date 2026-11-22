# Recast region data down to the leaf layer, and back

The two public halves of the `from -> leaves -> to` route:
`recast_to_geoleaves()` projects region-keyed data DOWN to the leaf
layer (one row per leaf), and `recast_from_geoleaves()` aggregates
leaf-keyed data UP into a geoframe's regions. Their composition is
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
and because the leaf rows are keyed by the leaf codes,
`recast_from_geoleaves(recast_to_geoleaves(x, gs_a), gs_b, to)` recasts
across two different GeoScales that share leaf codes.

## Usage

``` r
recast_to_geoleaves(
  data,
  gs,
  source = NULL,
  key = NULL,
  values = NULL,
  rule = NULL,
  weight = NULL,
  attach_weight = TRUE,
  collect = NULL,
  from = lifecycle::deprecated()
)

recast_from_geoleaves(
  data,
  gs,
  target,
  key = NULL,
  values = NULL,
  rule = NULL,
  weight = NULL,
  data_weight = NULL,
  na_rm = FALSE,
  na_action = c("drop", "error", "keep"),
  collect = NULL,
  to = lifecycle::deprecated()
)
```

## Arguments

- data:

  The data: for `recast_to_geoleaves()` keyed by region code at geoframe
  `source`; for `recast_from_geoleaves()` keyed by leaf codes.

- gs:

  The
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
  the data is keyed in (`to_geoleaves`) or aggregated into
  (`from_geoleaves`).

- source:

  `to_geoleaves` only: geoframe name the codes belong to. `NULL`
  (default) is inferred as in
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md).

- key:

  The key column. `to_geoleaves`: defaults to `source` when that column
  exists, otherwise the GeoScale's leaf column. `from_geoleaves`: the
  GeoScale's leaf column.

- values, rule:

  As in
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md).

- weight:

  A declared weight column of `gs`, as in
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md).
  `from_geoleaves` uses it only when `data` carries no weight of its
  own.

- attach_weight:

  `to_geoleaves` only: attach the `weight` column (default `TRUE`).

- collect:

  For lazy inputs: materialise (`TRUE`) or return the query (default).

- from, to:

  Deprecated names of `source` and `target`.

- target:

  `from_geoleaves` only: target geoframe name.

- data_weight:

  `from_geoleaves` only: the name of a column of `data` to weight by, so
  the weight may vary by identifier – a capacity-weighted efficiency
  differs by year and vintage. `NULL` (default) uses a `weight` column
  of `data` if present, else the scale weight `weight`.

- na_rm:

  `from_geoleaves` only: read an `NA` value as "this member says
  nothing" rather than as an unknown that makes the whole group `NA`
  (default `FALSE`). Only an all-`NA` group stays `NA`; a weighted mean
  drops the weight of each `NA` member so the divisor still matches.

- na_action:

  `from_geoleaves` only: what to do with leaves that have no code at
  `target` – `"drop"` (default, warning), `"error"`, or `"keep"` (an
  `NA` region row).

## Value

`recast_to_geoleaves()`: one row per (leaf x identifier combination)
with the leaf column (under its own name in the GeoScale, see
[`geoscale_leaf_column()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_leaf_column.md)),
identifiers, values (and `weight`). `recast_from_geoleaves()`: one row
per (region x identifier combination) with columns `target`-named
region, identifiers, values. Both in the input's class; lazy in, lazy
out.

## Details

Going down, extensive columns (rule `"sum"`) are split across a region's
leaves proportionally to the chosen weight so totals conserve; intensive
columns are repeated. A `weight` column (the leaf's weight) is attached
by default so that the return trip's `"weighted_mean"` reproduces the
source weighting exactly; pass `attach_weight = FALSE` to omit it.

Going up, rules act on the leaf rows directly: `"sum"` sums, `"mean"`
averages, `"weighted_mean"` uses the `weight` column when present (else
the target object's chosen weight), `"copy"` requires constancy, `"sd"`
is the standard deviation over the leaves.

Both ends run as dplyr pipelines and accept any supported backend (see
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)'s
Backends section); the geoscale side of every join is a small in-memory
frame.

## Examples

``` r
gs <- geoscale_example()
y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
a <- recast_to_geoleaves(y, gs, source = "country", rule = "sum",
                         weight = "km2")
a
#>   cell  capacity weight
#> 1   A1  1.000000    100
#> 2   A2  2.000000    200
#> 3   A3  3.000000    300
#> 4   A4  4.000000    400
#> 5   A5  9.090909    500
#> 6   A6 10.909091    600
sum(a$capacity)  # 30 -- totals conserve
#> [1] 30

recast_from_geoleaves(a, gs, target = "state", rule = "sum")
#>   state capacity
#> 1    N1        3
#> 2    N2        7
#> 3    S1       20
```
