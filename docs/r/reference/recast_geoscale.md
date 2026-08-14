# Recast values from one spatial level to another

The central conversion verb: takes a `data.frame` keyed by region code
at level `from` and returns one keyed at level `to`. Handles both
aggregation (fine to coarse) and disaggregation (coarse to fine) with a
single rule per value column.

## Usage

``` r
recast_geoscale(
  x,
  gs,
  from,
  to,
  key = NULL,
  values = NULL,
  rule = NULL,
  weight = NULL,
  na_action = c("drop", "error", "keep")
)
```

## Arguments

- x:

  A `data.frame` with a region-code column plus one or more numeric
  value columns.

- gs:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- from:

  Level name that the codes in `x` belong to.

- to:

  Target level name.

- key:

  Name of the region-code column in `x`. Defaults to `from` when
  present, otherwise `"region"`.

- values:

  Character vector of value columns to convert. Defaults to all numeric
  columns other than the key and any level names of `gs`. Numeric
  identifiers (e.g. `year`) must be excluded explicitly.

- rule:

  One of
  [`GEO_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEO_RULES.md),
  or `NULL` (default) to look each value column up with
  [`get_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_rule.md),
  falling back to `"sum"`.

- weight:

  Weight column used by `sum` (splitting) and `weighted_mean`. `NULL`
  uses the registered or default weight.

- na_action:

  What to do with atoms that have no code at `from` or `to`: `"drop"`
  (default, with a warning), `"error"`, or `"keep"` (retain an explicit
  `NA` group so totals conserve).

## Value

A `data.frame` keyed by a column named `to`, with the identifier columns
of `x` and the same value columns.

## Details

Columns of `x` that are neither the key nor a value column are treated
as identifiers and are preserved as grouping columns, so panel data (by
date, technology, ...) recasts correctly in one call.

`na_action = "keep"` emits `NA` in the output key column. Note that
downstream, `energyRt` reads `NA` in a region column as a *wildcard
meaning all regions*, so `"keep"` output should not be passed there
unfiltered.

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
recast_geoscale(z, gs, from = "atom", to = "state", rule = "weighted_mean")
#>   state       eff
#> 1    N1 0.3666667
#> 2    N2 0.5000000
#> 3    S1 0.6000000
```
