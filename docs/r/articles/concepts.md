# Concepts

## The problem

Energy-system, climate, and policy models carve space into discrete
*regions*. Different models — often different vintages of the same model
— pick different carvings: one nation, five grid regions, thirty-two
model regions, forty-six zones. The region **codes** are arbitrary, the
**weights** (area, population) are data, and converting values between
carvings is error-prone precisely where it matters: totals must
conserve, intensities must average correctly, and region systems drawn
by different hands rarely nest.

`geoscales` represents any such carving as a **Geoscale**: a set of
*atoms* (the finest regions) plus ordered *geoframes* that group them.

## Atoms and geoframes

The **atom layer** is the finest partition — every other resolution is a
grouping of atoms. A **geoframe** is one named resolution: a column over
the atoms assigning each to a region code. Geoframes are ordered
coarsest first, and the object’s hierarchy is that ordered set:

``` r

gs <- geoscale_example()
gs
#> Geoscale: example 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom 
#> Geoframes (4, coarsest first):
#>   - country (2)  [1 atom(s) unassigned]
#>     - state (3)  [1 atom(s) unassigned]
#>       - zone (3)  [1 atom(s) unassigned]
#>         - atom (7)
#> Atoms: 7
#> Weights: km2, pop (default: km2)
```

## Geoframes are partitions, not necessarily a tree

This is the main thing that differs from the time domain. Time
timeframes nest cleanly: every hour belongs to exactly one day. Spatial
geoframes frequently do not — two carvings of the same country can
**cross-cut**, with a region of one straddling two regions of the other:

``` r

geoscale_nests(gs, "country", "state")
#> [1] TRUE
geoscale_nests(gs, "state", "zone")   # ZB straddles two states
#> [1] FALSE
#> attr(,"offenders")
#> [1] "ZB"
```

Real data behaves the same way. In the IDEEA region system for India,
the `r32o11` code `APY` merges Andhra Pradesh with *part of* Puducherry,
so the 36-region carving does not nest inside the 32-region one. This is
exactly why the atom layer exists, and why
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
always routes through it: neither direction of a conversion ever assumes
the geoframes nest.

## Region IDs are authored, and not unique across geoframes

The naming lattice’s **ID rule** (see the glossary below): *time
COMPOSES node IDs from members; space AUTHORS them.* A timeslice ID like
`"d015_h00"` is assembled from its members; a region ID like `"N1"`
simply *is* the member, in its geoframe. Authored codes are reused
freely across geoframes:

``` r

geoscale_children(gs, "state", "N1")
#> [1] "N1"
geoscale_children(gs, "zone", "N1")   # same code, different geoframe
#> [1] "A1" "A2"
```

So a bare code is ambiguous, and every lookup names its geoframe — a
`geoframe` argument is required throughout the API.

## Shares and weights

A Geoscale carries one or more named **weight** columns on its atoms
(area, population, …); `meta$default_weight` names the default.
**`share`** is the universal derived quantity: a fraction of the whole
that sums to coverage and aggregates by SUM — the same word with the
same meaning as in timescales:

``` r

geoscale_share(gs, "state", weight = "km2", within = "country")
#>   state country  km2 share
#> 1    N1       N  300   0.3
#> 2    N2       N  700   0.7
#> 3    S1       S 1100   1.0
```

Weights drive the conversion rules: `sum` splits a coarse value across
atoms proportionally to the chosen weight, `weighted_mean` aggregates an
intensity up with atom weights. There is deliberately **no fallback
rule** — a value column with neither an explicit `rule=` nor a registry
entry is an error, in both siblings.

## Design boundaries

- **The package ships no maps and selects no boundaries.** Providers
  ([`ne_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/ne_geoscale.md),
  your own via
  [`register_geoscale_provider()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_provider.md))
  pass a point of view through and record it in `@meta`; the choice
  stays yours.
- **Everything derivable is computed on demand.** Parent/child tables,
  ancestry, shares, dissolved geometry — nothing is cached on the
  object.
- **Explicit registries only.** Constructors return values; behavior
  changes only through
  [`register_geoscale_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_rule.md),
  [`register_geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_map.md),
  [`register_geoscale_provider()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_provider.md).
- **Label-stable.** A Geoscale’s region codes and their order are fixed
  at construction; conversions never mutate them.

## The \*scales naming lattice (glossary)

The sibling packages `timescales` (time) and `geoscales` (space) share
one vocabulary, locked 2026-08. No surviving word changes meaning
between the packages; the word “levels” is retired from both.

| term | definition | timescales | geoscales | energyRt |
|----|----|----|----|----|
| frame | a named axis of resolution; the ordered frames form the hierarchy, coarsest first, with an implicit root | `@timeframes` | `@geoframes` | `commodity@timeframe` / `@geoframe` |
| members | the per-frame units — bare ordered labels, unique within their frame (`"h00"`; region codes); the components node IDs are made from | `@members[[tf]]` | `@members[[gf]]` | derived |
| node ID | identity of a cell at any frame. The ID rule: time COMPOSES (members `_`-joined, coarsest to finest: `"d015_h00"`); space AUTHORS (the member is the ID, in its geoframe) | `leaftable$timeslice` | `leaftable$region` | `@timeframes[[f]]` entries |
| leaftable | the leaf enumeration: one row per finest node — bare members per frame, plus the leaf ID and weights | `@leaftable` | `@leaftable` | `calendar@timetable` (legacy name; the bridge maps 1:1) |
| nodes at frame f | the leaf IDs of the object pruned at f (`prune_calendar()` / [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md)) | derived | derived | stored (cached view) |
| share / weight | `share` = fraction of the whole; sums to coverage; aggregates by SUM (universal). Weight conventions are documented side by side; energyRt’s share-weighted-mean parent rule is the solver-facing one | `share`, `weight` columns | named weight columns, share derived | `timeslice_share` |
| tokens / providers | domain-specific generators (grammar rules / data sources); deliberately separate concepts | token registry | provider registry | — |
| year-qualified calendar | YEAR as an explicit timeframe (`y2020_m01_h00`). Deferred: year stays an external dimension — the pair `(year, timeslice)` — matching what the solver consumes; `meta$year_qualified` reserves the flag | flag only | — | year = model dimension |

The route halves are named per domain: `recast_to_timebase()` /
`recast_from_timebase()` route through the base datetime grid;
[`recast_to_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md)
/
[`recast_from_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md)
route through the atom layer. Both compose into their package’s fused
`recast_*()` verb, and both packages resolve aggregation rules the same
way: explicit `rule=`, then the registry, then an error — never a silent
fallback.

## Where to next?

- [Data
  structures](https://optimal2050.github.io/geoscales/r/articles/data-structures.md)
  — anatomy of a `Geoscale` object and its registries.
- [Data
  manipulation](https://optimal2050.github.io/geoscales/r/articles/data-manipulation.md)
  — attach, recast, crosswalks, backends.
- [Visualization](https://optimal2050.github.io/geoscales/r/articles/visualization.md)
  — maps with
  [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
  and the structure figures.
