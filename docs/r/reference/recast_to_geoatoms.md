# Recast region data down to the atom layer, and back

The two public halves of the `from -> atoms -> to` route:
`recast_to_geoatoms()` projects region-keyed data DOWN to the atom layer
(one row per atom), and `recast_from_geoatoms()` aggregates atom-keyed
data UP into a geoframe's regions. Their composition is
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
and because the atom rows are keyed by the atom `region` IDs,
`recast_from_geoatoms(recast_to_geoatoms(x, gs_a), gs_b, to)` recasts
across two different Geoscales that share atom keys.

## Usage

``` r
recast_to_geoatoms(
  x,
  gs,
  from = NULL,
  key = NULL,
  values = NULL,
  rule = NULL,
  weight = NULL,
  attach_weight = TRUE,
  collect = NULL
)

recast_from_geoatoms(
  x,
  gs,
  to,
  key = NULL,
  values = NULL,
  rule = NULL,
  na_action = c("drop", "error", "keep"),
  collect = NULL
)
```

## Arguments

- x:

  The data: for `recast_to_geoatoms()` keyed by region code at geoframe
  `from`; for `recast_from_geoatoms()` keyed by atom `region` IDs.

- gs:

  The
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  the data is keyed in (`to_geoatoms`) or aggregated into
  (`from_geoatoms`).

- from:

  `to_geoatoms` only: geoframe name the codes belong to. `NULL`
  (default) is inferred as in
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md).

- key:

  The key column. `to_geoatoms`: defaults to `from` when that column
  exists, otherwise `"region"`. `from_geoatoms`: default `"region"`.

- values, rule, weight:

  As in
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md).

- attach_weight:

  `to_geoatoms` only: attach the `weight` column (default `TRUE`).

- collect:

  For lazy inputs: materialise (`TRUE`) or return the query (default).

- to:

  `from_geoatoms` only: target geoframe name.

- na_action:

  `from_geoatoms` only: what to do with atoms that have no code at `to`
  – `"drop"` (default, warning), `"error"`, or `"keep"` (an `NA` region
  row).

## Value

`recast_to_geoatoms()`: one row per (atom x identifier combination) with
columns `region`, identifiers, values (and `weight`).
`recast_from_geoatoms()`: one row per (region x identifier combination)
with columns `to`-named region, identifiers, values. Both in the input's
class; lazy in, lazy out.

## Details

Going down, extensive columns (rule `"sum"`) are split across a region's
atoms proportionally to the chosen weight so totals conserve; intensive
columns are repeated. A `weight` column (the atom's weight) is attached
by default so that the return trip's `"weighted_mean"` reproduces the
source weighting exactly; pass `attach_weight = FALSE` to omit it.

Going up, rules act on the atom rows directly: `"sum"` sums, `"mean"`
averages, `"weighted_mean"` uses the `weight` column when present (else
the target object's chosen weight), `"copy"` requires constancy, `"sd"`
is the standard deviation over the atoms.

Both ends run as dplyr pipelines and accept any supported backend (see
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)'s
Backends section); the geoscale side of every join is a small in-memory
frame.

## Examples

``` r
gs <- geoscale_example()
y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
a <- recast_to_geoatoms(y, gs, from = "country", rule = "sum",
                        weight = "km2")
a
#>   region  capacity weight
#> 1     A1  1.000000    100
#> 2     A2  2.000000    200
#> 3     A3  3.000000    300
#> 4     A4  4.000000    400
#> 5     A5  9.090909    500
#> 6     A6 10.909091    600
sum(a$capacity)  # 30 -- totals conserve
#> [1] 30

recast_from_geoatoms(a, gs, to = "state", rule = "sum")
#>   state capacity
#> 1    N1        3
#> 2    N2        7
#> 3    S1       20
```
