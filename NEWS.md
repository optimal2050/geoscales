# geoscales (development version)

## New features

* `geom_geoscale()` and `theme_geoscale()`: composable ggplot2
  choropleth layer and map theme, mirroring
  `timescales::geom_calendar()`'s design (column-name arguments, one
  standard `geom_sf()` layer, solid white background for dark-mode
  pages). `plot()` on a Geoscale now dispatches to
  `geoscale_autoplot()`.
* `get_geo_map()` and `list_geo_maps()` complete the crosswalk
  registry; `register_geo_map()`/`clear_geo_maps()` gain examples.

## Documentation

* The documentation is restructured to mirror timescales: the intro is
  a short 5-minute tour; new `vignette("concepts")` (with the shared
  *scales glossary), `vignette("data-structures")` and
  `vignette("data-manipulation")` (including a runnable
  time-and-space `recast()` chain and backend examples); the plotting
  article is rewritten on the current API as
  "Visualization with ggplot2" with a real-map tour of Iceland built
  from Natural Earth, with area data attached (old URL redirects). Vignette code follows the stack-wide
  tidyverse + `|>` style; README drops the retired word "levels".

# geoscales 0.2.0.9000

First working line: the `Geoscale` class, a conserving conversion core
mirroring timescales, navigation, plotting, and the Natural Earth
provider -- under one naming convention shared with timescales.

## Breaking changes

* `Geoscale@levels` is now `@geoframes` and `@leaves` is `@leaftable`
  (`@members` unchanged), matching timescales; `level`/`levels`
  arguments are `geoframe`/`geoframes` across the API, and derived
  tables use `parent_geoframe`/`child_geoframe` columns.
* A value column with neither `rule=` nor a `register_geo_rule()` entry
  is now an error; the silent `sum` fallback is gone.
* Materialised `recast_geoscale()` results complete to the full target
  vocabulary in member order (`NA` where nothing landed); lazy backends
  return observed groups until collected.
* `join_geoscale()` attaches a label column named after the Geoscale,
  with membership and share/weight columns `"<name>."`-prefixed
  (`meta$name` is now required for conversion and attach;
  `geoscale_build()` derives a default). Existing columns are never
  overwritten (error).
* Conflicting registered per-column weights build one crosswalk per
  weight instead of silently splitting equally.
* The `recast()` method argument `from_level` is now `from_geoframe`.

## New features

### Conversion

* `recast_geoscale(x, gs, from, to, rule)` converts between geoframes --
  aggregation and disaggregation as one operation through the atom
  layer, cross-cutting geoframes included; identifier (panel) columns
  are preserved as groups; `to =` also accepts another named Geoscale
  (targeting its atom layer via shared atom keys).
* `recast_to_geoatoms()` / `recast_from_geoatoms()` expose the route
  halves; chaining them across two Geoscales converts between region
  systems that share atom keys.
* `geoscale_map(from, to, gs =, weight =)` materialises the crosswalk
  (atom counts and weights per overlapping pair, within one Geoscale or
  across two); `register_geo_map()` installs exact crosswalks,
  `clear_geo_maps()` resets.
* All converters run over `data.frame`, tibble, `data.table`, dtplyr,
  and arrow inputs; results come back in the input's class, and lazy
  inputs return the uncollected query unless `collect = TRUE`.
* Rules `sum`, `weighted_mean`, `mean`, `copy`, and (new) `sd`, each
  defined in both directions; per-column defaults via
  `register_geo_rule()` / `get_geo_rule()` / `list_geo_rules()` /
  `clear_geo_rules()`; `na_action = c("drop", "error", "keep")` for
  partial coverage.
* The `recast()` generic (owned by timescales, now in Imports) chains
  time and space: `x |> recast(cal_a, cal_b) |> recast(gs, to =
  "country")`; the source geoframe is inferred from `x`'s columns or
  passed as `from_geoframe=`.

### Core, navigation, providers

* `Geoscale`: an S7 class holding `@leaftable` (one row per atom),
  `@geoframes` (ordered coarsest first), `@members`, optional
  `@geometry`, and `@meta`; geoframes are partitions of atoms, not a
  tree, so cross-cutting region systems are first-class.
* Construction layers: `geoscale_from_leaftable()`, `geoscale_build()`
  (ragged parent-child crosswalks), `geoscale_from_provider()`; plus
  `geoscale_example()`.
* Navigation and subsetting: `geoscale_geoframes()`,
  `geoscale_regions()`, `geoscale_rank()`, `geoscale_family()`,
  `geoscale_nests()`, `geoscale_ancestry()` (atom-mediated, never a
  transitive closure), `geoscale_children()` / `_parents()` /
  `_descendants()` / `_ancestors()`, `geoscale_share()`,
  `filter_geoscale()` / `gs[geoframe, region]`, `prune_geoscale()`.
  A `geoframe` argument is required throughout -- codes are not unique
  across geoframes.
* Geometry and plotting (`sf` and ggplot2 in Suggests):
  `attach_geometry_geoscale()`, `geoscale_geometry()` (dissolve),
  `add_area_geoscale()`, `geoscale_autoplot()` (icicle, no geometry
  needed), `geoscale_plot()` (choropleth), `geoscale_layout()`.
* Providers: `register_geo_provider()` / `get_geo_provider()` /
  `list_geo_providers()`; Natural Earth via `ne_source()` /
  `ne_geoscale()` with source and scale recorded in `meta`. The package
  ships no maps and selects no boundaries; known Natural Earth pitfalls
  (`iso_a3 == -99`, unreliable areas at 1:110m) are handled.

## Deprecations

Old names warn and forward; removal before 1.0: the `geo_*` family ->
`verb_geoscale()` / `geoscale_*()` / `register_geo_*()` (e.g.
`geo_recast()` -> `recast_geoscale()`, `geo_levels()` ->
`geoscale_geoframes()`), and the 2026-08 lattice renames
`geoscale_from_leaves()` -> `geoscale_from_leaftable()`,
`geoscale_levels()` -> `geoscale_geoframes()`, `is_valid_level()` ->
`is_valid_geoframe()`, `CORE_LEVELS` -> `CORE_GEOFRAMES`.

## Documentation

* `vignette("geoscales")` gains crosswalk, route-halves, attach,
  backends, and glossary sections; version files (`DESCRIPTION`,
  `VERSION`, NEWS) agree on 0.2.0.9000.
