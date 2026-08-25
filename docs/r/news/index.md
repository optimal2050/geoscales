# Changelog

## geoscales 0.5.0

Hard-break release: the sibling APIs of timescales and geoscales were
harmonized against each other (the pairing table and naming rules live
in the stack-wide CONVENTIONS.md, “Sibling API mirror”). NO deprecation
aliases are kept – old names are gone, not wrapped.

### Breaking changes

- Registries follow `register_<class>_<thing>` everywhere: the
  `geo_map`/`geo_rule`/`geo_provider` registry families are now
  `register_geoscale_map`/`get_geoscale_map`/`list_geoscale_maps`/
  `clear_geoscale_maps`, `register_geoscale_rule`/`get_geoscale_rule`/
  `list_geoscale_rules`/`clear_geoscale_rules`, and
  `register_geoscale_provider`/`get_geoscale_provider`/
  `list_geoscale_providers`. `GEO_RULES` is now `GEOSCALE_RULES`.
- The deprecated shim family is REMOVED (29 `geo_*` aliases plus
  `geoscale_levels`, `is_valid_level`, `geoscale_from_leaves`,
  `CORE_LEVELS`; archived under `drafts/`).
- `geoscale_regions(x, geoframe = NULL)` – `geoframe` now defaults to
  the finest geoframe (the atoms). The required-geoframe rule is about
  arguments that take region CODES; this one only selects the output.

### New

- `coords_to_region(x, gs, geoframe = NULL)` – the spatial twin of
  [`timescales::datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.html):
  match point observations (sf/sfc or a data.frame with `lon`/`lat`
  columns) to the regions whose geometry contains them; `NA` outside
  every region.
- `geoscale_leaftable(x)` – exported accessor for the leaf table (stop
  reaching for `x@leaftable`).

## geoscales 0.4.2

### Breaking changes

- A filtered Geoscale is now book-kept as a SAMPLE (the spatial mirror
  of a partial calendar’s `year_fraction`):
  [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md)
  writes `meta$coverage` (per-weight kept fraction of the ROOT parent,
  so filters compose), `meta$parent_totals` (making coverage verifiable
  by the validator), `meta$parent_name`, and mangles `meta$name` to
  `"parent[geoframe:codes]"` – so two different samples of one parent
  can no longer poison each other’s crosswalk-registry entries or
  collide in
  [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
  column names.
  [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md)
  renames to `"parent@geoframe"` (the
  [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.html)
  convention), now preserves the FULL meta (`crs`, `source`, `labels`),
  reflects dropped unassigned atoms in coverage, and keeps attached
  geometry by dissolving it per new atom (`keep_geometry = FALSE` to opt
  out). Read the fraction with the new `geoscale_coverage(x, weight)`.
  Code that relied on a subset keeping its parent’s name can find the
  parent in `meta$parent_name`.

### New features

- [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
  and
  [`theme_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md):
  composable ggplot2 choropleth layer and map theme, mirroring
  [`timescales::geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.html)’s
  design (column-name arguments, one standard
  [`geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)
  layer, solid white background for dark-mode pages).
  [`plot()`](https://rspatial.github.io/terra/reference/plot.html) on a
  Geoscale now dispatches to
  [`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md).
- `get_geo_map()` and `list_geo_maps()` complete the crosswalk registry;
  `register_geo_map()`/`clear_geo_maps()` gain examples.
- [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md),
  [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
  and the stack view gain an opt-in `precision=` for snapping
  near-coincident boundaries before the dissolve (workaround for sources
  with floating-point-jittered shared edges; default off).
- `geoscale_autoplot(type = "stack")` draws the layer-stack view: one
  map plane per geoframe, the same atoms dissolved at every resolution
  (requires attached geometry). Points of view come as presets
  (`view = "oblique"/"top-down"/"cavalier"/"cabinet"/"military"/ "isometric"/"dimetric"/"trimetric"/"perspective"`)
  or via `angle`/`ratio` (oblique) and raw `shear`/`depth`; `rotate=`
  turns the plane in place (point North anywhere), `direction=` flips
  the stack, and the default `gap` leaves planes almost touching with a
  slight overlap.
- The stack view takes data: `data`/`z` colour every plane by an
  atom-keyed value, recast onto each coarser plane with
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
  (`rule`, default `"weighted_mean"`) so the whole stack shares one
  continuous scale; `labels=` writes region names on chosen planes and
  `palette=` picks the viridis option — or `NULL` to bring your own
  scale, e.g. energypal’s Global Wind Atlas colours on their absolute
  breaks. The stack canvas now hugs the content: tight x/y limits, left
  room sized to the geoframe names, legend pulled in close.
- The structure icicle carries data too:
  `geoscale_autoplot(data =, z =)` fills every band with the value
  recast to that geoframe (atoms keep their values, coarser bands
  aggregate by `rule` – `"weighted_mean"` default), with contrast-aware
  labels – the 2D twin of the stack’s data fill. The README gained a
  five-point “What geoscales offers” intro mirrored with timescales.
- Stack guides and borders: `frame=` draws each plane’s outline (its
  “sheet”) through the same projection, `frame_fill=` fills the sheets
  (best mostly transparent – glass panes), and `connectors=` adds dashed
  corner-to-corner guides between planes – curved shapes become easy to
  read in oblique views. `colour=`/`linewidth=` style the region
  borders, recycled per plane (defaults `"grey35"`/`0.2`, ggplot2’s own
  sf polygon border). Same additions in
  `timescales::calendar_autoplot(type = "stack")`. The README front page
  shows it on Iceland’s onshore wind resource, clustered from the Global
  Wind Atlas per region (`data-raw/iceland_wind.R`; build walk-through
  in
  [`vignette("geoscales")`](https://optimal2050.github.io/geoscales/r/articles/geoscales.md)).

### Bug fixes

- [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md)
  no longer fails with an opaque “differing number of rows” when
  [`sf::st_union()`](https://r-spatial.github.io/sf/reference/geos_combine.html)
  returns several parts for one code (seen with s2-invalid source
  polygons, e.g. PyPSA-Eur’s full-resolution region shapes): the parts
  are collapsed into the code’s single dissolved geometry. Healing the
  source with
  [`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)
  before attaching remains the better fix.

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
- A value column with neither `rule=` nor a `register_geo_rule()` entry
  is now an error; the silent `sum` fallback is gone.
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
  across two); `register_geo_map()` installs exact crosswalks,
  `clear_geo_maps()` resets.
- All converters run over `data.frame`, tibble, `data.table`, dtplyr,
  and arrow inputs; results come back in the input’s class, and lazy
  inputs return the uncollected query unless `collect = TRUE`.
- Rules `sum`, `weighted_mean`, `mean`, `copy`, and (new) `sd`, each
  defined in both directions; per-column defaults via
  `register_geo_rule()` / `get_geo_rule()` / `list_geo_rules()` /
  `clear_geo_rules()`; `na_action = c("drop", "error", "keep")` for
  partial coverage.
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
- Providers: `register_geo_provider()` / `get_geo_provider()` /
  `list_geo_providers()`; Natural Earth via
  [`ne_source()`](https://optimal2050.github.io/geoscales/r/reference/ne_source.md)
  /
  [`ne_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/ne_geoscale.md)
  with source and scale recorded in `meta`. The package ships no maps
  and selects no boundaries; known Natural Earth pitfalls
  (`iso_a3 == -99`, unreliable areas at 1:110m) are handled.

### Deprecations

Old names warn and forward; removal before 1.0: the `geo_*` family -\>
`verb_geoscale()` / `geoscale_*()` / `register_geo_*()` (e.g.
`geo_recast()` -\>
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
`geo_levels()` -\>
[`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md)),
and the 2026-08 lattice renames `geoscale_from_leaves()` -\>
[`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md),
`geoscale_levels()` -\>
[`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md),
`is_valid_level()` -\>
[`is_valid_geoframe()`](https://optimal2050.github.io/geoscales/r/reference/is_valid_geoframe.md),
`CORE_LEVELS` -\> `CORE_GEOFRAMES`.

### Documentation

- [`vignette("geoscales")`](https://optimal2050.github.io/geoscales/r/articles/geoscales.md)
  gains crosswalk, route-halves, attach, backends, and glossary
  sections; version files (`DESCRIPTION`, `VERSION`, NEWS) agree on
  0.2.0.9000.
