"""Geometry (port of R/geometry.R): shapely + pyproj (+ geopandas for
GeoDataFrame input/output), the counterparts of sf. Optional: install
`geoscales[geo]`.

Geometry is per atom, in leaftable row order; its CRS is `meta$crs`.
"""
from __future__ import annotations

from collections.abc import Sequence
from typing import Any

import numpy as np
import pyarrow as pa

from ._utils import _check_geoframe, _check_geoscale, _stop, _warn
from .geoscale_class import GeoScale


def _need_geo(what: str = "this operation") -> None:
    try:
        import pyproj  # noqa: F401
        import shapely  # noqa: F401
    except ImportError:
        _stop("%s requires 'shapely' and 'pyproj'. Install them with pip install "
              "geoscales[geo].", what)


def _is_gdf(x: Any) -> bool:
    return hasattr(x, "geometry") and hasattr(x, "crs") and hasattr(x, "columns")


def _crs_string(crs: Any) -> str | None:
    if crs is None:
        return None
    import pyproj

    c = pyproj.CRS.from_user_input(crs)
    auth = c.to_authority()
    return "%s:%s" % auth if auth else c.to_string()


def _reproject(geoms: Sequence[Any], src: Any, dst: Any) -> list:
    """Geometries transformed between CRSs (x = lon/easting first)."""
    import pyproj
    import shapely

    tr = pyproj.Transformer.from_crs(src, dst, always_xy=True)

    def f(xy: np.ndarray) -> np.ndarray:
        x, y = tr.transform(xy[:, 0], xy[:, 1])
        return np.column_stack([x, y])

    return [None if g is None else shapely.transform(g, f) for g in geoms]


def _dissolve(geoms: Sequence[Any]) -> Any:
    """Union of a code's parts (sf: `st_union`, `st_combine` if needed)."""
    import shapely

    parts = [g for g in geoms if g is not None]
    if not parts:
        return None
    return shapely.union_all(parts)


def attach_geometry_geoscale(x: GeoScale, geom: Any, by: str | None = None,
                             geoframe: str | None = None,
                             crs: Any = None) -> GeoScale:
    """Attach per-atom geometry.

    `geom` is a GeoDataFrame matched on code column `by` (default: the
    geoframe's name, else `region`; with a coarser `geoframe` every atom
    inherits its parent's shape), or a sequence of shapely geometries
    already in leaftable row order (then `crs=` gives its CRS).
    """
    _check_geoscale(x)
    _need_geo("attach_geometry_geoscale()")
    lv = list(x.frames)
    geoframe = geoframe or lv[-1]
    _check_geoframe(x, geoframe)
    if _is_gdf(geom):
        if by is None:
            by = geoframe if geoframe in geom.columns else "region"
        if by not in geom.columns:
            _stop("`geom` has no column `%s`; pass `by=`", by)
        codes = [None if c is None else str(c) for c in geom[by].tolist()]
        pos = {c: i for i, c in enumerate(codes)}
        values = geom.geometry.values
        idx = [pos.get(c) for c in x.leaftable[geoframe].to_pylist()]
        if all(i is None for i in idx):
            _stop("no codes in `geom$%s` match geoframe `%s`", by, geoframe)
        n_miss = sum(i is None for i in idx)
        if n_miss:
            _warn("%d atom(s) have no matching geometry and are empty", n_miss)
        out = [None if i is None else values[i] for i in idx]
        crs = geom.crs
    else:
        out = list(geom)
        if len(out) != x.leaftable.num_rows:
            _stop("`geom` has %d geometries but `leaves` has %d rows; supply an `sf` "
                  "object to match on codes instead", len(out), x.leaftable.num_rows)
    meta = dict(x.meta)
    meta["crs"] = _crs_string(crs)
    return GeoScale(leaftable=x.leaftable, geoframes=x.frames, members=x.members,
                    geometry=out, meta=meta)


def geoscale_geometry(x: GeoScale, geoframe: str | None = None,
                      precision: float = 0):
    """One dissolved geometry per code at `geoframe`, in member order, as a
    GeoDataFrame (columns: the geoframe, `geometry`)."""
    _check_geoscale(x)
    _need_geo("geoscale_geometry()")
    import geopandas as gpd
    import shapely

    if x.geometry is None:
        _stop("no geometry attached; see `attach_geometry_geoscale()`")
    geoframe = geoframe or x.frames[-1]
    _check_geoframe(x, geoframe)
    codes = x.leaftable[geoframe].to_pylist()
    geoms = list(x.geometry)
    if precision > 0:
        # sf's precision is a scale factor (1000 = round to 1/1000); shapely
        # takes the grid size itself
        geoms = [None if g is None else shapely.make_valid(
            shapely.set_precision(g, 1 / precision)) for g in geoms]
    present = set(c for c in codes if c is not None)
    order = [c for c in x.members[geoframe] if c in present]
    merged = [_dissolve([g for g, c in zip(geoms, codes, strict=True) if c == cd])
              for cd in order]
    return gpd.GeoDataFrame({geoframe: order}, geometry=merged, crs=x.meta.get("crs"))


def add_area_geoscale(x: GeoScale, name: str = "km2",
                      crs: str = "ESRI:54034") -> GeoScale:
    """Add each atom's area (km2, in the equal-area `crs`) as a weight column."""
    _check_geoscale(x)
    _need_geo("add_area_geoscale()")
    import shapely

    if x.geometry is None:
        _stop("no geometry attached; see `attach_geometry_geoscale()`")
    src = x.meta.get("crs")
    if src:
        km2 = [None if g is None else shapely.make_valid(g).area / 1e6
               for g in _reproject(x.geometry, src, crs)]
    else:
        _warn("geometry has no CRS; `%s` is planar area in the coordinates' own "
              "units, not km2.", name)
        km2 = [None if g is None else shapely.make_valid(g).area for g in x.geometry]
    lt = x.leaftable
    col = pa.array(km2, pa.float64())
    lt = (lt.set_column(lt.column_names.index(name), name, col)
          if name in lt.column_names else lt.append_column(name, col))
    meta = dict(x.meta)
    meta["weights"] = list(dict.fromkeys([*(meta.get("weights") or ()), name]))
    meta["default_weight"] = meta.get("default_weight") or name
    return GeoScale(leaftable=lt, geoframes=x.frames, members=x.members,
                    geometry=x.geometry, meta=meta)


def coords_to_region(x: Any, gs: GeoScale, geoframe: str | None = None,
                     coords: Sequence[str] = ("lon", "lat"), crs: Any = 4326) -> list:
    """The code at `geoframe` of the region containing each point (first match
    in member order; None outside every region)."""
    _check_geoscale(gs)
    _need_geo("coords_to_region()")
    import pyproj
    import shapely
    from nestedscales import backend_pull

    shp = geoscale_geometry(gs, geoframe)
    geoframe = geoframe or gs.frames[-1]
    if _is_gdf(x):
        pts, pcrs = list(x.geometry.values), x.crs
    elif isinstance(x, (list, tuple, np.ndarray)) and len(x) and \
            hasattr(x[0], "geom_type"):
        pts, pcrs = list(x), None
    else:
        t = backend_pull(x)
        miss = [c for c in coords if c not in t.column_names]
        if miss:
            _stop("`x` has no coordinate column(s): %s; pass `coords=`",
                  ", ".join(miss))
        xs, ys = (t[c].to_pylist() for c in coords)
        pts = [shapely.Point(a, b) for a, b in zip(xs, ys, strict=True)]
        pcrs = crs
    if pcrs is not None and shp.crs is not None and \
            pyproj.CRS.from_user_input(pcrs) != shp.crs:
        pts = _reproject(pts, pcrs, shp.crs)
    tree = shapely.STRtree(list(shp.geometry.values))
    codes = shp[geoframe].tolist()
    out = []
    for p in pts:
        hits = sorted(tree.query(p, predicate="intersects").tolist())
        out.append(codes[hits[0]] if hits else None)
    return out

