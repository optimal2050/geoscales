# geoscales 0.1.0.9000

## Harmonized naming with timescales

One convention across the sibling packages: **`verb_class()`** for data
operations and object transforms, **class-prefixed nouns** for
properties and queries, constructors unchanged, registries
`register_/get_/list_/clear_` with a `geo` domain word. The old `geo_*`
names warn and forward (removal before 1.0):

* Verbs: `geo_recast()` -> `recast_geoscale()`, `geo_filter()` ->
  `filter_geoscale()`, `geo_prune()` -> `prune_geoscale()`,
  `geo_attach_geometry()` -> `attach_geometry_geoscale()`,
  `geo_area()` -> `add_area_geoscale()`.
* Properties/queries: `geo_<x>()` -> `geoscale_<x>()` (levels, rank,
  weights, regions, family, nests, ancestry, children, parents,
  descendants, ancestors, share, geometry, layout, autoplot, plot).
  `geoscale_autoplot()`'s first argument is now `x`.
* Registries: `geo_register_rule()` -> `register_geo_rule()` (and
  get/list/clear alike); `geo_provider()` -> `get_geo_provider()`.
* **`recast()` method registered on the timescales generic** (timescales
  moved to Imports): `x |> recast(cal_a, cal_b) |> recast(gs, to =
  "country")` chains time and space; the source level is inferred from
  `x`'s columns or passed as `from_level=`.
* New `join_geoscale()`: attach coarser-level membership plus
  weight/share columns to region-keyed data — the spatial mirror of
  `timescales::join_calendar()`.

## Milestone 1

First working version: the `Geoscale` class, the conversion verb, navigation,
plotting, and the Natural Earth provider.

### Core

* `Geoscale`, an S7 class holding `leaves` (one row per atom, one column per
  level), `levels` (ordered coarsest first), `members` (code vocabulary per
  level), optional `geometry`, and `meta`. Everything derivable is computed on
  demand; nothing is cached on the object.
* Three construction layers: `geoscale_from_leaves()` (escape hatch),
  `geoscale_build()` (from parent-child crosswalks — ragged, not Cartesian,
  because ragged hierarchies are the norm in space), and
  `geoscale_from_provider()`.
* `geoscale_example()`, a synthetic fixture reproducing three awkward features
  of real region tables: a code reused at several levels, a cross-cutting
  level pair, and an atom with no code at any coarser level.

### Conversion

* `geo_recast()` — aggregation and disaggregation as a single operation.
  Source values are projected down to atoms and then aggregated up to the
  target, so direction falls out of the level ranks and cross-cutting levels
  work without special handling.
* Rules `sum`, `weighted_mean`, `mean` and `copy`, each defined in both
  directions.
* `geo_register_rule()` / `geo_get_rule()` / `geo_list_rules()` — a
  per-parameter rule registry, with an explicit `rule=` always taking
  precedence.
* `na_action = "drop" | "error" | "keep"` for partial coverage. `"drop"`
  genuinely loses the uncovered share and warns with a count; `"keep"`
  conserves totals into an explicit `NA` group.
* Identifier columns are preserved as grouping columns, so panel data
  converts in one call.

### Navigation and subsetting

* `geo_children()`, `geo_parents()`, `geo_descendants()`, `geo_ancestors()`,
  `geo_regions()`, `geo_filter()`, `geo_prune()`, `geo_share()` and `[`.
* `level` is a required argument throughout: region codes are not unique
  across levels, so a bare code is ambiguous.
* `geo_family()`, `geo_ancestry()` and `geo_nests()`. Ancestry is computed
  atom-mediated rather than as a transitive closure — closing over a
  cross-cutting level would manufacture false relationships.

### Geometry and plotting

* `geo_attach_geometry()`, `geo_geometry()` (dissolve to a level) and
  `geo_area()`. `sf` is in Suggests; the core is geometry-free.
* `geo_autoplot()` draws the hierarchy as an icicle and needs no geometry;
  `geo_plot()` draws a choropleth when geometry is attached. `geo_layout()`
  exposes the rectangle coordinates for other plotting systems.

### Providers

* `geo_register_provider()` / `geo_provider()` / `geo_list_providers()`.
* Natural Earth via `ne_source()` and `ne_geoscale()`, with `source` and
  `scale` recorded in `meta`. **The package ships no maps and selects no
  boundaries.**
* Three Natural Earth pitfalls are handled: `adm0_a3` is used as the join key
  (`iso_a3` is `-99` for five countries at 1:110m); area weights are refused
  at scale 110 with a warning; and `-99` is converted to `NA` in numeric
  attributes as well as code columns.
