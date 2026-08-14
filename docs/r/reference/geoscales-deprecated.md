# Deprecated geoscales functions

These functions were renamed under the harmonized naming convention
shared with the timescales package. The old names warn and forward to
their replacements; they will be removed before the 1.0 release.

## Usage

``` r
geo_recast(...)

geo_filter(...)

geo_prune(...)

geo_attach_geometry(...)

geo_area(...)

geo_levels(...)

geo_rank(...)

geo_weights(...)

geo_regions(...)

geo_family(...)

geo_nests(...)

geo_ancestry(...)

geo_children(...)

geo_parents(...)

geo_descendants(...)

geo_ancestors(...)

geo_share(...)

geo_geometry(...)

geo_layout(...)

geo_autoplot(...)

geo_plot(...)

geo_register_rule(...)

geo_get_rule(...)

geo_list_rules(...)

geo_clear_rules(...)

geo_register_provider(...)

geo_provider(...)

geo_list_providers(...)
```

## Arguments

- ...:

  Arguments forwarded to the replacement function.

## Value

See the replacement function.

## Details

Data operations and object transforms (`verb_geoscale`): `geo_recast()`
-\>
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
(or the
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.html)
generic), `geo_filter()` -\>
[`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md),
`geo_prune()` -\>
[`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md),
`geo_attach_geometry()` -\>
[`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md),
`geo_area()` -\>
[`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md).

Properties and queries (`geoscale_*`): `geo_levels()` -\>
[`geoscale_levels()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_levels.md),
`geo_rank()` -\>
[`geoscale_rank()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_rank.md),
`geo_weights()` -\>
[`geoscale_weights()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_weights.md),
`geo_regions()` -\>
[`geoscale_regions()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_regions.md),
`geo_family()` -\>
[`geoscale_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_family.md),
`geo_nests()` -\>
[`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md),
`geo_ancestry()` -\>
[`geoscale_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_ancestry.md),
`geo_children()` -\>
[`geoscale_children()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md),
`geo_parents()` -\>
[`geoscale_parents()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md),
`geo_descendants()` -\>
[`geoscale_descendants()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md),
`geo_ancestors()` -\>
[`geoscale_ancestors()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md),
`geo_share()` -\>
[`geoscale_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_share.md),
`geo_geometry()` -\>
[`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md),
`geo_layout()` -\>
[`geoscale_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_layout.md),
`geo_autoplot()` -\>
[`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md),
`geo_plot()` -\>
[`geoscale_plot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_plot.md).

Registries: `geo_register_rule()` -\>
[`register_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_rule.md),
`geo_get_rule()` -\>
[`get_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_rule.md),
`geo_list_rules()` -\>
[`list_geo_rules()`](https://optimal2050.github.io/geoscales/r/reference/list_geo_rules.md),
`geo_clear_rules()` -\>
[`clear_geo_rules()`](https://optimal2050.github.io/geoscales/r/reference/clear_geo_rules.md),
`geo_register_provider()` -\>
[`register_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_provider.md),
`geo_provider()` -\>
[`get_geo_provider()`](https://optimal2050.github.io/geoscales/r/reference/get_geo_provider.md),
`geo_list_providers()` -\>
[`list_geo_providers()`](https://optimal2050.github.io/geoscales/r/reference/list_geo_providers.md).
