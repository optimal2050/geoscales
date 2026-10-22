"""GeoScale -- the spatial NestedScale (port of R/geoscale-class.R).

A nested spatial partition: a leaftable with one row per atom (a column per
geoframe, the unique `region` key, weight columns such as km2 or pop), the
geoframes coarsest first, their member codes, and an optional per-atom
geometry (shapely geometries in leaftable row order, R's `sfc`) with its
CRS in `meta$crs`.
"""
from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any

import numpy as np
import pyarrow as pa
from nestedscales import (
    NestedScale,
    backend_pull,
    empty_aliases,
    empty_attributes,
    scale_alias_property,
    scale_coverage,
    scale_nests,
    scale_payload_slice,
    scale_vocab,
)

from ._utils import _check_geoframe, _check_geoscale, _stop

#: Recommended geoframe vocabulary, not enforced.
CORE_GEOFRAMES = ("GLOBE", "CONTINENT", "COUNTRY", "STATE", "ZONE", "CELL")
RESERVED_COLS = ("region", "share", ".weight", ".order")


def is_valid_geoframe(x: object):
    from nestedscales import is_valid_frame

    return is_valid_frame(x)


def _as_geometry(geometry: Any) -> np.ndarray | None:
    if geometry is None:
        return None
    if hasattr(geometry, "values") and hasattr(geometry, "crs"):  # GeoSeries
        geometry = geometry.values
    return np.asarray(list(geometry), dtype=object)


class GeoScale(NestedScale):
    """A nested spatial partition; key column `region`."""

    _r_package = "geoscales"
    geoframes = scale_alias_property("frames")

    def __init__(self, leaftable: Any, geoframes: Sequence[str] | str,
                 members: Mapping[str, Sequence[str]], geometry: Any = None,
                 meta: Mapping | None = None) -> None:
        lt = leaftable if isinstance(leaftable, pa.Table) else backend_pull(leaftable)
        for k, v in (("leaftable", lt), ("frames", geoframes),
                     ("members", dict(members)), ("key", "region"),
                     ("meta", dict(meta or {})), ("attributes", empty_attributes()),
                     ("aliases", empty_aliases())):
            object.__setattr__(self, k, v)
        object.__setattr__(self, "geometry", _as_geometry(geometry))
        self._construct()

    def _errors(self) -> list[str]:
        if not hasattr(self, "geometry"):
            object.__setattr__(self, "geometry", None)
        return [*super()._errors(), *_validate_geoscale(self)]

    def __eq__(self, other: object) -> bool:
        base = super().__eq__(other)
        if base is not True:
            return base
        g1, g2 = self.geometry, other.geometry
        if g1 is None or g2 is None:
            return g1 is None and g2 is None
        return len(g1) == len(g2) and all(
            (a is None and b is None) or (a is not None and b is not None and
                                          a.equals_exact(b, 0))
            for a, b in zip(g1, g2, strict=True))

    __hash__ = None  # type: ignore[assignment]

    def __repr__(self) -> str:
        return "<GeoScale[%s] atoms=%d>" % ("/".join(self.frames),
                                            self.leaftable.num_rows)

    def __str__(self) -> str:
        return _format_geoscale(self)

    def __getitem__(self, idx: tuple) -> GeoScale:
        """`gs[geoframe, region]` is `filter_geoscale()`."""
        from .navigate import filter_geoscale

        if not isinstance(idx, tuple) or len(idx) != 2:
            _stop("subset a GeoScale as `gs[geoframe, region]`")
        return filter_geoscale(self, idx[0], idx[1])


@scale_vocab.register(GeoScale)
def _(x: GeoScale) -> dict[str, str]:
    return {"object": "GeoScale", "frame": "geoframe", "frames": "geoframes",
            "unit": "region", "units": "regions", "atoms": "geoatoms",
            "register_rule": "register_geoscale_rule()",
            "register_map": "register_geoscale_map_between()"}


@scale_payload_slice.register(GeoScale)
def _(x: GeoScale, i: Sequence[int]) -> GeoScale:
    # geometry is per atom, in leaftable row order: keep the same rows
    if x.geometry is not None:
        object.__setattr__(x, "geometry", x.geometry[np.asarray(list(i), dtype=int)])
    return x


def _validate_geoscale(self: GeoScale) -> list[str]:
    """R's GeoScale validator, which S7 runs after the NestedScale one (some
    checks repeat the parent's, and so do their messages)."""
    from nestedscales import is_valid_frame

    from ._utils import _preview

    errs: list[str] = []
    lt, gf, members, meta = self.leaftable, list(self.frames), self.members, self.meta
    cols = lt.column_names
    if lt.num_rows == 0:
        errs.append("`leaftable` must have at least one row")
    if "region" not in cols:
        errs.append("`leaftable` must have a `region` column (the atom key)")
    if not gf or not all(isinstance(g, str) for g in gf):
        errs.append("`geoframes` must be a non-empty character vector")
    elif len(set(gf)) != len(gf):
        errs.append("`geoframes` must be unique")
    else:
        bad = [g for g, ok in zip(gf, is_valid_frame(gf), strict=True) if not ok]
        if bad:
            errs.append("`geoframes` contains invalid names: %s" % _preview(bad))
        clash = [c for c in RESERVED_COLS if c != "region" and c in gf]
        if "region" in gf and gf[-1] != "region":
            clash.append("region")
        if clash:
            errs.append("`geoframes` may not use reserved names: %s" % _preview(clash))
        missing = [g for g in gf if g not in cols]
        if missing:
            errs.append("`leaftable` missing geoframe columns: %s" % _preview(missing))
    if "region" in cols:
        rid = lt["region"].to_pylist()
        if not pa.types.is_string(lt.schema.field("region").type) or any(
                r is None or r == "" for r in rid):
            errs.append("`leaftable$region` must be a non-empty character vector")
        elif len(set(rid)) != len(rid):
            seen: set = set()
            dup = list(dict.fromkeys(r for r in rid if r in seen or seen.add(r)))
            errs.append("`leaftable$region` must be unique; duplicated: %s. Parallel "
                        "dimensions (e.g. onshore/offshore) belong in separate "
                        "GeoScale objects." % _preview(dup))
    if not isinstance(members, Mapping):
        errs.append("`members` must be a list")
    elif not errs:
        missing = [g for g in gf if g not in members]
        if missing:
            errs.append("`members` missing entries for: %s" % _preview(missing))
        for g in [g for g in gf if g in members]:
            mb = members[g]
            if (len(mb) == 0 or not all(isinstance(m, str) and m != "" for m in mb)
                    or len(set(mb)) != len(mb)):
                errs.append('`members[["%s"]]` must be a unique non-empty character '
                            "vector" % g)
                continue
            seen_codes = {v for v in lt[g].cast(pa.string()).to_pylist()
                          if v is not None}
            if seen_codes != set(mb):
                errs.append('`members[["%s"]]` must contain exactly the non-NA values '
                            "present in `leaftable$%s`" % (g, g))
    wts = meta.get("weights")
    if wts is not None:
        for w in wts:
            if w not in cols:
                errs.append("weight column `%s` not found in `leaftable`" % w)
                continue
            ty = lt.schema.field(w).type
            if not (pa.types.is_integer(ty) or pa.types.is_floating(ty)):
                errs.append("weight column `%s` must be numeric" % w)
                continue
            v = [z for z in lt[w].to_pylist() if z is not None]
            if any(not math.isfinite(z) and not math.isnan(z) for z in v):
                errs.append("weight column `%s` must be finite" % w)
            elif any(z < 0 for z in v if not math.isnan(z)):
                errs.append("weight column `%s` must be >= 0" % w)
            elif sum(z for z in v if not math.isnan(z)) <= 0:
                errs.append("weight column `%s` sums to zero" % w)
        dw = meta.get("default_weight")
        if dw is not None and dw not in wts:
            errs.append("`meta$default_weight` must be one of `meta$weights`")
    g = self.geometry
    if g is not None and len(g) != lt.num_rows:
        errs.append("`geometry` has %d element(s) but `leaftable` has %d row(s)"
                    % (len(g), lt.num_rows))
    cov = meta.get("coverage")
    if cov is not None:
        wts = meta.get("weights") or ()
        if not isinstance(cov, Mapping) or not all(k in wts for k in cov):
            errs.append("`meta$coverage` must be a named numeric over declared "
                        "weights")
        elif any(not math.isfinite(v) or v <= 0 or v > 1 for v in cov.values()):
            errs.append("`meta$coverage` values must lie in (0, 1]")
        elif meta.get("parent_totals") is not None:
            pt = meta["parent_totals"]
            for w in [k for k in cov if k in pt]:
                got = sum(z for z in lt[w].to_pylist()
                          if z is not None and not math.isnan(z)) / pt[w]
                if abs(got - cov[w]) > 1e-8:
                    errs.append('`meta$coverage["%s"]` (%.6g) does not match the '
                                "leaftable (%.6g)" % (w, cov[w], got))
        pn = meta.get("parent_name")
        if pn is not None and not (isinstance(pn, str) and pn != ""):
            errs.append("`meta$parent_name` must be a single non-empty string")
    return errs


# Accessors --------------------------------------------------------------------

def geoscale_rank(x: GeoScale, geoframe: str | Sequence[str]):
    """Position of a geoframe (1 = coarsest); None when not a geoframe."""
    _check_geoscale(x)
    lv = list(x.frames)

    def one(f: str) -> int | None:
        return lv.index(f) + 1 if f in lv else None

    return one(geoframe) if isinstance(geoframe, str) else [one(f) for f in geoframe]


def geoscale_geoframes(x: GeoScale, finest: bool = False):
    _check_geoscale(x)
    return x.frames[-1] if finest else list(x.frames)


def geoscale_leaftable(x: GeoScale) -> pa.Table:
    _check_geoscale(x)
    return x.leaftable


def geoscale_weights(x: GeoScale) -> list[str]:
    _check_geoscale(x)
    return list(x.meta.get("weights") or ())


def geoscale_regions(x: GeoScale, geoframe: str | None = None) -> list[str]:
    """The ordered codes at a geoframe (default: the atoms)."""
    _check_geoscale(x)
    if geoframe is None:
        geoframe = x.frames[-1]
    _check_geoframe(x, geoframe)
    return list(x.members[geoframe])


def geoscale_coverage(x: GeoScale, weight: str | None = None):
    _check_geoscale(x)
    return scale_coverage(x, weight)


# Print / summary -------------------------------------------------------------

def _format_geoscale(x: GeoScale) -> str:
    meta, lv, lt = x.meta, x.frames, x.leaftable
    out = ["GeoScale: %s " % (meta.get("name") or "<unnamed>")]
    if meta.get("desc"):
        out.append("Description: %s " % meta["desc"])
    out.append("Geoframes (%d, coarsest first):" % len(lv))
    for i, f in enumerate(lv):
        n_na = lt[f].null_count
        out.append("  %s- %s (%d)%s" % ("  " * i, f, len(x.members[f]),
                                        "  [%d atom(s) unassigned]" % n_na
                                        if n_na else ""))
    out.append("Atoms: %d" % lt.num_rows)
    wts = geoscale_weights(x)
    if wts:
        out.append("Weights: %s (default: %s)" % (", ".join(wts),
                                                  meta.get("default_weight")
                                                  or wts[0]))
    if meta.get("source") is not None:
        out.append("Source: %s" % meta["source"])
    if meta.get("crs") is not None:
        out.append("CRS: %s" % meta["crs"])
    if x.geometry is not None:
        out.append("Geometry: attached (%d features)" % len(x.geometry))
    return "\n".join(out)


@dataclass(frozen=True)
class GeoScaleSummary:
    """The quantitative view (R: `summary()` -> summary_GeoScale)."""

    name: str
    desc: str
    geoframes: dict[str, int]
    unassigned: dict[str, int]
    n_atoms: int
    weights: list[str]
    weight_totals: dict[str, float]
    default_weight: str | None
    coverage: dict[str, float]
    sampled: bool
    parent_name: str | None
    nesting: list[dict] | None
    geometry: dict
    source: str | None

    def __str__(self) -> str:
        # R's cat() separates its arguments by a space, also before ">"
        out = ["<summary of GeoScale%s >" % (" '%s'" % self.name if self.name
                                         else "")]
        if self.desc:
            out.append("  desc:          %s" % self.desc)
        out.append("  geoframes:      " + " / ".join(
            "%s (%d)" % kv for kv in self.geoframes.items()))
        out.append("  atoms:          %d" % self.n_atoms)
        ua = {k: n for k, n in self.unassigned.items() if n}
        if ua:
            out.append("  unassigned:     " + ", ".join("%s (%d)" % kv
                                                        for kv in ua.items()))
        if self.weights:
            out.append("  weight totals:  " + ", ".join(
                "%s = %s" % (k, f"{t:,.6g}") for k, t in self.weight_totals.items()))
        if self.sampled:
            out.append("  SAMPLED:        " + ", ".join(
                "%s %.1f%%" % (k, 100 * c) for k, c in self.coverage.items())
                + (" of '%s'" % self.parent_name if self.parent_name else ""))
        for r in self.nesting or []:
            out.append("  nesting:        %s > %s: %s" % (
                r["parent"], r["child"], "nested" if r["nests"] else
                "CROSS-CUTTING (%d offender(s))" % r["n_offenders"]))
        g = self.geometry
        out.append("  geometry:       %s" % (
            "%d feature(s)%s" % (g["n_features"], ", %s" % g["crs"] if g["crs"] else "")
            if g["attached"] else "none"))
        if self.source is not None:
            out.append("  source:         %s" % self.source)
        return "\n".join(out)


def geoscale_summary(x: GeoScale) -> GeoScaleSummary:
    _check_geoscale(x)
    meta, lt, gf = x.meta, x.leaftable, list(x.frames)
    wts = geoscale_weights(x)
    cov = geoscale_coverage(x)
    nesting = None
    if len(gf) > 1:
        nesting = []
        for a, b in zip(gf[:-1], gf[1:], strict=True):
            ok = scale_nests(x, a, b)
            nesting.append({"parent": a, "child": b, "nests": ok.ok,
                            "n_offenders": len(ok.offenders)})

    def tot(w: str) -> float:
        return float(sum(z for z in lt[w].to_pylist()
                         if z is not None and not math.isnan(z)))

    return GeoScaleSummary(
        name=meta.get("name") or "", desc=meta.get("desc") or "",
        geoframes={f: len(x.members[f]) for f in gf},
        unassigned={f: lt[f].null_count for f in gf}, n_atoms=lt.num_rows,
        weights=wts, weight_totals={w: tot(w) for w in wts},
        default_weight=meta.get("default_weight"), coverage=cov,
        sampled=any(c < 1 for c in cov.values()),
        parent_name=meta.get("parent_name"), nesting=nesting,
        geometry={"attached": x.geometry is not None,
                  "n_features": 0 if x.geometry is None else len(x.geometry),
                  "crs": meta.get("crs")},
        source=meta.get("source"))
