"""Crosswalks and joins (ports of R/map.R and R/join.R), delegating to
nestedscales."""
from __future__ import annotations

from collections.abc import Sequence
from typing import Any

import nestedscales as ns
import pyarrow as pa

from ._utils import _check_geoframe, _check_geoscale, _preview, _stop
from .geoscale_class import GeoScale


def geoscale_map(gs: GeoScale, source: str, target: str,
                 weight: str | None = None) -> pa.Table:
    """Crosswalk between two geoframes of one GeoScale."""
    if isinstance(source, GeoScale) or isinstance(target, GeoScale):
        _stop("`source` and `target` are geoframe names of `gs`; for the map "
              "between two GeoScales use `geoscale_map_between()`")
    _check_geoscale(gs, "gs")
    _check_geoframe(gs, source, "source")
    _check_geoframe(gs, target, "target")
    return ns.scale_map(gs, source, target, weight=weight)


def geoscale_map_between(source: GeoScale, target: GeoScale,
                         weight: str | None = None) -> pa.Table:
    """Crosswalk between two GeoScales through their shared atoms."""
    _check_geoscale(source, "source")
    _check_geoscale(target, "target")
    return ns.scale_map_between(source, target, weight=weight)


def register_geoscale_map(gs: GeoScale | str, source: str, target: str,
                          map: Any) -> str:
    if not isinstance(gs, str):
        _check_geoscale(gs, "gs")
    return ns.register_scale_map(gs, source, target, map)


def register_geoscale_map_between(source: GeoScale | str, target: GeoScale | str,
                                  map: Any) -> str:
    for a, z in (("source", source), ("target", target)):
        if not isinstance(z, str):
            _check_geoscale(z, a)
    return ns.register_scale_map_between(source, target, map)


def get_geoscale_map(gs: GeoScale | str, source: str, target: str):
    if not isinstance(gs, str):
        _check_geoscale(gs, "gs")
    return ns.get_scale_map(gs, source, target)


def get_geoscale_map_between(source: GeoScale | str, target: GeoScale | str):
    for a, z in (("source", source), ("target", target)):
        if not isinstance(z, str):
            _check_geoscale(z, a)
    return ns.get_scale_map_between(source, target)


def list_geoscale_maps() -> pa.Table:
    return ns.list_scale_maps()


def clear_geoscale_maps(name: str | Sequence[str] | None = None) -> None:
    ns.clear_scale_maps(name)


def join_geoscale(x: Any, gs: GeoScale, key: str | None = None,
                  geoframe: str | None = None,
                  geoframes: bool | str | Sequence[str] | None = None,
                  meta: bool = False, weight: str | None = None,
                  as_factor: bool = True, collect: bool | None = None) -> Any:
    """Attach the GeoScale's label, coarser codes (`<name>.<geoframe>`) and
    share/weight to `x`."""
    _check_geoscale(gs, "gs")
    if geoframe is None:
        cols = ns.backend_schema(x).names
        hit = [g for g in gs.frames if g in cols]
        if len(hit) != 1:
            _stop("cannot infer the code geoframe from `x`'s columns (found: %s); "
                  "pass `geoframe=`", "none" if not hit else _preview(hit))
        geoframe = hit[0]
    _check_geoframe(gs, geoframe, "geoframe")
    return ns.join_scale(x, gs, key=key, frame=geoframe, attach=geoframes,
                         meta=meta, weight=weight, as_factor=as_factor,
                         collect=collect)
