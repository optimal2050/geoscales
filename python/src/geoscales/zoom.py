"""zoom_geoscale() -- a telescoping cut (port of R/zoom.R)."""
from __future__ import annotations

from collections.abc import Sequence

import pyarrow as pa

from ._utils import _as_list, _preview, _stop
from .construct import geoscale_from_leaftable
from .geoscale_class import GeoScale
from .navigate import geoscale_nests


def zoom_geoscale(x: GeoScale, focus: str | Sequence[str],
                  geoframes: Sequence[str] | None = None, name: str = "zoom",
                  label_rest: str = "%s_rest") -> GeoScale:
    """Keep the `focus` atoms individual and group every other atom into the
    finest ring (geoframe code) it shares with a focus atom; the rest fall
    back to the coarsest of `geoframes`. Geoframes of the result: the
    coarsest, `name`, the atoms."""
    if not isinstance(x, GeoScale):
        _stop("`x` must be a GeoScale")
    frames = list(x.frames)
    atom_frame = frames[-1]
    geoframes = [f for f in frames if f != atom_frame] if geoframes is None \
        else _as_list(geoframes)
    if not geoframes:
        _stop("`geoframes` must name at least one geoframe")
    unknown = [g for g in geoframes if g not in frames]
    if unknown:
        _stop("unknown geoframe(s) in `geoframes`: %s; available: %s",
              _preview(unknown), ", ".join(frames))
    if atom_frame in geoframes:
        _stop("`geoframes` must not include the atom geoframe `%s`", atom_frame)
    if name in frames:
        _stop("`name` = `%s` is already a geoframe of `x`", name)
    lt = x.leaftable
    atoms = lt["region"].to_pylist()
    focus = list(dict.fromkeys(_as_list(focus)))
    if not focus:
        _stop("`focus` is empty; a zoom with no focus area is `prune_geoscale()`")
    have = set(atoms)
    gone = [f for f in focus if f not in have]
    if gone:
        _stop("`focus` names atoms (geoframe `%s`), not coarser regions; not found: "
              "%s", atom_frame, _preview(gone))
    fset = set(focus)
    is_focus = [a in fset for a in atoms]
    cut = [a if f else None for a, f in zip(atoms, is_focus, strict=True)]
    for lvl in reversed(geoframes):
        codes = lt[lvl].to_pylist()
        touched = {c for c, f in zip(codes, is_focus, strict=True)
                   if f and c is not None}
        for i, c in enumerate(codes):
            if cut[i] is None and c is not None and c in touched:
                cut[i] = label_rest % c
    coarsest = lt[geoframes[0]].to_pylist()
    cut = [c if c is not None else k for c, k in zip(cut, coarsest, strict=True)]
    carried = [c for c in lt.column_names if c not in frames]
    cols = {c: lt[c] for c in carried}
    cols[geoframes[0]] = lt[geoframes[0]]
    cols[name] = pa.array(cut, pa.string())
    cols[atom_frame] = lt[atom_frame]
    meta = x.meta
    nm = meta.get("name") or ""
    out = geoscale_from_leaftable(
        pa.table(cols), geoframes=[geoframes[0], name, atom_frame], key="region",
        weights=meta.get("weights"), default_weight=meta.get("default_weight"),
        geometry=x.geometry, name="%s@%s" % (nm, name) if nm else name,
        desc="telescoping zoom on %d atom(s) of %s" % (len(focus),
                                                        nm or "a geoscale"),
        crs=meta.get("crs"), source=meta.get("source"),
        zoom={"focus": focus, "geoframes": geoframes, "parent_name": meta.get("name")})
    for a, b in ((geoframes[0], name), (name, atom_frame)):
        ok = geoscale_nests(out, a, b)
        if not ok:
            _stop("the zoom does not nest: `%s` -> `%s` has %d code(s) with more than "
                  "one parent (e.g. %s). Please report this.", b, a,
                  len(ok.offenders), _preview(ok.offenders))
    return out
