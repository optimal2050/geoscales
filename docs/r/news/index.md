# Changelog

## geoscales (development version)

### New features

- [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
  and
  [`theme_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md):
  composable ggplot2 choropleth layer and map theme, mirroring
  [`timescales::geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.html)’s
  design (column-name arguments, one standard
  [`geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)
  layer, solid white background for dark-mode pages).
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on a Geoscale
  now dispatches to
  [`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md).
- [`get_geo_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_map.md)
  and
  [`list_geo_maps()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_map.md)
  complete the crosswalk registry;
  [`register_geo_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_map.md)/[`clear_geo_maps()`](https://optimal2050.github.io/geoscales/r/reference/clear_geo_maps.md)
  gain examples.

### Documentation

- The documentation is restructured to mirror timescales: the intro is a
  short 5-minute tour; new
  [`vignette("concepts")`](https://optimal2050.github.io/geoscales/r/articles/concepts.md)
  (with the shared \*scales glossary),
  [`vignette("data-structures")`](https://optimal2050.github.io/geoscales/r/articles/data-structures.md)
  and
  [`vignette("data-manipulation")`](https://optimal2050.github.io/geoscales/r/articles/data-manipulation.md)
  (including a runnable time-and-space
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.html)
  chain and backend examples); the plotting article is rewritten on the
  current API as “Visualization with ggplot2” with a real-map tour of
  Iceland built from Natural Earth, with area data attached (old URL
  redirects). Vignette code follows the stack-wide tidyverse + `|>`
  style; README drops the retired word “levels”.

## geoscales 0.2.0.9000

First working line: the `Geoscale` class, a conserving conversion core
mirroring timescales, navigation, plotting, and the Natural Earth
provider – under one naming convention shared with timescales.

### Breaking changes

- `Geoscale@levels` is now `@geoframes` and `@leaves` is `@leaftable`
  (`@members` unchanged), matching timescales; `level`/`levels`
  arguments are `geoframe`/`geoframes` across the API, and derived
  tables use `parent_geoframe`/`child_geoframe` columns.
- A value column with neither `rule=` nor a
  [`register_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_rule.md)
  entry is now an error; the silent `sum` fallback is gone.
- Materialised
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
  results complete to the full target vocabulary in member order (`NA`
  where nothing landed); lazy backends return observed groups until
  collected.
- [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
  attaches a label column named after the Geoscale, with membership and
  share/weight columns `"<name>."`-prefixed (`meta$name` is now required
  for conversion and attach;
  [`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
  derives a default). Existing columns are never overwritten (error).
- Conflicting registered per-column weights build one crosswalk per
  weight instead of silently splitting equally.
- The
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.html)
  method argument `from_level` is now `from_geoframe`.

### New features

#### Conversion

- `recast_geoscale(x, gs, from, to, rule)` converts between geoframes –
  aggregation and disaggregation as one operation through the atom
  layer, cross-cutting geoframes included; identifier (panel) columns
  are preserved as groups; `to =` also accepts another named Geoscale
  (targeting its atom layer via shared atom keys).
- [`recast_to_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md)
  /
  [`recast_from_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md)
  expose the route halves; chaining them across two Geoscales converts
  between region systems that share atom keys.
- `geoscale_map(from, to, gs =, weight =)` materialises the crosswalk
  (atom counts and weights per overlapping pair, within one Geoscale or
  across two);
  [`register_geo_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_map.md)
  installs exact crosswalks,
  [`clear_geo_maps()`](https://optimal2050.github.io/geoscales/r/reference/clear_geo_maps.md)
  resets.
- All converters run over `data.frame`, tibble, `data.table`, dtplyr,
  and arrow inputs; results come back in the input’s class, and lazy
  inputs return the uncollected query unless `collect = TRUE`.
- Rules `sum`, `weighted_mean`, `mean`, `copy`, and (new) `sd`, each
  defined in both directions; per-column defaults via
  [`register_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_rule.md)
  /
  [`get_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_rule.md)
  /
  [`list_geo_rules()`](https://optimal2050.github.io/geoscales/r/reference/list_geo_rules.md)
  /
  [`clear_geo_rules()`](https://optimal2050.github.io/geoscales/r/reference/clear_geo_rules.md);
  `na_action = c("drop", "error", "keep")` for partial coverage.
- The
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.html)
  generic (owned by timescales, now in Imports) chains time and space:
  `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")`; the source
  geoframe is inferred from `x`’s columns or passed as `from_geoframe=`.

#### Core, navigation, providers

- `Geoscale`: an S7 class holding `@leaftable` (one row per atom),
  `@geoframes` (ordered coarsest first), `@members`, optional
  `@geometry`, and `@meta`; geoframes are partitions of atoms, not a
  tree, so cross-cutting region systems are first-class.
- Construction layers:
  [`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md),
  [`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
  (ragged parent-child crosswalks),
  [`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md);
  plus
  [`geoscale_example()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_example.md).
- Navigation and subsetting:
  [`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md),
  [`geoscale_regions()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_regions.md),
  [`geoscale_rank()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_rank.md),
  [`geoscale_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_family.md),
  [`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md),
  [`geoscale_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_ancestry.md)
  (atom-mediated, never a transitive closure),
  [`geoscale_children()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md)
  / `_parents()` / `_descendants()` / `_ancestors()`,
  [`geoscale_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_share.md),
  [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md)
  / `gs[geoframe, region]`,
  [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md).
  A `geoframe` argument is required throughout – codes are not unique
  across geoframes.
- Geometry and plotting (`sf` and ggplot2 in Suggests):
  [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md),
  [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md)
  (dissolve),
  [`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md),
  [`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md)
  (icicle, no geometry needed),
  [`geoscale_plot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_plot.md)
  (choropleth),
  [`geoscale_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_layout.md).
- Providers:
  [`register_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_provider.md)
  /
  [`get_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_provider.md)
  /
  [`list_geo_providers()`](https://optimal2050.github.io/geoscales/r/reference/list_geo_providers.md);
  Natural Earth via
  [`ne_source()`](https://optimal2050.github.io/geoscales/r/reference/ne_source.md)
  /
  [`ne_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/ne_geoscale.md)
  with source and scale recorded in `meta`. The package ships no maps
  and selects no boundaries; known Natural Earth pitfalls
  (`iso_a3 == -99`, unreliable areas at 1:110m) are handled.

### Deprecations

Old names warn and forward; removal before 1.0: the `geo_*` family -\>
`verb_geoscale()` / `geoscale_*()` / `register_geo_*()` (e.g.
[`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
-\>
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
[`geo_levels()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
-\>
[`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md)),
and the 2026-08 lattice renames
[`geoscale_from_leaves()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
-\>
[`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md),
[`geoscale_levels()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
-\>
[`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md),
[`is_valid_level()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
-\>
[`is_valid_geoframe()`](https://optimal2050.github.io/geoscales/r/reference/is_valid_geoframe.md),
`CORE_LEVELS` -\> `CORE_GEOFRAMES`.

### Documentation

- [`vignette("geoscales")`](https://optimal2050.github.io/geoscales/r/articles/geoscales.md)
  gains crosswalk, route-halves, attach, backends, and glossary
  sections; version files (`DESCRIPTION`, `VERSION`, NEWS) agree on
  0.2.0.9000.
