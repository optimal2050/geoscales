"""geoscales: regions and spatial hierarchies for modeling.

Python binding of the R package of the same name, built on nestedscales.
Function and argument names match R. Geometry is optional
(`pip install geoscales[geo]`).
"""
from .construct import geoscale_build, geoscale_example, geoscale_from_leaftable
from .geometry import (
    add_area_geoscale,
    attach_geometry_geoscale,
    coords_to_region,
    geoscale_geometry,
)
from .geoscale_class import (
    CORE_GEOFRAMES,
    GeoScale,
    GeoScaleSummary,
    geoscale_add_weight,
    geoscale_coverage,
    geoscale_geoframes,
    geoscale_leaftable,
    geoscale_rank,
    geoscale_regions,
    geoscale_summary,
    geoscale_weights,
    is_valid_geoframe,
)
from .labels import (
    attach_labels_geoscale,
    geoscale_label,
    geoscale_labels,
    geoscale_leaf_column,
)
from .map import (
    clear_geoscale_maps,
    geoscale_map,
    geoscale_map_between,
    get_geoscale_map,
    get_geoscale_map_between,
    join_geoscale,
    list_geoscale_maps,
    register_geoscale_map,
    register_geoscale_map_between,
)
from .navigate import (
    filter_geoscale,
    geoscale_ancestors,
    geoscale_ancestry,
    geoscale_children,
    geoscale_descendants,
    geoscale_family,
    geoscale_nests,
    geoscale_parents,
    geoscale_share,
    prune_geoscale,
)
from .providers import (
    geoscale_from_provider,
    get_geoscale_provider,
    list_geoscale_providers,
    ne_geoscale,
    ne_source,
    register_geoscale_provider,
)
from .recast import (
    recast_from_geoleaves,
    recast_geoscale,
    recast_pairs,
    recast_to_geoleaves,
)
from .rules import (
    GEOSCALE_RULES,
    clear_geoscale_rules,
    geoscale_rule_action,
    get_geoscale_rule,
    list_geoscale_rules,
    register_geoscale_rule,
)
from .visible import (
    geoscale_id,
    geoscale_tree,
    hide_geoframes_geoscale,
    show_geoframes_geoscale,
)
from .zoom import zoom_geoscale

try:  # the generic lives in nestedscales; re-exported as in R
    from nestedscales import recast
except ImportError:  # pragma: no cover
    recast = None


def as_geoscale(x):
    """A GeoScale from a NestedScale holding one: a scale reopened from a
    nestedscales store, which records no class, or a definition file read
    with `read_scale(cls="core")`. The leaf column, the labels, attributes
    and aliases are carried over; geometry and hidden geoframes are not
    part of either file."""
    import nestedscales as ns

    from ._utils import _stop

    if isinstance(x, GeoScale):
        return x
    if not ns.scale_is(x):
        _stop("`x` must be a NestedScale or GeoScale object")
    return GeoScale(leaftable=x.leaftable, geoframes=x.frames, members=x.members,
                    meta=x.meta, leaf=x.leaf, labels=x.labels,
                    attributes=x.attributes, aliases=x.aliases)


__version__ = "0.8.0"

__all__ = [
    "CORE_GEOFRAMES", "GEOSCALE_RULES", "GeoScale", "GeoScaleSummary",
    "add_area_geoscale", "as_geoscale", "attach_geometry_geoscale",
    "attach_labels_geoscale", "clear_geoscale_maps", "clear_geoscale_rules",
    "coords_to_region", "filter_geoscale", "geoscale_add_weight",
    "geoscale_ancestors", "geoscale_ancestry", "geoscale_build",
    "geoscale_children", "geoscale_coverage", "geoscale_descendants",
    "geoscale_example", "geoscale_family", "geoscale_from_leaftable",
    "geoscale_from_provider", "geoscale_geoframes", "geoscale_geometry",
    "geoscale_id", "geoscale_label", "geoscale_labels", "geoscale_leaf_column",
    "geoscale_leaftable", "geoscale_map", "geoscale_map_between", "geoscale_nests",
    "geoscale_parents", "geoscale_rank", "geoscale_regions",
    "geoscale_rule_action", "geoscale_share", "geoscale_summary", "geoscale_tree",
    "geoscale_weights", "get_geoscale_map", "get_geoscale_map_between",
    "get_geoscale_provider", "get_geoscale_rule", "hide_geoframes_geoscale",
    "is_valid_geoframe", "join_geoscale", "list_geoscale_maps",
    "list_geoscale_providers", "list_geoscale_rules", "ne_geoscale", "ne_source",
    "prune_geoscale", "recast", "recast_from_geoleaves", "recast_geoscale",
    "recast_pairs", "recast_to_geoleaves", "register_geoscale_map",
    "register_geoscale_map_between", "register_geoscale_provider",
    "register_geoscale_rule", "show_geoframes_geoscale", "zoom_geoscale",
]
