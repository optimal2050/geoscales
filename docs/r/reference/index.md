# Package index

## The Geoscale class

A nested spatial partition: a flat table of weighted leaf regions
(“atoms”) plus the ordered levels that group them.

- [`Geoscale()`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  : Geoscale (S7 class)

- [`geoscale_example()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_example.md)
  : A small example Geoscale

- [`geoscale_levels()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_levels.md)
  : Levels of a Geoscale

- [`geoscale_regions()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_regions.md)
  : Regions present at a level

- [`geoscale_rank()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_rank.md)
  : Level rank

- [`geoscale_weights()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_weights.md)
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

- [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
  : Recast values from one spatial level to another
- [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
  : Attach Geoscale metadata to region-keyed data
- [`GEO_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEO_RULES.md)
  : Supported aggregation rules
- [`register_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_rule.md)
  : Register how a parameter should be recast
- [`get_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_rule.md)
  : Look up a registered rule
- [`list_geo_rules()`](https://optimal2050.github.io/geoscales/r/reference/list_geo_rules.md)
  : List registered rules
- [`clear_geo_rules()`](https://optimal2050.github.io/geoscales/r/reference/clear_geo_rules.md)
  : Clear the rule registry

## Navigation and subsetting

Region codes are not unique across levels, so every lookup names its
level.

- [`geoscale_children()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md)
  [`geoscale_parents()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md)
  [`geoscale_descendants()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md)
  [`geoscale_ancestors()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md)
  : Navigate a region hierarchy
- [`geoscale_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_family.md)
  : Immediate parent-child table between two levels
- [`geoscale_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_ancestry.md)
  : Ancestry between all level pairs
- [`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md)
  : Do two levels nest?
- [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md)
  : Subset a Geoscale by region
- [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md)
  : Collapse a Geoscale to a coarser level
- [`geoscale_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_share.md)
  : Weight shares within a level

## Geometry and plotting

Optional, and backed by ‘sf’. The core is geometry-free;
[`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md)
draws the hierarchy itself and needs no map.

- [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md)
  : Attach geometry to a Geoscale
- [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md)
  : Geometry dissolved to a level
- [`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md)
  : Compute area weights from attached geometry
- [`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md)
  [`autoplot.Geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md)
  : Plot a Geoscale
- [`geoscale_plot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_plot.md)
  : Map data onto a Geoscale
- [`geoscale_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_layout.md)
  : Icicle layout for a Geoscale

## Data providers

geoscales ships integration code, not data. Natural Earth is the default
provider; its source and scale are recorded on the object, and no
boundaries are bundled.

- [`get_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_provider.md)
  : Look up a registered provider
- [`register_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_provider.md)
  : Register a Geoscale data provider
- [`list_geo_providers()`](https://optimal2050.github.io/geoscales/r/reference/list_geo_providers.md)
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

## Deprecated

- [`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_filter()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_prune()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_attach_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_area()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_levels()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_rank()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_weights()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_regions()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_children()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_parents()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_descendants()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_ancestors()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_plot()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_register_rule()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_get_rule()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_list_rules()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_clear_rules()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_register_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  [`geo_list_providers()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.md)
  : Deprecated geoscales functions

## Package

- [`geoscales`](https://optimal2050.github.io/geoscales/r/reference/geoscales-package.md)
  [`geoscales-package`](https://optimal2050.github.io/geoscales/r/reference/geoscales-package.md)
  : geoscales: Nested Regions and Spatial Hierarchies for Modeling
