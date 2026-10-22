"""recast_geoscale() and the geoatom halves (port of R/recast.R and
R/recast-pairs.R).

`recast_geoscale()` is nestedscales' `recast_scale()` on a GeoScale. The
halves are kept local, as in R: `recast_from_geoatoms()` returns the
OBSERVED target regions only (no completion to the full vocabulary), unlike
nestedscales' `recast_from_atoms()`.
"""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any, Literal

import nestedscales as ns
import numpy as np
import pyarrow as pa
import pyarrow.compute as pc
from nestedscales.recast import _group_parts, _group_result

from ._utils import (
    _as_list,
    _check_geoframe,
    _check_geoscale,
    _map_weight,
    _preview,
    _stop,
    _warn,
)
from .geoscale_class import GeoScale, geoscale_rank
from .rules import GEOSCALE_RULES, _match_arg, get_geoscale_rule

NaAction = Literal["drop", "error", "keep"]
_GS_COLS = (".gs_parent", ".gs_tot", ".gs_to", ".gs_f", ".gs_n_from",
            ".gs_n_overlap", ".gs_w", ".gs_w_from")
_KEEP_NULLS = pc.ScalarAggregateOptions(skip_nulls=False, min_count=0)


def _check_gs_cols(schema: pa.Schema) -> None:
    clash = [c for c in schema.names if c in _GS_COLS or c.startswith("__gs_")]
    if clash:
        _stop("`x` uses reserved column name(s): %s", _preview(clash))


def _rules_for(values: Sequence[str], rule: Any, weight: Any) -> dict[str, dict]:
    def pick(spec: Any, v: str, arg: str) -> Any:
        if spec is None:
            return None
        if isinstance(spec, Mapping):
            return spec.get(v)
        if isinstance(spec, str):
            return spec
        spec = list(spec)
        if len(spec) != 1:
            _stop("`%s` must be one value or a NAMED vector, one per column", arg)
        return spec[0]

    out = {}
    for v in values:
        r, w = pick(rule, v, "rule"), pick(weight, v, "weight")
        if r is not None:
            out[v] = {"rule": _match_arg(r, GEOSCALE_RULES, "rule"), "weight": w}
            continue
        reg = get_geoscale_rule(v)
        if reg is None:
            _stop('no aggregation rule for value column `%s`; pass `rule=` or '
                  'register one with register_geoscale_rule("%s", ...)', v, v)
        out[v] = {"rule": reg["rule"], "weight": w or reg["weight"]}
    return out


def _values_for(schema: pa.Schema, key: str, drop: Sequence[str],
                values: Any) -> list[str]:
    if values is None:
        out = [c for c in schema.names if c != key and c not in drop and (
            pa.types.is_integer(schema.field(c).type)
            or pa.types.is_floating(schema.field(c).type))]
        if not out:
            _stop("no numeric value columns found in `x`; specify `values=`")
        return out
    values = _as_list(values)
    miss = [v for v in values if v not in schema.names]
    if miss:
        _stop("value column(s) not in `x`: %s", _preview(miss))
    return values


def _no_share(rules: Mapping[str, dict], where: str) -> None:
    if any(r["rule"] in ("share", "logshare") for r in rules.values()):
        _stop('rule "share" is not supported by %s(); use recast_geoscale() with a '
              "parent geoframe", where)


def _infer_from(gs: GeoScale, schema: pa.Schema, key: str | None) -> str:
    gf = list(gs.frames)
    if key is not None and key in gf:
        return key
    hit = [g for g in gf if g in schema.names]
    if len(hit) != 1:
        _stop("cannot infer the source geoframe from `x`'s columns (found: %s); "
              "pass `from=`", "none" if not hit else _preview(hit))
    return hit[0]


def _as_str(t: pa.Table, c: str) -> pa.Table:
    if not pa.types.is_string(t.schema.field(c).type):
        t = t.set_column(t.column_names.index(c), c, pc.cast(t[c], pa.string()))
    return t


def recast_geoscale(x: Any, gs: GeoScale, source: str | None = None,
                    target: str | GeoScale | None = None, key: str | None = None,
                    values: Any = None, rule: Any = None, weight: Any = None,
                    na_action: NaAction = "drop", parent: str | None = None,
                    collect: bool | None = None) -> Any:
    """Recast region data between geoframes (or onto another GeoScale's atoms,
    matched on shared `region` keys)."""
    na_action = _match_arg(na_action, ("drop", "error", "keep"), "na_action")
    _check_geoscale(gs, "gs")
    if isinstance(target, GeoScale):
        rv = list(rule.values()) if isinstance(rule, Mapping) else _as_list(rule)
        if any(r in ("share", "logshare") for r in rv):
            _stop('rule "share" needs a parent geoframe of the same GeoScale; it '
                  "cannot recast across objects")
        g = recast_to_geoatoms(x, gs, source=source, key=key, values=values,
                               rule=rule, weight=weight, collect=collect)
        return recast_from_geoatoms(g, target, target=target.frames[-1],
                                    values=values, rule=rule, na_action=na_action,
                                    collect=collect)
    return ns.recast_scale(x, gs, source=source, target=target, key=key,
                           values=values, rule=rule, weight=weight,
                           na_action=na_action, parent=parent, collect=collect)


def recast_to_geoatoms(x: Any, gs: GeoScale, source: str | None = None,
                       key: str | None = None, values: Any = None, rule: Any = None,
                       weight: Any = None, attach_weight: bool = True,
                       collect: bool | None = None) -> Any:
    """Project region data DOWN to the atoms: `sum` columns split by the weight
    share, others repeated; a `weight` column attached. Keyed by `region`."""
    _check_geoscale(gs, "gs")
    bk = ns.backend_of(x, "x")
    schema = ns.backend_schema(x, bk)
    _check_gs_cols(schema)
    if source is None:
        source = _infer_from(gs, schema, key)
    _check_geoframe(gs, source, "source")
    if key is None:
        key = source if source in schema.names else "region"
    if key not in schema.names:
        _stop("`x` has no column named `%s`; pass `key=`", key)
    if attach_weight and "weight" in schema.names:
        _stop("`x` already has a `weight` column; rename it first")
    if key != "region" and "region" in schema.names:
        _stop("`x` already has a `region` column; rename it first")
    gf = list(gs.frames)
    values = _values_for(schema, key, gf, values)
    id_cols = [c for c in schema.names if c != key and c not in values and c not in gf]
    rules = _rules_for(values, rule, weight)
    _no_share(rules, "recast_to_geoatoms")
    wt = list(dict.fromkeys(r["weight"] or "" for r in rules.values()))
    if len(wt) > 1:
        _stop("the value columns resolve to different weights (%s); recast them in "
              "separate calls or pass one `weight=`", _preview(wt))
    wcol = _map_weight(gs, wt[0] if wt[0] else (weight if isinstance(weight, str)
                                                else None))
    t = _as_str(ns.backend_scan(x, bk), key)
    lt = gs.leaftable
    src_keys = [k for k in pc.unique(t[key]).to_pylist() if k is not None]
    known = set(v for v in lt[source].to_pylist() if v is not None)
    unknown = [k for k in src_keys if k not in known]
    if unknown:
        _warn("%d code(s) in `x$%s` are not present at geoframe `%s`: %s",
              len(unknown), key, source, _preview(unknown))

    codes, regions = lt[source].to_pylist(), lt["region"].to_pylist()
    w = ([1.0] * lt.num_rows if wcol is None else
         [0.0 if z is None or z != z else float(z) for z in lt[wcol].to_pylist()])
    rows = [(c, r, z) for c, r, z in zip(codes, regions, w, strict=True)
            if c is not None]
    tot: dict = {}
    cnt: dict = {}
    for c, _, z in rows:
        tot[c] = tot.get(c, 0.0) + z
        cnt[c] = cnt.get(c, 0) + 1
    atoms = pa.table({
        "__gs_k": pa.array([c for c, _, _ in rows], pa.string()),
        "region": pa.array([r for _, r, _ in rows], pa.string()),
        "__gs_f": pa.array([z / tot[c] if tot[c] > 0 else 1 / cnt[c]
                            for c, _, z in rows], pa.float64()),
        "__gs_a": pa.array(np.arange(len(rows))),
        **({"weight": pa.array([z for _, _, z in rows], pa.float64())}
           if attach_weight else {})})
    jkey = key
    if key == "region":  # the data's key gives way to the atoms' region
        t = t.rename_columns(["__gs_key" if c == key else c for c in t.column_names])
        jkey = "__gs_key"
    t = t.append_column("__gs_x", pa.array(np.arange(t.num_rows)))
    out = t.join(atoms, keys=jkey, right_keys="__gs_k", join_type="inner")
    out = out.take(pc.sort_indices(out, sort_keys=[("__gs_x", "ascending"),
                                                   ("__gs_a", "ascending")]))
    for v in values:
        if rules[v]["rule"] == "sum":
            out = out.set_column(out.column_names.index(v), v, pc.multiply(
                pc.cast(out[v], pa.float64()), out["__gs_f"]))
    keep = ["region", *id_cols, *values, *(["weight"] if attach_weight else [])]
    return ns.backend_restore(out.select(keep), bk, collect)


def _summarise(joined: pa.Table, grp: Sequence[str], values: Sequence[str],
               rules: Mapping[str, dict], wt_col: str, na_rm: bool) -> pa.Table:
    ww = pc.cast(joined[wt_col], pa.float64())
    cols: dict[str, Any] = {c: joined[c] for c in grp}
    specs: list = []
    names: dict[str, dict] = {}
    for i, v in enumerate(values):
        c, s = _group_parts(rules[v]["rule"], pc.cast(joined[v], pa.float64()), ww,
                            na_rm)
        pref = "__gs_g%d_" % i
        for nm, arr in c.items():
            cols[pref + nm] = arr
        specs += [(pref + col, fn, opt) for col, fn, opt in s]
        names[v] = {"%s_%s" % (col, fn): "%s%s_%s" % (pref, col, fn)
                    for col, fn, _ in s}
        if rules[v]["rule"] == "copy":
            cols[pref + "raw"] = pc.cast(joined[v], pa.float64())
            specs += [(pref + "raw", "max", _KEEP_NULLS),
                      (pref + "raw", "min", _KEEP_NULLS)]
    g = pa.table(cols).group_by(list(grp)).aggregate(specs)
    res = g.select(list(grp))
    for i, v in enumerate(values):
        if rules[v]["rule"] == "copy":
            pref = "__gs_g%d_raw" % i
            rng = pc.subtract(g[pref + "_max"], g[pref + "_min"])
            bad = pc.and_(pc.is_valid(rng), pc.greater(rng, 1e-9))
            if pc.any(pc.fill_null(bad, False)).as_py():
                _stop('rule "copy" for `%s`: values are not constant within a target '
                      "region", v)
        gv = {k: g[n] for k, n in names[v].items()}
        res = res.append_column(v, _group_result(rules[v]["rule"], gv, na_rm))
    return res


def _member_sort(res: pa.Table, cols: Sequence[str], members: Sequence[Sequence[str]],
                 tail: Sequence[str]) -> pa.Table:
    """Order rows by member position of `cols` (missing last), then `tail`
    columns ascending (dplyr's group order)."""
    pos = [{v: i for i, v in enumerate(m)} for m in members]
    big = 1 << 30
    data = [res[c].to_pylist() for c in cols]
    tails = [res[c].to_pylist() for c in tail]

    def k(r: int) -> tuple:
        out = []
        for p, d in zip(pos, data, strict=True):
            out.append(p.get(d[r], big))
        for d in tails:
            v = d[r]
            out.append((v is None, "" if v is None else v))
        return tuple(out)

    order = sorted(range(res.num_rows), key=k)
    return res.take(pa.array(order, pa.int64()))


def recast_from_geoatoms(x: Any, gs: GeoScale, target: str, key: str | None = None,
                         values: Any = None, rule: Any = None,
                         weight: str | None = None, na_rm: bool = False,
                         na_action: NaAction = "drop",
                         collect: bool | None = None) -> Any:
    """Aggregate atom-keyed rows UP to `target`. Returns the OBSERVED target
    regions only, in member order."""
    na_action = _match_arg(na_action, ("drop", "error", "keep"), "na_action")
    _check_geoscale(gs, "gs")
    bk = ns.backend_of(x, "x")
    _check_geoframe(gs, target, "target")
    schema = ns.backend_schema(x, bk)
    _check_gs_cols(schema)
    if key is None:
        key = "region"
    if key not in schema.names:
        _stop("`x` has no column named `%s`; pass `key=`", key)
    wt_col = "weight"
    if weight is not None:
        if not isinstance(weight, str):
            _stop("`weight` must be a single column name of `x`")
        if weight not in schema.names:
            _stop("`x` has no column named `%s` to weight by", weight)
        wt_col = weight
    gf = list(gs.frames)
    values = _values_for(schema, key, [*gf, wt_col], values)
    id_cols = [c for c in schema.names if c not in (key, wt_col) and c not in values
               and c not in gf]
    rules = _rules_for(values, rule, None)
    _no_share(rules, "recast_from_geoatoms")
    has_weight = wt_col in schema.names
    lt = gs.leaftable
    atoms = {key: lt["region"], "__gs_to": pc.cast(lt[target], pa.string())}
    if not has_weight:
        wcol = _map_weight(gs, None)
        atoms[wt_col] = (pa.array([1.0] * lt.num_rows) if wcol is None else
                         pc.fill_null(pc.cast(lt[wcol], pa.float64()), 0.0))
    atoms = pa.table(atoms)
    t = _as_str(ns.backend_scan(x, bk), key)
    src_keys = [k for k in pc.unique(t[key]).to_pylist() if k is not None]
    regions = set(lt["region"].to_pylist())
    unknown = [k for k in src_keys if k not in regions]
    if unknown:
        _warn("%d code(s) in `x$%s` are not atoms of the GeoScale: %s",
              len(unknown), key, _preview(unknown))
    if not any(k in regions for k in src_keys):
        _stop("no rows of `x` matched the GeoScale's atoms; check `key=`")
    joined = t.join(atoms, keys=key, join_type="left outer")
    n_na = joined["__gs_to"].null_count
    if n_na:
        if na_action == "error":
            _stop("%d row(s) of `x` fall on atoms with no code at geoframe `%s`; "
                  'use na_action = "drop" or "keep"', n_na, target)
        if na_action == "drop":
            _warn("%d row(s) of `x` fall on atoms with no code at geoframe `%s` and "
                  'were dropped; use na_action = "keep" to conserve totals',
                  n_na, target)
            joined = joined.filter(pc.is_valid(joined["__gs_to"]))
    grp = [*id_cols, "__gs_to"]
    res = _summarise(joined, grp, values, rules, wt_col, na_rm)
    res = res.rename_columns([target if c == "__gs_to" else c
                              for c in res.column_names])
    res = res.select([target, *id_cols, *values])
    if bk.lazy and not collect:
        return ns.backend_restore(res, bk, collect)
    res = _member_sort(res, [target], [gs.members[target]], id_cols)
    return ns.backend_restore(res, bk, collect)


def recast_pairs(x: Any, gs: GeoScale, target: str, source: str | None = None,
                 src: str = "src", dst: str = "dst", values: Any = None,
                 rule: Any = None, weight: str | None = None, na_rm: bool = False,
                 directed: bool = True, drop_internal: bool = True,
                 collect: bool | None = None) -> Any:
    """Aggregate origin-destination pairs (columns `src`, `dst` at `source`)
    to `target` codes. Aggregation only; internal pairs are dropped."""
    _check_geoscale(gs, "gs")
    bk = ns.backend_of(x, "x")
    schema = ns.backend_schema(x, bk)
    _check_gs_cols(schema)
    _check_geoframe(gs, target, "target")
    if source is None:
        source = gs.frames[-1]
    _check_geoframe(gs, source, "source")
    if geoscale_rank(gs, target) > geoscale_rank(gs, source):
        _stop('`target` = "%s" is finer than `source` = "%s"; pairs aggregate only',
              target, source)
    if src == dst:
        _stop("`src` and `dst` must differ")
    for nm in (src, dst):
        if nm not in schema.names:
            _stop("`x` has no column named `%s`; pass `src=` / `dst=`", nm)
    wt_col = "weight"
    if weight is not None:
        if not isinstance(weight, str):
            _stop("`weight` must be a single column name of `x`")
        if weight not in schema.names:
            _stop("`x` has no column named `%s` to weight by", weight)
        wt_col = weight
    gf = list(gs.frames)
    drop = [src, dst, wt_col, *gf]
    values = [v for v in _values_for(schema, src, drop, values) if v != dst]
    id_cols = [c for c in schema.names if c not in (src, dst, wt_col)
               and c not in values and c not in gf]
    rules = _rules_for(values, rule, None)
    _no_share(rules, "recast_pairs")
    has_weight = wt_col in schema.names
    lt = gs.leaftable
    look = list(dict.fromkeys(zip(lt[source].to_pylist(), lt[target].to_pylist(),
                                  strict=True)))
    look = [(a, b) for a, b in look if a is not None]
    t = _as_str(_as_str(ns.backend_scan(x, bk), src), dst)
    ends = list(dict.fromkeys(v for c in (src, dst) for v in
                              pc.unique(t[c]).to_pylist() if v is not None))
    froms = set(a for a, _ in look)
    unknown = [e for e in ends if e not in froms]
    if unknown:
        _warn("%d endpoint code(s) are not present at geoframe `%s` and their pairs "
              "were dropped: %s", len(unknown), source, _preview(unknown))
    if not any(e in froms for e in ends):
        _stop("no endpoint of `x` matched geoframe `%s`; check `from=`, `src=` and "
              "`dst=`", source)
    ls = pa.table({src: pa.array([a for a, _ in look], pa.string()),
                   "__gs_src": pa.array([b for _, b in look], pa.string())})
    ld = pa.table({dst: pa.array([a for a, _ in look], pa.string()),
                   "__gs_dst": pa.array([b for _, b in look], pa.string())})
    out = t.join(ls, keys=src, join_type="inner").join(ld, keys=dst,
                                                       join_type="inner")
    if drop_internal:
        same = pc.equal(out["__gs_src"], out["__gs_dst"])
        n_int = pc.sum(pc.cast(pc.fill_null(same, False), pa.int64())).as_py() or 0
        if n_int > 0:
            _warn("%d pair(s) fall inside a single `%s` region and were dropped as "
                  "internal", n_int, target)
        out = out.filter(pc.invert(pc.fill_null(same, False)))
    if not directed:
        a, b = out["__gs_src"], out["__gs_dst"]
        le = pc.less_equal(a, b)
        out = out.set_column(out.column_names.index("__gs_src"), "__gs_src",
                             pc.if_else(le, a, b))
        out = out.set_column(out.column_names.index("__gs_dst"), "__gs_dst",
                             pc.if_else(le, b, a))
    if not has_weight:
        out = out.append_column(wt_col, pa.array([1.0] * out.num_rows))
    grp = ["__gs_src", "__gs_dst", *id_cols]
    res = _summarise(out, grp, values, rules, wt_col, na_rm)
    res = res.rename_columns([{"__gs_src": src, "__gs_dst": dst}.get(c, c)
                              for c in res.column_names])
    res = res.select([src, dst, *id_cols, *values])
    if bk.lazy and not collect:
        return ns.backend_restore(res, bk, collect)
    ordm = gs.members[target]
    res = _member_sort(res, [src, dst], [ordm, ordm], id_cols)
    return ns.backend_restore(res, bk, collect)


@ns.recast.register(GeoScale)
def _(scale: GeoScale, x: Any, target: Any = None, source: str | None = None,
      **kwargs: Any) -> Any:
    return recast_geoscale(x, scale, source=source, target=target, **kwargs)
