"""Navigation, filtering and pruning (port of R/filter.R)."""
from __future__ import annotations

from typing import Any

import nestedscales as ns
import pyarrow as pa

from ._utils import _check_geoframe, _check_geoscale, _stop
from .construct import geoscale_from_leaftable
from .geoscale_class import GeoScale, geoscale_weights


def _geoframe_cols(t: pa.Table) -> pa.Table:
    return t.rename_columns([c.replace("_frame", "_geoframe") if c.endswith("_frame")
                             else c for c in t.column_names])


def geoscale_family(x: GeoScale, parent: str | None = None,
                    child: str | None = None) -> pa.Table:
    """Immediate parent-child pairs (all adjacent pairs by default)."""
    _check_geoscale(x)
    if parent is not None or child is not None:
        _check_geoframe(x, parent, "parent")
        _check_geoframe(x, child, "child")
    return _geoframe_cols(ns.scale_family(x, parent, child))


def geoscale_nests(x: GeoScale, parent: str, child: str):
    """Does every code at `child` sit inside one code at `parent`?"""
    _check_geoscale(x)
    _check_geoframe(x, parent, "parent")
    _check_geoframe(x, child, "child")
    return ns.scale_nests(x, parent, child)


def geoscale_ancestry(x: GeoScale) -> pa.Table:
    _check_geoscale(x)
    return _geoframe_cols(ns.scale_ancestry(x))


def _nav(fn: Any, x: GeoScale, geoframe: str, region: Any, target: str | None):
    _check_geoscale(x)
    _check_geoframe(x, geoframe)
    if target is not None:
        _check_geoframe(x, target, "target")
    return fn(x, geoframe, region, target)


def geoscale_children(x: GeoScale, geoframe: str, region: Any,
                      target: str | None = None) -> list[str]:
    return _nav(ns.scale_children, x, geoframe, region, target)


def geoscale_parents(x: GeoScale, geoframe: str, region: Any,
                     target: str | None = None) -> list[str]:
    return _nav(ns.scale_parents, x, geoframe, region, target)


def geoscale_descendants(x: GeoScale, geoframe: str, region: Any,
                         target: str | None = None) -> pa.Table:
    return _nav(ns.scale_descendants, x, geoframe, region, target).rename_columns(
        ["geoframe", "region"])


def geoscale_ancestors(x: GeoScale, geoframe: str, region: Any,
                       target: str | None = None) -> pa.Table:
    return _nav(ns.scale_ancestors, x, geoframe, region, target).rename_columns(
        ["geoframe", "region"])


def filter_geoscale(x: GeoScale, geoframe: str, region: Any,
                    drop_empty_geoframes: bool = False) -> GeoScale:
    """Keep the atoms of `region` at `geoframe`; a sample of the root parent.
    Attached geometry follows the kept rows."""
    _check_geoscale(x)
    _check_geoframe(x, geoframe)
    return ns.filter_scale(x, geoframe, region, drop_empty_frames=drop_empty_geoframes)


def geoscale_share(x: GeoScale, geoframe: str, weight: str | None = None,
                   within: str | None = None) -> pa.Table:
    _check_geoscale(x)
    _check_geoframe(x, geoframe)
    if within is not None:
        _check_geoframe(x, within, "within")
    return ns.scale_share(x, geoframe, weight=weight, within=within)


def _sample_meta(x: GeoScale, meta: dict, kept: pa.Table, tag: str) -> dict:
    wts = geoscale_weights(x)
    lt = x.leaftable

    def tot(t: pa.Table, w: str) -> float:
        return float(sum(z for z in t[w].to_pylist() if z is not None and z == z))

    totals = meta.get("parent_totals") or {w: tot(lt, w) for w in wts}
    meta = dict(meta)
    base = meta.get("parent_name") or meta.get("name")
    meta.update(parent_totals=dict(totals),
                coverage={w: tot(kept, w) / totals[w] for w in wts},
                parent_name=base, name="%s%s" % (base, tag))
    return meta


def prune_geoscale(x: GeoScale, geoframe: str,
                   keep_geometry: bool | None = None) -> GeoScale:
    """Collapse to `geoframe` (it becomes the atom layer), summing weights;
    renamed `"name@geoframe"`. Attached geometry is dissolved per code."""
    _check_geoscale(x)
    _check_geoframe(x, geoframe)
    if keep_geometry is None:
        keep_geometry = x.geometry is not None
    lv = list(x.frames)
    keep_lv = lv[:lv.index(geoframe) + 1]
    lt0 = x.leaftable
    codes0 = lt0[geoframe].to_pylist()
    covered = [c is not None for c in codes0]
    lt = lt0.filter(pa.array(covered))
    if lt.num_rows == 0:
        _stop("no atoms have a code at geoframe `%s`", geoframe)
    wts = geoscale_weights(x)
    keys = list(zip(*(lt[g].to_pylist() for g in keep_lv), strict=True))
    first: dict = {}
    for i, k in enumerate(keys):
        first.setdefault(k, i)
    groups = list(first)
    cols: dict[str, Any] = {g: pa.array([k[j] for k in groups], pa.string())
                            for j, g in enumerate(keep_lv)}
    for w in wts:
        acc: dict = {}
        for k, v in zip(keys, lt[w].to_pylist(), strict=True):
            acc[k] = acc.get(k, 0.0) + (float(v) if v is not None and v == v else 0.0)
        cols[w] = pa.array([acc[k] for k in groups], pa.float64())
    cols["region"] = cols[geoframe]
    out = pa.table(cols)

    meta = x.meta
    new_meta = dict(meta)
    if not all(covered):
        new_meta = _sample_meta(x, new_meta, lt, "")
    new_meta["parent_name"] = meta.get("name")
    new_meta["name"] = "%s@%s" % (meta.get("name") or "", geoframe)
    gs = geoscale_from_leaftable(out, geoframes=keep_lv, key="region", weights=wts,
                                 default_weight=meta.get("default_weight"),
                                 name=new_meta["name"], desc=meta.get("desc") or "")
    for k in ("weights", "default_weight"):  # R's modifyList(): NULL removes
        if gs.meta.get(k) is None:
            new_meta.pop(k, None)
        else:
            new_meta[k] = gs.meta[k]
    if new_meta.get("parent_name") is None:
        new_meta.pop("parent_name", None)
    geometry = None
    if keep_geometry and x.geometry is not None:
        from .geometry import _dissolve

        gk = [g for g, c in zip(x.geometry, covered, strict=True) if c]
        geometry = [_dissolve([g for g, k in zip(gk, keys, strict=True) if k == grp])
                    for grp in groups]
    return GeoScale(leaftable=gs.leaftable, geoframes=gs.frames, members=gs.members,
                    geometry=geometry, meta=new_meta)

