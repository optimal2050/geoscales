"""Data providers (ports of R/providers.R and R/naturalearth.R).

A provider fetches a table (or GeoDataFrame) of atoms; `geoscale_from_provider()`
turns it into a GeoScale. The built-in "naturalearth" provider reads the
Natural Earth admin-0 / admin-1 shapefiles (downloaded from naciscdn.org on
first use and cached), where R reads rnaturalearth's data packages.
"""
from __future__ import annotations

from collections.abc import Callable, Sequence
from pathlib import Path
from typing import Any

import pyarrow as pa
from nestedscales import backend_pull

from ._utils import _as_list, _preview, _stop, _warn
from .construct import geoscale_from_leaftable
from .geoscale_class import GeoScale

_PROVIDER_REGISTRY: dict[str, dict] = {}


def register_geoscale_provider(name: str, fetch: Callable[..., Any],
                               geoframes: Sequence[str] | None = None,
                               weights: Sequence[str] | None = None,
                               desc: str = "") -> dict:
    if not isinstance(name, str) or name == "":
        _stop("`name` must be a single non-empty string")
    if not callable(fetch):
        _stop("`fetch` must be a function")
    entry = {"name": name, "fetch": fetch, "geoframes": geoframes,
             "weights": weights, "desc": desc}
    _PROVIDER_REGISTRY[name] = entry
    return entry


def get_geoscale_provider(name: str) -> dict:
    if not isinstance(name, str) or name not in _PROVIDER_REGISTRY:
        _stop('unknown provider "%s"; registered: %s', name,
              ", ".join(sorted(_PROVIDER_REGISTRY)))
    return _PROVIDER_REGISTRY[name]


def list_geoscale_providers() -> pa.Table:
    nms = sorted(_PROVIDER_REGISTRY)
    return pa.table({"name": pa.array(nms, pa.string()),
                     "desc": pa.array([_PROVIDER_REGISTRY[n]["desc"] or ""
                                       for n in nms], pa.string())})


def geoscale_from_provider(provider: Any = "naturalearth",
                           geoframes: Sequence[str] | None = None,
                           weights: Sequence[str] | None = None, geometry: bool = True,
                           name: str = "", desc: str = "", **kwargs: Any) -> GeoScale:
    """A GeoScale from a registered provider, or from a table/GeoDataFrame."""
    if isinstance(provider, str):
        p = get_geoscale_provider(provider)
        src = p["fetch"](**kwargs)
        geoframes = geoframes or p["geoframes"]
        weights = weights if weights is not None else p["weights"]
        src_name = provider
    else:
        src, src_name = provider, "custom"
    if geoframes is None:
        _stop("`geoframes` must be given (the provider declares no default)")
    geom, crs = None, None
    if hasattr(src, "geometry") and hasattr(src, "crs"):  # GeoDataFrame
        if geometry:
            geom = src.geometry.values
            crs = None if src.crs is None else src.crs.to_string()
        src = src.drop(columns=src.geometry.name)
    t = src if isinstance(src, pa.Table) else backend_pull(src)
    if "geometry" in t.column_names:
        t = t.drop_columns(["geometry"])
    geoframes = _as_list(geoframes)
    missing = [g for g in geoframes if g not in t.column_names]
    if missing:
        _stop("source has no column(s): %s", _preview(missing))
    wts = [w for w in _as_list(weights) if w in t.column_names]
    gs = geoscale_from_leaftable(t.select([*geoframes, *wts]), geoframes=geoframes,
                                 weights=wts, name=name, desc=desc, source=src_name)
    if geom is not None:
        meta = dict(gs.meta)
        if crs is not None:
            meta["crs"] = crs
        gs = GeoScale(leaftable=gs.leaftable, geoframes=gs.frames,
                      members=gs.members, geometry=geom, meta=meta)
    return gs


_NE_URL = "https://naciscdn.org/naturalearth/{scale}m/cultural/{layer}.zip"


def _ne_cache() -> Path:
    import os

    root = os.environ.get("GEOSCALES_CACHE") or (Path.home() / ".cache" / "geoscales")
    p = Path(root)
    p.mkdir(parents=True, exist_ok=True)
    return p


def ne_source(scale: int = 110, geoframe: str = "country",
              country: str | Sequence[str] | None = None, path: str | None = None):
    """Natural Earth admin-0 ("country") or admin-1 ("states") features as a
    GeoDataFrame, with `feature` and `country` columns (adm0_a3/adm1_code,
    "-99" as missing). `path` reads a local shapefile/zip instead of the
    cached download."""
    try:
        import geopandas as gpd
    except ImportError:
        _stop("the Natural Earth provider requires 'geopandas'. Install it with "
              "pip install geoscales[geo].")
    if geoframe not in ("country", "states"):
        _stop('`geoframe` should be one of: country, states')
    layer = ("ne_%dm_admin_0_countries" % scale if geoframe == "country"
             else "ne_10m_admin_1_states_provinces")
    if path is None:
        f = _ne_cache() / ("%s.zip" % layer)
        if not f.exists():
            import urllib.request

            url = _NE_URL.format(scale=scale if geoframe == "country" else 10,
                                 layer=layer)
            urllib.request.urlretrieve(url, f)  # noqa: S310 (fixed https URL)
        path = str(f)
    x = gpd.read_file(path)
    x.columns = [c.lower() if c != x.geometry.name else c for c in x.columns]
    if country is not None:
        want = set(_as_list(country))
        x = x[x["admin"].isin(want) | x.get("name", x["admin"]).isin(want)
              | x["adm0_a3"].isin(want)]
    code = "adm1_code" if geoframe == "states" else "adm0_a3"
    x["feature"] = x[code].astype(str).where(x[code].astype(str) != "-99")
    x["country"] = x["adm0_a3"].astype(str).where(x["adm0_a3"].astype(str) != "-99")
    f = x["feature"]
    if f.isna().any():
        _stop("Natural Earth returned %d feature(s) with no `%s`", int(f.isna().sum()),
              code)
    if f.duplicated().any():
        _stop("Natural Earth returned duplicated `%s`: %s", code,
              _preview(f[f.duplicated()].unique().tolist()))
    return x


def ne_geoscale(scale: int = 110,
                geoframes: Sequence[str] = ("continent", "subregion", "country",
                                            "feature"),
                weights: Sequence[str] = ("pop_est", "gdp_md"), geometry: bool = True,
                **kwargs: Any) -> GeoScale:
    """The Natural Earth admin-0 hierarchy as a GeoScale."""
    src = ne_source(scale=scale, **kwargs)
    for w in weights:
        if w in src.columns and src[w].dtype.kind in "fi":
            src[w] = src[w].astype(float).where(src[w] != -99)
    if scale == 110 and any(("km2" in w.lower() or "area" in w.lower())
                            for w in weights):
        _warn("scale = 110 is a cartographic generalisation and is not suitable for "
              "area weights (Chile is +10.6%, Indonesia -3.2% against 1:10m). Use "
              "scale = 10.")
    gs = geoscale_from_provider(src, geoframes=list(geoframes), weights=list(weights),
                                geometry=geometry, name="naturalearth-%s" % scale,
                                desc="Natural Earth admin-0 hierarchy")
    meta = dict(gs.meta)
    meta.update(source="naturalearth", scale=scale)
    return GeoScale(leaftable=gs.leaftable, geoframes=gs.frames, members=gs.members,
                    geometry=gs.geometry, meta=meta)


register_geoscale_provider(
    "naturalearth", fetch=lambda **kw: ne_source(**kw),
    geoframes=["continent", "subregion", "country", "feature"],
    weights=["pop_est", "gdp_md"], desc="Natural Earth admin-0/admin-1 (naciscdn)")
