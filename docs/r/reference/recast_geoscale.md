# Recast values from one spatial resolution to another

The central conversion verb: takes a table keyed by region code at
geoframe `from` and returns one keyed at `to` – a geoframe name of the
same
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md),
or ANOTHER Geoscale (whose atom layer is the target, matched on shared
atom `region` keys). Handles both aggregation (fine to coarse) and
disaggregation (coarse to fine) with a single rule per value column;
geoframes that cross-cut work too, because the route always goes through
the atom layer. The route is evaluated as one dplyr pipeline against the
[`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
crosswalk, so `x` may live in any supported backend (see below). A
crosswalk registered with
[`register_geo_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_map.md)
short-circuits the derivation.

## Usage

``` r
recast_geoscale(
  x,
  gs,
  from = NULL,
  to,
  key = NULL,
  values = NULL,
  rule = NULL,
  weight = NULL,
  na_action = c("drop", "error", "keep"),
  collect = NULL
)
```

## Arguments

- x:

  The data to recast, in any supported backend, with a column named by
  `key` plus one or more numeric value columns; other columns are
  preserved as identifiers.

- gs:

  The
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  the codes in `x` belong to.

- from:

  Geoframe name the codes belong to. `NULL` (default) is inferred: `key`
  when it is a geoframe name, else the single geoframe name appearing
  among `x`'s columns.

- to:

  Target geoframe name of `gs`, or another (named)
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  – then the target is that object's atom layer, matched on the atom
  `region` keys the two objects share.

- key:

  Name of the region-code column in `x`. Defaults to `from` when that
  column exists, otherwise `"region"`.

- values:

  Character vector of value columns to convert. Default: all numeric
  columns other than the key and `gs`'s geoframe columns. Numeric
  identifiers (e.g. `year`) must be excluded explicitly.

- rule:

  One of
  [`GEO_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEO_RULES.md),
  applied to every value column; or `NULL` (default) to look each column
  up with
  [`get_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_rule.md).
  A column with neither an explicit `rule=` nor a registry entry is an
  ERROR – there is deliberately no fallback (a silently guessed rule is
  a silent unit error).

- weight:

  Weight column used by `sum` (splitting), `weighted_mean` and the
  attached shares. `NULL` uses each column's registered weight, falling
  back to the object's default weight; when the object declares no
  weights at all, atoms weigh 1 (an equal split, with a warning when
  that choice is material, i.e. when disaggregating).

- na_action:

  What to do with atoms that have no code at `from` or `to`: `"drop"`
  (default, with a warning – the affected source share is genuinely
  lost), `"error"`, or `"keep"` (retain an explicit `NA` region row so
  totals conserve).

- collect:

  For lazy inputs (arrow, dtplyr): materialise the result (`TRUE`) or
  return the uncollected query (default).

## Value

The recast table in the input's class, with columns
`c(to, identifiers, values)`: per identifier combination, one row per
member of `to` (the full target vocabulary, `NA` where uncovered), plus
an `NA` region row under `na_action = "keep"`. Identifier column types
are preserved.

## Details

Columns of `x` that are neither the key nor a value column are treated
as identifiers (panel columns – a year, a technology) and preserved as
grouping columns, so panel data recasts correctly in one call; this is
what makes mixed pipelines like
`x |> recast_calendar(...) |> recast_geoscale(...)` work. Columns named
like `gs`'s geoframes are treated as region attributes and dropped.

The public halves of the route are
[`recast_to_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md)
and
[`recast_from_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md);
`recast_geoscale(x, gs, from, to)` is equivalent to
`recast_from_geoatoms(recast_to_geoatoms(x, gs, from), gs, to)`.

Rules (see
[`GEO_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEO_RULES.md)):
`"sum"` splits each source value across its region's atoms
proportionally to the weight before summing up, so totals are conserved.
`"weighted_mean"` weights by the atom weights; `"mean"` is the plain
atom-count mean – the two differ exactly when atom weights differ.
`"copy"` requires a constant value per target region; `"sd"` is
aggregation-only.

`na_action = "keep"` emits `NA` in the output key column. Note that
downstream, `energyRt` reads `NA` in a region column as a *wildcard
meaning all regions*, so `"keep"` output should not be passed there
unfiltered.

## Backends

`x` may be a `data.frame`, tibble, `data.table`, `dtplyr` lazy table, or
an arrow Dataset/Table/query. The result comes back in the input's
class; lazy inputs (arrow, dtplyr) return the uncollected query unless
`collect = TRUE`. Lazy results contain the observed target regions only
– the full-vocabulary completion (and its `NA` rows) applies when the
result is materialised.

## Examples

``` r
gs <- geoscale_example()

# Extensive quantity, fine -> coarse: totals are preserved
x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                capacity = c(1, 2, 3, 4, 5, 6))
recast_geoscale(x, gs, from = "atom", to = "country", rule = "sum")
#>   country capacity
#> 1       N       10
#> 2       S       11

# Coarse -> fine: split proportionally to area
y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
recast_geoscale(y, gs, from = "country", to = "state",
                rule = "sum", weight = "km2")
#>   state capacity
#> 1    N1        3
#> 2    N2        7
#> 3    S1       20

# Intensive quantity: weighted mean going up, copied going down
z <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6))
recast_geoscale(z, gs, from = "atom", to = "state",
                rule = "weighted_mean")
#>   state       eff
#> 1    N1 0.3666667
#> 2    N2 0.5000000
#> 3    S1 0.6000000
```
