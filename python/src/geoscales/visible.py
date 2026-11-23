"""Geoframes hidden from plots (port of R/visible.R), and the identity and
parts of a GeoScale (port of R/tree.R).

A geoframe may exist for calculation only: grid cells or clusters that carry
the weights and the crosswalks but are not something a figure should show.
The object lists such geoframes in `hidden`. Recasts, joins and navigation
see every geoframe.
"""
from __future__ import annotations

from collections.abc import Sequence

from nestedscales import scale_id, scale_set_props, scale_tree

from ._utils import _as_list, _check_geoframe, _check_geoscale, _stop
from .geoscale_class import GeoScale, _hidden


def _names(geoframes: object, null_ok: bool) -> list[str]:
    ok = isinstance(geoframes, str) or (
        isinstance(geoframes, (list, tuple)) and all(
            isinstance(g, str) for g in geoframes))
    if not ok:
        _stop("`geoframes` must be %sa character vector of geoframe names",
              "NULL or " if null_ok else "")
    return _as_list(geoframes)


def hide_geoframes_geoscale(x: GeoScale, geoframes: str | Sequence[str]) -> GeoScale:
    """Mark geoframes as hidden from plots; they stay available to recasts,
    joins and navigation. At least one geoframe must stay visible."""
    _check_geoscale(x)
    geoframes = _names(geoframes, null_ok=False)
    for g in geoframes:
        _check_geoframe(x, g, "geoframes")
    hidden = tuple(dict.fromkeys([*_hidden(x), *geoframes]))
    return scale_set_props(x, check=True, hidden=hidden)


def show_geoframes_geoscale(x: GeoScale,
                            geoframes: str | Sequence[str] | None = None) -> GeoScale:
    """Make hidden geoframes visible again: the named ones, or all of them
    when `geoframes` is None."""
    _check_geoscale(x)
    if geoframes is None:
        return scale_set_props(x, check=True, hidden=())
    geoframes = _names(geoframes, null_ok=True)
    for g in geoframes:
        _check_geoframe(x, g, "geoframes")
    hidden = tuple(h for h in _hidden(x) if h not in geoframes)
    return scale_set_props(x, check=True, hidden=hidden)


def geoscale_id(gs: GeoScale) -> str:
    """The identity of a GeoScale, `"<name>@<hash>"`: the hash covers the leaf
    column, the geoframes and the leaf-to-geoframe memberships, and is the
    same string as in R for the same GeoScale."""
    _check_geoscale(gs, "gs")
    return scale_id(gs)


def geoscale_tree(x: GeoScale):
    """The parts of a GeoScale as a tree, each marked `fixed` (it enters the
    identity), `derived` or `mutable`, with the function that changes it.

    Returns the `ScaleTree` of nestedscales: `table` holds one row per part
    and `str()` draws the tree.
    """
    _check_geoscale(x)
    return scale_tree(x)
