# Data manipulation with geoscales

## The toolkit at a glance

| verb | direction | what it does |
|----|----|----|
| [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md) | Geoscale → columns | *attach* labels, membership, share/weight to a table (no aggregation) |
| [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md) | geoframe A → geoframe B | *convert* values between resolutions, one rule per column |
| [`recast_to_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md) / [`recast_from_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md) | the route halves | project down to the atom layer / aggregate up from it |
| [`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md) | A → B crosswalk | the conversion, materialised as a small table |
| [`register_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_rule.md) / [`register_geo_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_map.md) / [`register_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_provider.md) | registries | per-column rules, exact crosswalks, map sources |
| [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.html) | generic | one pipeline verb across time AND space |

Everything below runs on the synthetic
[`geoscale_example()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_example.md)
fixture in tidyverse style — data flows through `|>`, and every verb
accepts a `data.frame`, tibble, `data.table`, dtplyr, or arrow input
(see [Backends](#backends)).

``` r

gs <- geoscale_example()
atoms <- gs@leaftable$region[!is.na(gs@leaftable$country)]
cap <- tibble(atom = atoms, capacity = c(1, 2, 3, 4, 5, 6))
```

## Attaching a Geoscale to a table

[`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
*decorates* rather than converts: it adds a label column **named after
the Geoscale**, plus optional coarser-geoframe membership columns and
share/weight, all `"<name>."`-prefixed. The keyed geoframe is inferred
from the columns (or passed as `geoframe=`):

``` r

tibble(state = c("N1", "N2", "S1"), v = 1:3) |>
  join_geoscale(gs, geoframes = TRUE, meta = TRUE)
#> # A tibble: 3 × 6
#>   state     v example.country example.weight example.share example
#>   <chr> <int> <fct>                    <dbl>         <dbl> <chr>  
#> 1 N1        1 N                          300         0.143 N1     
#> 2 N2        2 N                          700         0.333 N2     
#> 3 S1        3 S                         1100         0.524 S1
```

Because every Geoscale attaches under its own name, several can coexist
on one dataset — and a table carrying two label columns is itself an
empirical crosswalk between the region systems. Existing columns are
never overwritten; a clashing attach errors instead.

## Recasting between geoframes

[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
converts values — aggregation and disaggregation are one operation,
routed through the atom layer, so cross-cutting geoframes need no
special handling. Three things to know:

**1. One rule per value column, and the rule is mandatory.** Pass
`rule=` for all columns, or register per-column rules once; a column
with neither errors — a silently guessed rule is a silent unit error.

``` r

register_geo_rule("capacity", "sum")            # extensive
register_geo_rule("eff", "weighted_mean",       # intensive
                  weight = "pop")

cap |> recast_geoscale(gs, from = "atom", to = "country")
#> # A tibble: 2 × 2
#>   country capacity
#>   <chr>      <dbl>
#> 1 N             10
#> 2 S             11
```

| rule | up (coarsen) | down (refine) |
|----|----|----|
| `sum` | sum | split by the weight (conserves totals) |
| `weighted_mean` | weight-weighted mean | copy |
| `mean` | plain mean | copy |
| `copy` | common value (error if not constant) | copy |
| `sd` | dispersion over atoms | degenerates |

Disaggregation is the same call in the other direction — the chosen
weight drives the split, and a round trip is exact:

``` r

tibble(country = c("N", "S"), capacity = c(10, 20)) |>
  recast_geoscale(gs, from = "country", to = "state", weight = "km2")
#> # A tibble: 3 × 2
#>   state capacity
#>   <chr>    <dbl>
#> 1 N1           3
#> 2 N2           7
#> 3 S1          20
```

**2. Identifier columns ride along.** Columns that are neither the key
nor values (a year, a technology) are grouping columns, so panel data
converts in one call, and totals conserve *per group*. Materialised
results complete to the **full target vocabulary** in member order (`NA`
where nothing landed), so downstream joins see a stable schema.

``` r

panel <- expand.grid(atom = atoms, year = c(2030L, 2050L),
                     stringsAsFactors = FALSE) |>
  as_tibble() |>
  mutate(capacity = seq_along(atom) * 1.0)
panel |> recast_geoscale(gs, from = "atom", to = "country",
                         values = "capacity")
#> # A tibble: 4 × 3
#>   country  year capacity
#>   <chr>   <int>    <dbl>
#> 1 N        2030       10
#> 2 S        2030       11
#> 3 N        2050       34
#> 4 S        2050       23
```

(`values=` is explicit here because `year` is numeric — value
auto-detection takes every numeric non-key column, so numeric
identifiers must be named out.)

**3. Coverage is explicit.** Atoms with no code at `from` or `to` go
through `na_action=`: `"drop"` (default; warns — the affected share is
genuinely lost), `"keep"` (an explicit `NA` region row so totals
conserve), or `"error"`. Note that downstream, energyRt reads `NA` in a
region column as a wildcard meaning *all* regions — don’t pass `"keep"`
output there unfiltered.

## The route halves and cross-Geoscale conversion

[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
is the fused route `from -> atoms -> to`; its halves are public. Going
down, extensive columns split by the chosen weight and the atom `weight`
is attached so the return trip is exact; going up, rules act on the atom
rows directly:

``` r

a <- tibble(country = c("N", "S"), capacity = c(10, 20)) |>
  recast_to_geoatoms(gs, from = "country", rule = "sum", weight = "km2")
head(a, 3)
#> # A tibble: 3 × 3
#>   region capacity weight
#>   <chr>     <dbl>  <dbl>
#> 1 A1            1    100
#> 2 A2            2    200
#> 3 A3            3    300
a |> recast_from_geoatoms(gs, to = "state", rule = "sum")
#> # A tibble: 3 × 2
#>   state capacity
#>   <chr>    <dbl>
#> 1 N1           3
#> 2 N2           7
#> 3 S1          20
```

Because the atom rows are keyed by atom `region` IDs, the halves also
convert **across two different Geoscales that share atom keys** (reg32
to NUTS style conversions) — and the fused verb accepts another Geoscale
as `to`, targeting its atom layer:

``` r

lf <- tibble(band = rep(c("X", "Y"), 3), atom = atoms,
             km2 = c(100, 200, 300, 400, 500, 600))
gs_b <- geoscale_from_leaftable(lf, geoframes = c("band", "atom"),
                                name = "bands")
cap |>
  recast_geoscale(gs, from = "atom", to = gs_b, rule = "sum") |>
  recast_geoscale(gs_b, from = "atom", to = "band", rule = "sum")
#> # A tibble: 2 × 2
#>   band  capacity
#>   <chr>    <dbl>
#> 1 X            9
#> 2 Y           12
```

## The crosswalk, inspectable and overridable

Every recast is a join against a small crosswalk table — one row per
overlapping region pair with atom counts (`n_from`, `n_overlap`) and
weights (`w`, the absolute overlap weight; `w_from`, the full source
weight — `w / w_from` is the split share):

``` r

geoscale_map("country", "state", gs = gs, weight = "km2")
#>   country state n_from n_overlap    w w_from
#> 1       N    N1      4         2  300   1000
#> 2       N    N2      4         2  700   1000
#> 3       S    S1      2         2 1100   1100
```

When an exact correspondence is known (an official concordance table),
register it and it short-circuits the derivation — with accessors to
inspect what is installed:

``` r

exact <- geoscale_map("state", "zone", gs = gs)
register_geo_map("state", "zone", exact, gs = gs)
list_geo_maps()
#>                   key
#> 1 example:state->zone
identical(get_geo_map("state", "zone", gs = gs), exact)
#> [1] TRUE
clear_geo_maps()
```

## One verb across time and space

The bare
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.html)
generic (owned by timescales, re-exported here) dispatches on the scale
object, so one pipeline chains both dimensions — this runs, since
geoscales imports timescales:

``` r

library(timescales)
x <- expand.grid(timeslice = sprintf("m%02d", 1:12),
                 state = c("N1", "N2", "S1"),
                 stringsAsFactors = FALSE) |>
  as_tibble() |>
  mutate(demand = seq_along(timeslice) * 1.0)

x |>
  recast(calendar("m12"), to = calendar("q4"), year = 2025,
         rule = "sum") |>
  recast(gs, to = "country", rule = "sum")
#> # A tibble: 8 × 3
#>   country timeslice demand
#>   <chr>   <chr>      <dbl>
#> 1 N       Q1            48
#> 2 S       Q1            78
#> 3 N       Q2            66
#> 4 S       Q2            87
#> 5 N       Q3            84
#> 6 S       Q3            96
#> 7 N       Q4           102
#> 8 S       Q4           105
```

Same contract on both sides: explicit rules, identifier columns
preserved, totals conserved under `"sum"`.

## Backends

The verbs are single dplyr pipelines, so the SAME code runs over an
in-memory `data.frame`/tibble, a `data.table` (via dtplyr), or an arrow
Dataset/query. Eager inputs come back in their own class; lazy inputs
return the *uncollected query* unless `collect = TRUE`:

``` r

dt <- data.table::as.data.table(cap)

dt |>
  recast_geoscale(gs, from = "atom", to = "country", rule = "sum") |>
  class()                          # data.table in, data.table out
#> [1] "data.table" "data.frame"

lazy <- dtplyr::lazy_dt(dt) |>
  recast_geoscale(gs, from = "atom", to = "country", rule = "sum")
class(lazy)                        # the query, not the result
#> [1] "dtplyr_step_call" "dtplyr_step"
as.data.frame(dplyr::collect(lazy))
#>   country capacity
#> 1       N       10
#> 2       S       11
```

Two contract details for lazy sources (dtplyr, arrow): results carry the
*observed* target regions only — the full-vocabulary completion happens
on materialisation — and the geoscale side of every join is a small
in-memory frame, so an on-disk arrow dataset is never pulled into memory
for the geoscale arithmetic.

## Where to next?

- [Concepts](https://optimal2050.github.io/geoscales/r/articles/concepts.md)
  — why the route always goes through the atom layer.
- [Data
  structures](https://optimal2050.github.io/geoscales/r/articles/data-structures.md)
  — the registries as structures.
- [Visualization](https://optimal2050.github.io/geoscales/r/articles/visualization.md)
  — the same pipelines flowing onto maps.
