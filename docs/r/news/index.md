# Changelog

## geoscales 0.1.0.9000

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

- [`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geo_recast.md)
  — aggregation and disaggregation as a single operation. Source values
  are projected down to atoms and then aggregated up to the target, so
  direction falls out of the level ranks and cross-cutting levels work
  without special handling.
- Rules `sum`, `weighted_mean`, `mean` and `copy`, each defined in both
  directions.
- [`geo_register_rule()`](https://optimal2050.github.io/geoscales/r/reference/geo_register_rule.md)
  /
  [`geo_get_rule()`](https://optimal2050.github.io/geoscales/r/reference/geo_get_rule.md)
  /
  [`geo_list_rules()`](https://optimal2050.github.io/geoscales/r/reference/geo_list_rules.md)
  — a per-parameter rule registry, with an explicit `rule=` always
  taking precedence.
- `na_action = "drop" | "error" | "keep"` for partial coverage. `"drop"`
  genuinely loses the uncovered share and warns with a count; `"keep"`
  conserves totals into an explicit `NA` group.
- Identifier columns are preserved as grouping columns, so panel data
  converts in one call.

#### Navigation and subsetting

- [`geo_children()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md),
  [`geo_parents()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md),
  [`geo_descendants()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md),
  [`geo_ancestors()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md),
  [`geo_regions()`](https://optimal2050.github.io/geoscales/r/reference/geo_regions.md),
  [`geo_filter()`](https://optimal2050.github.io/geoscales/r/reference/geo_filter.md),
  [`geo_prune()`](https://optimal2050.github.io/geoscales/r/reference/geo_prune.md),
  [`geo_share()`](https://optimal2050.github.io/geoscales/r/reference/geo_share.md)
  and `[`.
- `level` is a required argument throughout: region codes are not unique
  across levels, so a bare code is ambiguous.
- [`geo_family()`](https://optimal2050.github.io/geoscales/r/reference/geo_family.md),
  [`geo_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geo_ancestry.md)
  and
  [`geo_nests()`](https://optimal2050.github.io/geoscales/r/reference/geo_nests.md).
  Ancestry is computed atom-mediated rather than as a transitive closure
  — closing over a cross-cutting level would manufacture false
  relationships.

#### Geometry and plotting

- [`geo_attach_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geo_attach_geometry.md),
  [`geo_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geo_geometry.md)
  (dissolve to a level) and
  [`geo_area()`](https://optimal2050.github.io/geoscales/r/reference/geo_area.md).
  `sf` is in Suggests; the core is geometry-free.
- [`geo_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geo_autoplot.md)
  draws the hierarchy as an icicle and needs no geometry;
  [`geo_plot()`](https://optimal2050.github.io/geoscales/r/reference/geo_plot.md)
  draws a choropleth when geometry is attached.
  [`geo_layout()`](https://optimal2050.github.io/geoscales/r/reference/geo_layout.md)
  exposes the rectangle coordinates for other plotting systems.

#### Providers

- [`geo_register_provider()`](https://optimal2050.github.io/geoscales/r/reference/geo_register_provider.md)
  /
  [`geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/geo_provider.md)
  /
  [`geo_list_providers()`](https://optimal2050.github.io/geoscales/r/reference/geo_list_providers.md).
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
