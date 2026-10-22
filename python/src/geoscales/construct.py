"""Construction (ports of R/geoscale-construct.R and R/geoscale-build.R).

* `geoscale_from_leaftable()` -- the escape hatch: one row per atom;
* `geoscale_build(xwalk, ..., geoframes=)` -- from parent-child crosswalks;
* `geoscale_example()` -- a synthetic 7-atom scale.
"""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

import pyarrow as pa
import pyarrow.compute as pc
from nestedscales import backend_pull

from ._utils import _as_list, _preview, _stop, _warn
from .geoscale_class import RESERVED_COLS, GeoScale, _as_geometry


def _blank_to_na(col: Any) -> pa.ChunkedArray:
    col = pc.cast(col, pa.string())
    blank = pc.fill_null(pc.equal(pc.utf8_trim_whitespace(col), ""), False)
    return pc.if_else(blank, pa.scalar(None, pa.string()), col)


def _is_numeric(t: pa.Table, c: str) -> bool:
    ty = t.schema.field(c).type
    return pa.types.is_integer(ty) or pa.types.is_floating(ty)


def geoscale_from_leaftable(leaftable: Any, geoframes: Sequence[str] | str,
                            key: str | None = None,
                            weights: Sequence[str] | str | None = None,
                            default_weight: str | None = None,
                            members: Mapping[str, Sequence[str]] | None = None,
                            geometry: Any = None, name: str = "", desc: str = "",
                            row_order: str = "nested", **meta: Any) -> GeoScale:
    """A GeoScale from a table with one row per atom.

    Blank codes become null; `key` defaults to `region`, else the finest
    geoframe (copied into `region`); `weights` defaults to every numeric
    non-geoframe column; `members` to first-appearance order.
    """
    if "leaves" in meta or "levels" in meta:
        _stop("arguments `leaves`/`levels` were renamed `leaftable`/`geoframes` "
              "(2026-08 naming lattice); update the call")
    if isinstance(leaftable, (str, bytes, int, float)) or leaftable is None:
        _stop("`leaftable` must be a data.frame")
    lt = leaftable if isinstance(leaftable, pa.Table) else backend_pull(leaftable)
    geoframes = _as_list(geoframes)
    if not geoframes or not all(isinstance(g, str) for g in geoframes):
        _stop("`geoframes` must be a non-empty character vector")
    missing = [g for g in geoframes if g not in lt.column_names]
    if missing:
        _stop("`leaftable` is missing geoframe column(s): %s", _preview(missing))
    for g in geoframes:
        lt = lt.set_column(lt.column_names.index(g), g, _blank_to_na(lt[g]))
    if key is None:
        key = "region" if "region" in lt.column_names else geoframes[-1]
    if key not in lt.column_names:
        _stop('`key` column "%s" not found in `leaftable`', key)
    region = pc.cast(lt[key], pa.string())
    if "region" in lt.column_names:
        lt = lt.set_column(lt.column_names.index("region"), "region", region)
    else:
        lt = lt.append_column("region", region)
    if any(v is None or v == "" for v in lt["region"].to_pylist()):
        _stop('the atom key column "%s" has missing or empty values; every atom '
              "needs an identifier", key)
    if weights is None:
        skip = {*geoframes, *RESERVED_COLS, "region"}
        weights = [c for c in lt.column_names if c not in skip and _is_numeric(lt, c)]
    weights = _as_list(weights)
    bad = [w for w in weights if w not in lt.column_names]
    if bad:
        _stop("weight column(s) not found in `leaftable`: %s", _preview(bad))
    if default_weight is None and weights:
        default_weight = weights[0]
    if members is None:
        members = {g: [v for v in dict.fromkeys(lt[g].to_pylist()) if v is not None]
                   for g in geoframes}
    empty = [g for g in geoframes if not _as_list(members.get(g))]
    if empty:
        _stop("geoframe(s) with no codes at all: %s", _preview(empty))
    n = [len(_as_list(members[g])) for g in geoframes]
    inverted = [geoframes[i] for i in range(1, len(n)) if n[i] < n[i - 1]]
    if inverted:
        _warn("`geoframes` should be ordered coarsest first, but %s has fewer codes "
              "than the geoframe before it. Aggregation direction is taken from "
              "this order.", _preview(inverted))
    if _check_row_order(row_order) == "nested":
        ord_ = _nested_row_order(lt, geoframes, members)
        lt = lt.take(pa.array(ord_, pa.int64()))
        if geometry is not None:
            geo = _as_geometry(geometry)
            if len(geo) == len(ord_):
                geometry = geo[ord_]
    m = {"name": name, "desc": desc, "weights": weights,
         "default_weight": default_weight}
    m.update(meta)
    return GeoScale(leaftable=lt, geoframes=geoframes, members=dict(members),
                    geometry=geometry, meta=m)


def _nested_row_order(table: pa.Table, frames: Sequence[str],
                      members: Mapping[str, Sequence[str]]) -> list[int]:
    """Row order by each frame, coarsest first, in member order; unassigned
    (null) codes last, ties in their given order (R: `.nested_row_order()`)."""
    keys = []
    for f in frames:
        pos = {m: i for i, m in enumerate(members[f])}
        keys.append([pos.get(v) for v in table[f].to_pylist()])
    return sorted(range(table.num_rows), key=lambda r: tuple(
        (1, 0) if k[r] is None else (0, k[r]) for k in keys))


def _check_row_order(row_order: str) -> str:
    if row_order not in ("nested", "given"):
        _stop("`row_order` should be one of: nested, given")
    return row_order


def geoscale_example() -> GeoScale:
    """A synthetic 7-atom scale: code "N1" reused at two geoframes, zone ZB
    cross-cutting, and atom ROW unassigned at every coarser geoframe."""
    df = pa.table({
        "country": ["N", "N", "N", "N", "S", "S", None],
        "state": ["N1", "N1", "N2", "N2", "S1", "S1", None],
        "zone": ["N1", "N1", "ZB", "ZB", "ZB", "ZC", None],
        "atom": ["A1", "A2", "A3", "A4", "A5", "A6", "ROW"],
        "km2": [100.0, 200, 300, 400, 500, 600, 1000],
        "pop": [10.0, 90, 30, 70, 50, 50, 0]})
    return geoscale_from_leaftable(
        df, geoframes=["country", "state", "zone", "atom"], name="example",
        desc="Synthetic example: reused code, non-nesting geoframe pair, and an "
             "unassigned atom")


def _rows(t: pa.Table) -> list[dict]:
    return t.to_pylist()


def _merge(a: list[dict], b: list[dict], by: list[str], all_x: bool,
           all_y: bool) -> list[dict]:
    """R's merge(sort = FALSE): matched pairs in x order, then unmatched x
    rows, then unmatched y rows."""
    index: dict[tuple, list[int]] = {}
    for j, r in enumerate(b):
        index.setdefault(tuple(r.get(k) for k in by), []).append(j)
    out, used = [], set()
    unmatched_x = []
    for r in a:
        hits = index.get(tuple(r.get(k) for k in by), [])
        if not hits:
            if all_x:
                unmatched_x.append(dict(r))
            continue
        for j in hits:
            used.add(j)
            out.append({**r, **b[j]})
    out += unmatched_x
    if all_y:
        for j, r in enumerate(b):
            if j not in used:
                out.append(dict(r))
    return out


def geoscale_build(*xwalks: Any, geoframes: Sequence[str],
                   weights: Any = None, name: str = "", desc: str = "",
                   row_order: str = "nested") -> GeoScale:
    """A GeoScale assembled from two-column parent-child crosswalks."""
    if not xwalks:
        _stop("supply at least one crosswalk data.frame")
    tables = []
    for d in xwalks:
        if isinstance(d, (str, bytes, int, float)) or d is None:
            _stop("every `...` argument must be a data.frame")
        tables.append(d if isinstance(d, pa.Table) else backend_pull(d))
    geoframes = _as_list(geoframes)
    if not geoframes or not all(isinstance(g, str) for g in geoframes):
        _stop("`geoframes` must be a non-empty character vector")
    if not isinstance(name, str) or name == "":
        name = "_".join(geoframes)
    cleaned = []
    for t in tables:
        for c in t.column_names:
            t = t.set_column(t.column_names.index(c), c, _blank_to_na(t[c]))
        cleaned.append([dict(r) for r in dict.fromkeys(
            tuple(sorted(r.items())) for r in _rows(t))])
        cleaned[-1] = [dict(r) for r in cleaned[-1]]
    cols_of = [t.column_names for t in tables]
    unknown = [c for cols in cols_of for c in cols if c not in geoframes]
    if unknown:
        _stop("crosswalk column(s) not listed in `geoframes`: %s",
              _preview(list(dict.fromkeys(unknown))))
    atom = geoframes[-1]
    has_atom = [atom in cols for cols in cols_of]
    if not any(has_atom):
        _stop("no crosswalk mentions the atom geoframe `%s`", atom)
    seeds = [(c, cols) for c, cols, h in zip(cleaned, cols_of, has_atom, strict=True)
             if h]
    rows, cols = seeds[0][0], list(seeds[0][1])
    for r2, c2 in seeds[1:]:
        by = [c for c in cols if c in c2]
        rows = _merge(rows, r2, by, all_x=True, all_y=True)
        cols += [c for c in c2 if c not in cols]
    pending = [(c, cc) for c, cc, h in zip(cleaned, cols_of, has_atom, strict=True)
               if not h]
    while pending:
        shared = [any(c in cols for c in cc) for _, cc in pending]
        if not any(shared):
            stuck = list(dict.fromkeys(c for _, cc in pending for c in cc))
            _stop("cannot connect crosswalk(s) covering %s to the atom geoframe `%s`; "
                  "add a crosswalk sharing a geoframe with them",
                  _preview([c for c in stuck if c not in cols]), atom)
        i = shared.index(True)
        r2, c2 = pending.pop(i)
        rows = _merge(rows, r2, [c for c in c2 if c in cols], all_x=True,
                      all_y=False)
        cols += [c for c in c2 if c not in cols]
    missing = [g for g in geoframes if g not in cols]
    if missing:
        _stop("no crosswalk supplies geoframe(s): %s", _preview(missing))
    if weights is not None:
        wt = weights if isinstance(weights, pa.Table) else backend_pull(weights)
        if atom not in wt.column_names:
            _stop("`weights` must have a `%s` column (the atom geoframe)", atom)
        wt = wt.set_column(wt.column_names.index(atom), atom, _blank_to_na(wt[atom]))
        rows = _merge(rows, _rows(wt), [atom], all_x=True, all_y=False)
        cols += [c for c in wt.column_names if c not in cols]
    atoms = [r.get(atom) for r in rows]
    seen: set = set()
    dup = list(dict.fromkeys(a for a in atoms if a in seen or seen.add(a)))
    if dup:
        _stop("crosswalks produce %d duplicated atom(s) (%s); a geoframe assigns "
              "more than one code to the same atom", len(dup), _preview(dup))
    order = [*geoframes, *[c for c in cols if c not in geoframes]]
    types = {}
    if weights is not None:
        types = {c: wt.schema.field(c).type for c in wt.column_names if c != atom}
    table = pa.table({c: pa.array([r.get(c) for r in rows], types.get(c, pa.string()))
                      for c in order})
    return geoscale_from_leaftable(table, geoframes=geoframes, name=name, desc=desc,
                                   row_order=row_order)
