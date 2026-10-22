"""Internal utilities (port of R/utils.R). Errors and warnings are
nestedscales' classes, so one `except` catches a failure anywhere."""
from __future__ import annotations

import warnings
from collections.abc import Iterable

from nestedscales import NestedScalesError, NestedScalesWarning


def _stop(msg: str, *args: object) -> None:
    raise NestedScalesError(msg % args if args else msg)


def _warn(msg: str, *args: object) -> None:
    warnings.warn(msg % args if args else msg, NestedScalesWarning, stacklevel=3)


def _preview(x: Iterable[object], n: int = 3) -> str:
    x = [str(v) for v in x]
    if len(x) <= n:
        return ", ".join(x)
    return "%s, ... (%d total)" % (", ".join(x[:n]), len(x))


def _as_list(x: object) -> list:
    if x is None:
        return []
    if isinstance(x, str):
        return [x]
    if hasattr(x, "to_pylist"):
        return x.to_pylist()
    return list(x)


def _geoscale_name(gs, require: bool = True, arg: str = "gs") -> str:
    nm = gs.meta.get("name") or ""
    if require and not (isinstance(nm, str) and nm != ""):
        _stop("`%s` has no name; conversion and attach need a named GeoScale -- set "
              "meta$name, or pass `name=` to geoscale_from_leaftable()/"
              "geoscale_build()", arg)
    return nm


def _check_geoscale(x: object, arg: str = "x") -> None:
    from .geoscale_class import GeoScale

    if not isinstance(x, GeoScale):
        _stop("`%s` must be a GeoScale object", arg)


def _check_geoframe(x, geoframe: object, arg: str = "geoframe") -> None:
    lv = list(x.frames)
    if not isinstance(geoframe, str):
        _stop("`%s` must be a single geoframe name; one of: %s", arg, ", ".join(lv))
    if geoframe not in lv:
        _stop('`%s` = "%s" is not a geoframe of this GeoScale; one of: %s', arg,
              geoframe, ", ".join(lv))


def _resolve_weight(x, weight: str | None = None) -> str:
    wts = list(x.meta.get("weights") or ())
    if weight is None:
        weight = x.meta.get("default_weight") or (wts[0] if wts else None)
    if weight is None:
        _stop("no weight column available; declare one via `meta$weights` or pass "
              "`weight=`")
    if weight not in wts:
        _stop('`weight` = "%s" is not a weight column; one of: %s', weight,
              ", ".join(wts) if wts else "<none>")
    return weight


def _map_weight(x, weight: str | None) -> str | None:
    if not (x.meta.get("weights") or ()) and weight is None:
        return None
    return _resolve_weight(x, weight)
