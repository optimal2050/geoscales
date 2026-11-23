"""GeoScale -- the spatial NestedScale (port of R/geoscale-class.R).

A nested spatial partition: a leaftable with one row per leaf region (a
column per geoframe and weight columns such as km2 or pop), the geoframes
coarsest first, their member codes, a table of labels, the geoframes hidden
from plots, and an optional geometry per leaf (shapely geometries in
leaftable row order, R's `sfc`) with its CRS in `meta["crs"]`.

The leaf column is the finest geoframe's own column unless `leaf` names
another column. A member of a geoframe is a region; "unit" means a unit of
measure only.
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
    scale_alias_property,
    scale_coverage,
    scale_leaf_column,
    scale_nests,
    scale_payload_parts,
    scale_payload_slice,
    scale_set_props,
    scale_validate,
    scale_vocab,
)

from ._utils import _as_list, _check_geoframe, _check_geoscale, _preview, _stop

#: Recommended geoframe vocabulary, not enforced.
CORE_GEOFRAMES = ("GLOBE", "CONTINENT", "COUNTRY", "STATE", "ZONE", "CELL")
RESERVED_COLS = ("share", ".weight", ".order")


def is_valid_geoframe(x: object):
    from nestedscales import is_valid_frame

    return is_valid_frame(x)


def _as_geometry(geometry: Any) -> np.ndarray | None:
    if geometry is None:
        return None
    if hasattr(geometry, "values") and hasattr(geometry, "crs"):  # GeoSeries
        geometry = geometry.values
    out = np.empty(len(geometry), dtype=object)
    for i, g in enumerate(geometry):
        out[i] = g
    return out


def _as_hidden(hidden: Any) -> tuple[str, ...]:
    """`hidden` as given to a constructor: unique geoframe names."""
    if hidden is None:
        return ()
    hidden = _as_list(hidden)
    if not all(isinstance(h, str) for h in hidden):
        _stop("`hidden` must be a character vector of geoframe names")
    return tuple(dict.fromkeys(hidden))


def _hidden(x: GeoScale) -> list[str]:
    """The hidden geoframes in the object's own order, coarsest first."""
    h = list(x.hidden or ())
    lv = list(x.frames)
    return [f for f in lv if f in h] + [f for f in h if f not in lv]


def _trim_hidden(hidden: Sequence[str], geoframes: Sequence[str]) -> tuple[str, ...]:
    """The hidden geoframes that remain; none when they would cover every
    geoframe."""
    h = tuple(f for f in hidden if f in geoframes)
    if geoframes and all(g in h for g in geoframes):
        return ()
    return h


def _check_hidden(hidden: Any, geoframes: Sequence[str]) -> list[str]:
    if not isinstance(hidden, (list, tuple)) or not all(
            isinstance(h, str) for h in hidden):
        return ["`hidden` must be a character vector of geoframe names"]
    errs = []
    bad = [h for h in dict.fromkeys(hidden) if h not in geoframes]
    if bad:
        errs.append("`hidden` names geoframe(s) not in the object: %s"
                    % ", ".join(bad))
    if len(set(hidden)) != len(hidden):
        errs.append("`hidden` repeats a geoframe")
    if geoframes and all(g in hidden for g in geoframes):
        errs.append("`hidden` may not cover every geoframe")
    return errs


@dataclass(init=False, frozen=True, eq=False, repr=False)
class GeoScale(NestedScale):
    """A nested spatial partition: a table of weighted leaf regions plus the
    geoframes that group them.

    Built with `geoscale_from_leaftable()`, `geoscale_build()` or
    `geoscale_from_provider()`. `leaf` names the leaf column; None is the
    finest geoframe. `labels` is the table `attach_labels_geoscale()` takes
    and `hidden` the geoframes left out of plots.
    """

    geometry: Any = None
    hidden: tuple[str, ...] = ()

    _r_package = "geoscales"
    geoframes = scale_alias_property("frames")

    def __init__(self, leaftable: Any, geoframes: Sequence[str] | str,
                 members: Mapping[str, Sequence[str]], geometry: Any = None,
                 meta: Mapping | None = None, leaf: str | None = None,
                 labels: Any = None, hidden: Sequence[str] | None = None, *,
                 attributes: Any = None, aliases: Any = None) -> None:
        lt = leaftable if isinstance(leaftable, pa.Table) else backend_pull(leaftable)
        gf = (geoframes,) if isinstance(geoframes, str) else tuple(geoframes)
        if leaf is None:
            leaf = gf[-1] if gf else "leaf"
        for k, v in (("leaftable", lt), ("frames", gf),
                     ("members", dict(members) if isinstance(members, Mapping)
                      else members),
                     ("leaf", leaf), ("meta", dict(meta or {})),
                     ("attributes", attributes), ("aliases", aliases),
                     ("labels", None), ("geometry", _as_geometry(geometry)),
                     ("hidden", (hidden,) if isinstance(hidden, str)
                      else tuple(hidden or ()))):
            object.__setattr__(self, k, v)
        # the core object is built without the labels, as in R: a table that
        # fails is then reported for the GeoScale, by both validators
        self._construct()
        if labels is not None:
            object.__setattr__(self, "labels", labels)
            scale_validate(self)

    def _errors(self) -> list[str]:
        return [*super()._errors(), *_validate_geoscale(self)]

    def __eq__(self, other: object) -> bool:
        base = super().__eq__(other)
        if base is not True:
            return base
        if _hidden(self) != _hidden(other):
            return False
        g1, g2 = self.geometry, other.geometry
        if g1 is None or g2 is None:
            return g1 is None and g2 is None
        return len(g1) == len(g2) and all(
            (a is None and b is None) or (a is not None and b is not None and
                                          a.equals_exact(b, 0))
            for a, b in zip(g1, g2, strict=True))

    __hash__ = None  # type: ignore[assignment]

    def __repr__(self) -> str:
        return "<GeoScale[%s] leaves=%d>" % ("/".join(self.frames),
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
            "member": "region", "members": "regions", "leaves": "geoleaves",
            "register_rule": "register_geoscale_rule()",
            "register_map": "register_geoscale_map_between()"}


@scale_payload_slice.register(GeoScale)
def _(x: GeoScale, i: Sequence[int]) -> GeoScale:
    # geometry is per leaf, in leaftable row order: the same rows are kept;
    # the hidden geoframes are cut to those that remain
    props: dict[str, Any] = {"hidden": _trim_hidden(_hidden(x), x.frames)}
    if x.geometry is not None:
        props["geometry"] = x.geometry[np.asarray(list(i), dtype=int)]
    return scale_set_props(x, **props)


def _geometry_shape(geometry: Any) -> str:
    """The size of the geometry as R spells an `sfc`: one geometry type gives
    `sfc_<TYPE>`, a mixture or an empty shape `sfc_GEOMETRY`."""
    if geometry is None:
        return "NULL"
    kinds = {None if g is None else g.geom_type.upper() for g in geometry}
    kind = kinds.pop() if len(kinds) == 1 else None
    return "sfc_%s [%d]" % (kind or "GEOMETRY", len(geometry))


@scale_payload_parts.register(GeoScale)
def _(x: GeoScale) -> list[dict]:
    lt = x.leaftable
    weights = [w for w in (x.meta.get("weights") or ()) if w in lt.column_names]
    rows: list[dict] = [
        {"part": "labels", "parent": "", "verb": "attach_labels_geoscale()"},
        {"part": "geometry", "parent": "", "mark": "mutable",
         "shape": _geometry_shape(x.geometry),
         "verb": "attach_geometry_geoscale()",
         "note": "one shape per row of the leaftable"},
        {"part": "hidden", "parent": "", "mark": "mutable",
         "verb": "hide_geoframes_geoscale()",
         "note": "geoframes left out of plots"}]
    rows += [{"part": w, "parent": "leaftable", "mark": "mutable",
              "verb": "geoscale_add_weight()"} for w in weights]
    return rows


def _validate_geoscale(self: GeoScale) -> list[str]:
    """R's GeoScale validator, which S7 runs after the NestedScale one (some
    checks repeat the parent's, and so do their messages)."""
    from nestedscales import is_valid_frame

    from .labels import _check_labels_table

    errs: list[str] = []
    lt, gf, members, meta = self.leaftable, list(self.frames), self.members, self.meta
    leaf = self.leaf
    if not isinstance(lt, pa.Table):
        return ["`leaftable` must be a data.frame"]
    cols = lt.column_names
    if lt.num_rows == 0:
        errs.append("`leaftable` must have at least one row")
    if leaf not in cols:
        errs.append("`leaftable` must have a `%s` column (the leaf column)" % leaf)
    if not gf or not all(isinstance(g, str) for g in gf):
        errs.append("`geoframes` must be a non-empty character vector")
    elif len(set(gf)) != len(gf):
        errs.append("`geoframes` must be unique")
    else:
        bad = [g for g, ok in zip(gf, is_valid_frame(gf), strict=True) if not ok]
        if bad:
            errs.append("`geoframes` contains invalid names: %s" % _preview(bad))
        # the leaf column is normally the finest geoframe's own column; a
        # coarser geoframe could not be unique per leaf
        clash = [g for g in gf if g in RESERVED_COLS]
        if leaf in gf and gf[-1] != leaf:
            clash.append(leaf)
        if clash:
            errs.append("`geoframes` may not use reserved names: %s" % _preview(clash))
        missing = [g for g in gf if g not in cols]
        if missing:
            errs.append("`leaftable` missing geoframe columns: %s" % _preview(missing))
    if leaf in cols:
        rid = lt[leaf].to_pylist()
        if not pa.types.is_string(lt.schema.field(leaf).type) or any(
                r is None or r == "" for r in rid):
            errs.append("`leaftable$%s` must be a non-empty character vector" % leaf)
        elif len(set(rid)) != len(rid):
            seen: set = set()
            dup = list(dict.fromkeys(r for r in rid if r in seen or seen.add(r)))
            errs.append("`leaftable$%s` must be unique; duplicated: %s. Parallel "
                        "dimensions (e.g. onshore/offshore) belong in separate "
                        "GeoScale objects." % (leaf, _preview(dup)))
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
    wts = meta.get("weights") if isinstance(meta, Mapping) else None
    if wts is not None:
        if not all(isinstance(w, str) for w in wts):
            errs.append("`meta$weights` must be a character vector")
        else:
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
    if not errs and isinstance(members, Mapping):
        errs += _check_labels_table(self.labels, gf, members)
    hidden = self.hidden
    if hidden is not None and len(hidden) > 0:
        errs += _check_hidden(hidden, gf)
    g = self.geometry
    if g is not None and len(g) != lt.num_rows:
        errs.append("`geometry` has %d element(s) but `leaftable` has %d row(s)"
                    % (len(g), lt.num_rows))
    if not isinstance(meta, Mapping):
        errs.append("`meta` must be a list")
        return errs
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


def geoscale_geoframes(x: GeoScale, finest: bool = False,
                       visible: bool | None = None):
    """The geoframe names, coarsest first; only the finest when `finest`.

    `visible=None` gives every geoframe, `True` those shown in plots and
    `False` those hidden from them (see `hide_geoframes_geoscale()`).
    """
    _check_geoscale(x)
    lv = list(x.frames)
    if visible is not None:
        hid = set(_hidden(x))
        lv = [f for f in lv if (f not in hid) == bool(visible)]
    if finest:
        return lv[-1] if lv else None
    return lv


def geoscale_leaftable(x: GeoScale) -> pa.Table:
    """The one-row-per-leaf table the GeoScale is built on."""
    _check_geoscale(x)
    return x.leaftable


def geoscale_weights(x: GeoScale) -> list[str]:
    _check_geoscale(x)
    return list(x.meta.get("weights") or ())


def geoscale_regions(x: GeoScale, geoframe: str | None = None) -> list[str]:
    """The ordered codes at a geoframe (default: the finest geoframe)."""
    _check_geoscale(x)
    if geoframe is None:
        geoframe = x.frames[-1]
    _check_geoframe(x, geoframe)
    return list(x.members[geoframe])


def geoscale_coverage(x: GeoScale, weight: str | None = None):
    _check_geoscale(x)
    return scale_coverage(x, weight)


def geoscale_add_weight(x: GeoScale, *args: Any, default: str | None = None,
                        overwrite: bool = False, **weights: Any) -> GeoScale:
    """Declare one or more numeric weights over the leaves of a GeoScale.

    Each keyword is a weight: a mapping from leaf code to value, a sequence
    in leaftable row order, or one number for every leaf. A single table
    keyed by the leaf column, with one or more numeric columns, may be given
    instead. `default` names the weight to make the default; `overwrite`
    allows replacing a weight that is already declared.
    """
    _check_geoscale(x)
    lt = x.leaftable
    lcol = scale_leaf_column(x)
    leaves = lt[lcol].to_pylist()
    named: dict[str, Any] = dict(weights)
    if len(args) == 1 and not named and not isinstance(
            args[0], (int, float, str, list, tuple)) and args[0] is not None:
        df = backend_pull(args[0])
        if lcol not in df.column_names:
            _stop("the `data.frame` must carry the leaf column `%s`", lcol)
        num = [c for c in df.column_names
               if pa.types.is_integer(df.schema.field(c).type)
               or pa.types.is_floating(df.schema.field(c).type)]
        if not num:
            _stop("the `data.frame` has no numeric weight column")
        codes = [None if c is None else str(c) for c in df[lcol].to_pylist()]
        named = {c: dict(zip(codes, df[c].to_pylist(), strict=True)) for c in num}
    elif args:
        _stop("every weight must be named: geoscale_add_weight(x, population = )")
    if not named:
        _stop("no weight given")
    have = geoscale_weights(x)
    clash = [w for w in named if w in have]
    if clash and not overwrite:
        _stop("weight(s) already declared: %s. Pass `overwrite = TRUE` to replace "
              "them", ", ".join(clash))
    reserved = [c for c in lt.column_names if c not in have and c != "geometry"]
    bad = [w for w in named if w in reserved]
    if bad:
        _stop("`%s` is a column of the leaftable already and is not a weight", bad[0])
    for w, v in named.items():
        if isinstance(v, Mapping):
            miss = [c for c in leaves if c not in v]
            if miss:
                _stop("weight `%s` has no value for %d leaf code(s): %s", w,
                      len(miss), _preview(miss))
            v = [v[c] for c in leaves]
        elif isinstance(v, (int, float)) and not isinstance(v, bool):
            v = [v] * len(leaves)
        else:
            v = _as_list(v)
            if len(v) == 1:
                v = v * len(leaves)
            elif len(v) != len(leaves):
                _stop("weight `%s` has %d values for %d leaves; name it by leaf code "
                      "or give one value per leaftable row", w, len(v), len(leaves))
        if not all(z is None or (isinstance(z, (int, float))
                                 and not isinstance(z, bool)) for z in v):
            _stop("weight `%s` must be numeric", w)
        v = [None if z is None else float(z) for z in v]
        ok = [z for z in v if z is not None and not math.isnan(z)]
        # checked here so that the message names the weight
        if any(not math.isfinite(z) for z in ok):
            _stop("weight `%s` must be finite", w)
        if any(z < 0 for z in ok):
            _stop("weight `%s` must be >= 0", w)
        if not sum(ok) > 0:
            _stop("weight `%s` sums to zero", w)
        col = pa.array(v, pa.float64())
        lt = (lt.set_column(lt.column_names.index(w), w, col)
              if w in lt.column_names else lt.append_column(w, col))
    meta = dict(x.meta)
    meta["weights"] = list(dict.fromkeys([*have, *named]))
    if default is not None:
        if not isinstance(default, str) or default not in meta["weights"]:
            _stop("`default` must be one of the declared weights: %s",
                  ", ".join(meta["weights"]))
        meta["default_weight"] = default
    return scale_set_props(x, check=True, leaftable=lt, meta=meta)


# Print / summary -------------------------------------------------------------

def _format_geoscale(x: GeoScale) -> str:
    from .labels import _default_variant

    meta, lv, lt = x.meta, x.frames, x.leaftable
    out = ["GeoScale: %s " % (meta.get("name") or "<unnamed>")]
    if meta.get("desc"):
        out.append("Description: %s " % meta["desc"])
    out.append("Geoframes (%d, coarsest first):" % len(lv))
    for i, f in enumerate(lv):
        n_na = lt[f].null_count
        out.append("  %s- %s (%d)%s" % ("  " * i, f, len(x.members[f]),
                                        "  [%d leaf region(s) unassigned]" % n_na
                                        if n_na else ""))
    out.append("Leaves: %d%s" % (lt.num_rows, "" if x.leaf == lv[-1] else
                                 " (leaf column: %s)" % x.leaf))
    wts = geoscale_weights(x)
    if wts:
        out.append("Weights: %s (default: %s)" % (", ".join(wts),
                                                  meta.get("default_weight")
                                                  or wts[0]))
    lb = x.labels
    if lb.num_rows > 0:
        per: dict[str, list] = {}
        for f, va in zip(lb["frame"].to_pylist(), lb["variant"].to_pylist(),
                         strict=True):
            per.setdefault(f, [])
            if va not in per[f]:
                per[f].append(va)
        out.append("Labels: %s (default: %s)" % (
            ", ".join("%s [%s]" % (f, ", ".join(vs)) for f, vs in per.items()),
            _default_variant(x)))
    hid = _hidden(x)
    if hid:
        out.append("Hidden in plots: %s" % ", ".join(hid))
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
    n_leaves: int
    hidden: list[str]
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
        out.append("  leaves:         %d" % self.n_leaves)
        ua = {k: n for k, n in self.unassigned.items() if n}
        if ua:
            out.append("  unassigned:     " + ", ".join("%s (%d)" % kv
                                                        for kv in ua.items()))
        if self.weights:
            # R formats the totals as one vector: right-justified to a
            # common width
            tot = {k: f"{t:,.6g}" for k, t in self.weight_totals.items()}
            width = max(len(z) for z in tot.values())
            out.append("  weight totals:  " + ", ".join(
                "%s = %s" % (k, z.rjust(width)) for k, z in tot.items())
                + ("  (default: %s)" % self.default_weight
                   if self.default_weight else ""))
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
            "attached (%d features%s)" % (g["n_features"],
                                         ", %s" % g["crs"] if g["crs"] else "")
            if g["attached"] else "none"))
        if self.source is not None:
            out.append("  source:         %s" % self.source)
        return "\n".join(out)


def geoscale_summary(x: GeoScale) -> GeoScaleSummary:
    """Per-weight totals and coverage, the nesting of adjacent geoframes and
    the state of the geometry (R: `summary()`)."""
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
        unassigned={f: lt[f].null_count for f in gf}, n_leaves=lt.num_rows,
        hidden=_hidden(x), weights=wts, weight_totals={w: tot(w) for w in wts},
        default_weight=meta.get("default_weight"), coverage=cov,
        sampled=any(c < 1 for c in cov.values()),
        parent_name=meta.get("parent_name"), nesting=nesting,
        geometry={"attached": x.geometry is not None,
                  "n_features": 0 if x.geometry is None else len(x.geometry),
                  "crs": meta.get("crs")},
        source=meta.get("source"))
