# Changelog

## geoscales 0.1.0.9000

### Harmonized naming with timescales

One convention across the sibling packages: **`verb_class()`** for data
operations and object transforms, **class-prefixed nouns** for
properties and queries, constructors unchanged, registries
`register_/get_/list_/clear_` with a `geo` domain word. The old `geo_*`
names warn and forward (removal before 1.0):

- Verbs:
  [`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  -\>
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
  [`geo_filter()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  -\>
  [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md),
  [`geo_prune()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  -\>
  [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md),
  [`geo_attach_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  -\>
  [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md),
  [`geo_area()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  -\>
  [`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md).
- Properties/queries: `geo_<x>()` -\> `geoscale_<x>()` (levels, rank,
  weights, regions, family, nests, ancestry, children, parents,
  descendants, ancestors, share, geometry, layout, autoplot, plot).
  [`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md)’s
  first argument is now `x`.
- Registries:
  [`geo_register_rule()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  -\>
  [`register_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_rule.md)
  (and get/list/clear alike);
  [`geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  -\>
  [`get_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_provider.md).
- **[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.html)
  method registered on the timescales generic** (timescales moved to
  Imports): `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")`
  chains time and space; the source level is inferred from `x`’s columns
  or passed as `from_level=`.
- New
  [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md):
  attach coarser-level membership plus weight/share columns to
  region-keyed data — the spatial mirror of
  [`timescales::join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.html).

### Milestone 1

First working version: the `Geoscale` class, the conversion verb,
navigation, plotting, and the Natural Earth provider.

#### Core

- `Geoscale`, an S7 class holding `leaves` (one row per atom, one column
  per level), `levels` (ordered coarsest first), `members` (code
  vocabulary per level), optional `geometry`, and `meta`. Everything
  derivable is computed on demand; nothing is cached on the object.
- Three construction layers:
  [`geoscale_from_leaves()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaves.md)
  (escape hatch),
  [`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
  (from parent-child crosswalks — ragged, not Cartesian, because ragged
  hierarchies are the norm in space), and
  [`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md).
- [`geoscale_example()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_example.md),
  a synthetic fixture reproducing three awkward features of real region
  tables: a code reused at several levels, a cross-cutting level pair,
  and an atom with no code at any coarser level.

#### Conversion

- [`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  — aggregation and disaggregation as a single operation. Source values
  are projected down to atoms and then aggregated up to the target, so
  direction falls out of the level ranks and cross-cutting levels work
  without special handling.
- Rules `sum`, `weighted_mean`, `mean` and `copy`, each defined in both
  directions.
- [`geo_register_rule()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  /
  [`geo_get_rule()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  /
  [`geo_list_rules()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  — a per-parameter rule registry, with an explicit `rule=` always
  taking precedence.
- `na_action = "drop" | "error" | "keep"` for partial coverage. `"drop"`
  genuinely loses the uncovered share and warns with a count; `"keep"`
  conserves totals into an explicit `NA` group.
- Identifier columns are preserved as grouping columns, so panel data
  converts in one call.

#### Navigation and subsetting

- [`geo_children()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_parents()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_descendants()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_ancestors()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_regions()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_filter()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_prune()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  and `[`.
- `level` is a required argument throughout: region codes are not unique
  across levels, so a bare code is ambiguous.
- [`geo_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  and
  [`geo_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md).
  Ancestry is computed atom-mediated rather than as a transitive closure
  — closing over a cross-cutting level would manufacture false
  relationships.

#### Geometry and plotting

- [`geo_attach_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md),
  [`geo_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  (dissolve to a level) and
  [`geo_area()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md).
  `sf` is in Suggests; the core is geometry-free.
- [`geo_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  draws the hierarchy as an icicle and needs no geometry;
  [`geo_plot()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  draws a choropleth when geometry is attached.
  [`geo_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  exposes the rectangle coordinates for other plotting systems.

#### Providers

- [`geo_register_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  /
  [`geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  /
  [`geo_list_providers()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md).
- Natural Earth via
  [`ne_source()`](https://optimal2050.github.io/geoscales/r/reference/ne_source.md)
  and
  [`ne_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/ne_geoscale.md),
  with `source` and `scale` recorded in `meta`. **The package ships no
  maps and selects no boundaries.**
- Three Natural Earth pitfalls are handled: `adm0_a3` is used as the
  join key (`iso_a3` is `-99` for five countries at 1:110m); area
  weights are refused at scale 110 with a warning; and `-99` is
  converted to `NA` in numeric attributes as well as code columns.
