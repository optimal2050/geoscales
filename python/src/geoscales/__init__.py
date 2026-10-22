"""geoscales: regions and spatial hierarchies for modeling.

Python binding of the R package of the same name, built on nestedscales.
Function names match R; R's `from`/`to` arguments are `source`/`target`.
Geometry is optional (`pip install geoscales[geo]`).
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
    geoscale_coverage,
    geoscale_geoframes,
    geoscale_leaftable,
    geoscale_rank,
    geoscale_regions,
    geoscale_summary,
    geoscale_weights,
    is_valid_geoframe,
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
    recast_from_geoatoms,
    recast_geoscale,
    recast_pairs,
    recast_to_geoatoms,
)
from .rules import (
    GEOSCALE_RULES,
    clear_geoscale_rules,
    get_geoscale_rule,
    list_geoscale_rules,
    register_geoscale_rule,
)
from .zoom import zoom_geoscale

try:  # the generic lives in nestedscales; re-exported as in R
    from nestedscales import recast
except ImportError:  # pragma: no cover
    recast = None


def as_geoscale(x):
    """A GeoScale from a NestedScale holding one (e.g. a scale reopened from a
    `nestedscales` store, which records no class)."""
    import nestedscales as ns

    from ._utils import _stop

    if isinstance(x, GeoScale):
        return x
    if not ns.scale_is(x):
        _stop("`x` must be a NestedScale or GeoScale object")
    return GeoScale(leaftable=x.leaftable, geoframes=x.frames, members=x.members,
                    meta=x.meta)


__version__ = "0.7.0"

__all__ = [
    "CORE_GEOFRAMES", "GEOSCALE_RULES", "GeoScale", "GeoScaleSummary",
    "add_area_geoscale", "as_geoscale", "attach_geometry_geoscale",
    "clear_geoscale_maps", "clear_geoscale_rules", "coords_to_region",
    "filter_geoscale", "geoscale_ancestors", "geoscale_ancestry", "geoscale_build",
    "geoscale_children", "geoscale_coverage", "geoscale_descendants",
    "geoscale_example", "geoscale_family", "geoscale_from_leaftable",
    "geoscale_from_provider", "geoscale_geoframes", "geoscale_geometry",
    "geoscale_leaftable", "geoscale_map", "geoscale_map_between", "geoscale_nests",
    "geoscale_parents", "geoscale_rank", "geoscale_regions", "geoscale_share",
    "geoscale_summary", "geoscale_weights", "get_geoscale_map",
    "get_geoscale_map_between", "get_geoscale_provider", "get_geoscale_rule",
    "is_valid_geoframe", "join_geoscale", "list_geoscale_maps",
    "list_geoscale_providers", "list_geoscale_rules", "ne_geoscale", "ne_source",
    "prune_geoscale", "recast", "recast_from_geoatoms", "recast_geoscale",
    "recast_pairs", "recast_to_geoatoms", "register_geoscale_map",
    "register_geoscale_map_between", "register_geoscale_provider",
    "register_geoscale_rule", "zoom_geoscale",
]
