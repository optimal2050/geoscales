# Package index

## The Geoscale class

A nested spatial partition: a flat table of weighted leaf regions
(“atoms”) plus the ordered levels that group them.

- [`Geoscale()`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  : Geoscale (S7 class)

- [`geoscale_example()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_example.md)
  : A small example Geoscale

- [`geo_levels()`](https://optimal2050.github.io/geoscales/r/reference/geo_levels.md)
  : Levels of a Geoscale

- [`geo_regions()`](https://optimal2050.github.io/geoscales/r/reference/geo_regions.md)
  : Regions present at a level

- [`geo_rank()`](https://optimal2050.github.io/geoscales/r/reference/geo_rank.md)
  : Level rank

- [`geo_weights()`](https://optimal2050.github.io/geoscales/r/reference/geo_weights.md)
  : Weight columns of a Geoscale

- [`` `[`( ``*`<Geoscale>`*`)`](https://optimal2050.github.io/geoscales/r/reference/sub-.Geoscale.md)
  [`` `[`( ``*`<geoscales::Geoscale>`*`)`](https://optimal2050.github.io/geoscales/r/reference/sub-.Geoscale.md)
  :

  Subset a Geoscale with `[`

## Construction

Three layers, from most to least convenient: a provider, parent-child
crosswalks, or a wide table you already have.

- [`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md)
  : Build a Geoscale from a provider
- [`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
  : Build a Geoscale from parent-child crosswalks
- [`geoscale_from_leaves()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaves.md)
  : Build a Geoscale from a flat table of leaf regions

## Conversion

Aggregation and disaggregation are one operation. Values are projected
down to atoms and aggregated up to the target, so direction follows the
level ranks and cross-cutting levels need no special handling.

- [`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geo_recast.md)
  : Recast values from one spatial level to another
- [`GEO_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEO_RULES.md)
  : Supported aggregation rules
- [`geo_register_rule()`](https://optimal2050.github.io/geoscales/r/reference/geo_register_rule.md)
  : Register how a parameter should be recast
- [`geo_get_rule()`](https://optimal2050.github.io/geoscales/r/reference/geo_get_rule.md)
  : Look up a registered rule
- [`geo_list_rules()`](https://optimal2050.github.io/geoscales/r/reference/geo_list_rules.md)
  : List registered rules
- [`geo_clear_rules()`](https://optimal2050.github.io/geoscales/r/reference/geo_clear_rules.md)
  : Clear the rule registry

## Navigation and subsetting

Region codes are not unique across levels, so every lookup names its
level.

- [`geo_children()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md)
  [`geo_parents()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md)
  [`geo_descendants()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md)
  [`geo_ancestors()`](https://optimal2050.github.io/geoscales/r/reference/geo_navigate.md)
  : Navigate a region hierarchy
- [`geo_family()`](https://optimal2050.github.io/geoscales/r/reference/geo_family.md)
  : Immediate parent-child table between two levels
- [`geo_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geo_ancestry.md)
  : Ancestry between all level pairs
- [`geo_nests()`](https://optimal2050.github.io/geoscales/r/reference/geo_nests.md)
  : Do two levels nest?
- [`geo_filter()`](https://optimal2050.github.io/geoscales/r/reference/geo_filter.md)
  : Subset a Geoscale by region
- [`geo_prune()`](https://optimal2050.github.io/geoscales/r/reference/geo_prune.md)
  : Collapse a Geoscale to a coarser level
- [`geo_share()`](https://optimal2050.github.io/geoscales/r/reference/geo_share.md)
  : Weight shares within a level

## Geometry and plotting

Optional, and backed by ‘sf’. The core is geometry-free;
[`geo_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geo_autoplot.md)
draws the hierarchy itself and needs no map.

- [`geo_attach_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geo_attach_geometry.md)
  : Attach geometry to a Geoscale
- [`geo_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geo_geometry.md)
  : Geometry dissolved to a level
- [`geo_area()`](https://optimal2050.github.io/geoscales/r/reference/geo_area.md)
  : Compute area weights from attached geometry
- [`geo_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geo_autoplot.md)
  [`autoplot.Geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geo_autoplot.md)
  : Plot a Geoscale
- [`geo_plot()`](https://optimal2050.github.io/geoscales/r/reference/geo_plot.md)
  : Map data onto a Geoscale
- [`geo_layout()`](https://optimal2050.github.io/geoscales/r/reference/geo_layout.md)
  : Icicle layout for a Geoscale

## Data providers

geoscales ships integration code, not data. Natural Earth is the default
provider; its source and scale are recorded on the object, and no
boundaries are bundled.

- [`geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/geo_provider.md)
  : Look up a registered provider
- [`geo_register_provider()`](https://optimal2050.github.io/geoscales/r/reference/geo_register_provider.md)
  : Register a Geoscale data provider
- [`geo_list_providers()`](https://optimal2050.github.io/geoscales/r/reference/geo_list_providers.md)
  : List registered providers
- [`ne_source()`](https://optimal2050.github.io/geoscales/r/reference/ne_source.md)
  : Fetch a Natural Earth source table
- [`ne_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/ne_geoscale.md)
  : Build a Geoscale from Natural Earth

## Levels

- [`CORE_LEVELS`](https://optimal2050.github.io/geoscales/r/reference/CORE_LEVELS.md)
  : Core spatial levels
- [`is_valid_level()`](https://optimal2050.github.io/geoscales/r/reference/is_valid_level.md)
  : Validate level names

## Package

- [`geoscales`](https://optimal2050.github.io/geoscales/r/reference/geoscales-package.md)
  [`geoscales-package`](https://optimal2050.github.io/geoscales/r/reference/geoscales-package.md)
  : geoscales: Nested Regions and Spatial Hierarchies for Modeling
