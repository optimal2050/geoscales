"""Labels -- display names for regions and geoframes, in named variants (port
of R/labels.R).

A long table keyed by (geoframe, region, variant): one row per display
name. The table is sparse -- a geoframe, or a region, without a row is shown
by its code -- and a row with a null `region` names the geoframe itself.

The object stores the table under the column names of nestedscales (`frame`,
`member`), whose validator reads it too. The functions here take and return
it under the spatial names (`geoframe`, `region`).
"""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

import pyarrow as pa
import pyarrow.compute as pc
from nestedscales import (
    backend_pull,
    scale_label,
    scale_leaf_column,
    scale_set_props,
)

from ._utils import _as_list, _check_geoframe, _check_geoscale, _preview, _stop

LABEL_COLS = ("frame", "member", "variant", "label")
LABEL_PUBLIC = {"frame": "geoframe", "member": "region"}
DEFAULT_VARIANT = "label"
_LABEL_SCHEMA = pa.schema([(c, pa.string()) for c in LABEL_COLS])


def _empty_labels() -> pa.Table:
    return _LABEL_SCHEMA.empty_table()


def _public_labels(lb: pa.Table) -> pa.Table:
    """The label table under the names it is shown with."""
    return lb.rename_columns([LABEL_PUBLIC.get(c, c) for c in lb.column_names])


def _as_labels(labels: Any, variant: str | None = None) -> pa.Table:
    """Coerce user input to the stored label table; a table without a
    `variant` column takes `variant` (default `"label"`). Membership is
    checked by the validator."""
    if labels is None:
        return _empty_labels()
    try:
        if isinstance(labels, (str, bytes, int, float)):
            raise TypeError
        t = labels if isinstance(labels, pa.Table) else backend_pull(labels)
    except Exception:
        _stop("`labels` must be a data.frame with columns `geoframe`, `region` and "
              "`label`")
    # stored under the names of nestedscales, which are accepted as well
    back = {v: k for k, v in LABEL_PUBLIC.items()}
    t = t.rename_columns([back.get(c, c) for c in t.column_names])
    if "variant" in t.column_names:
        if variant is not None:
            _stop("`labels` already has a `variant` column; drop `variant=`")
    else:
        if variant is None:
            variant = DEFAULT_VARIANT
        if not isinstance(variant, str) or variant == "":
            _stop("`variant` must be a single string")
        t = t.append_column("variant", pa.array([variant] * t.num_rows, pa.string()))
    missing = [c for c in LABEL_COLS if c not in t.column_names]
    if missing:
        _stop("`labels` is missing column(s): %s",
              _preview([LABEL_PUBLIC.get(c, c) for c in missing]))
    extra = [c for c in t.column_names if c not in LABEL_COLS]
    if extra:
        _stop("`labels` has unknown column(s): %s", _preview(extra))
    cols = {}
    for c in LABEL_COLS:
        col = t[c]
        if pa.types.is_dictionary(col.type):
            col = col.cast(col.type.value_type)
        cols[c] = col.cast(pa.string())
    return pa.table(cols, schema=_LABEL_SCHEMA)


def _default_variant(x) -> str:
    """The variant a lookup uses when none is named: the declared default,
    else the first in the table."""
    have = x.labels["variant"].to_pylist()
    variant = x.meta.get("default_label")
    if variant is None or variant not in have:
        variant = have[0] if have else DEFAULT_VARIANT
    return variant


def _label_keys(lb: pa.Table) -> list[tuple]:
    """(frame, member, variant) row keys; a null member is the geoframe's
    own."""
    return list(zip(lb["frame"].to_pylist(), lb["member"].to_pylist(),
                    lb["variant"].to_pylist(), strict=True))


def _check_labels_table(lb: Any, geoframes: Sequence[str],
                        members: Mapping[str, Sequence[str]]) -> list[str]:
    """The checks the validator runs on a label table."""
    if not isinstance(lb, pa.Table):
        return ["`labels` must be a data.frame or NULL"]
    if tuple(lb.column_names) != LABEL_COLS:
        return ["`labels` must have exactly the columns: %s" % ", ".join(LABEL_COLS)]
    errs: list[str] = []
    if lb.num_rows == 0:
        return errs
    fr, mb = lb["frame"].to_pylist(), lb["member"].to_pylist()
    bad_frame = list(dict.fromkeys(f for f in fr if f not in geoframes))
    if bad_frame:
        errs.append("`labels` names geoframe(s) not in the object: %s"
                    % _preview(bad_frame))
    bad = list(dict.fromkeys(
        "%s/%s" % (f, u) for f, u in zip(fr, mb, strict=True)
        if f in geoframes and u is not None and u not in members.get(f, ())))
    if bad:
        errs.append("`labels` names (geoframe/region) pairs that are not members: %s"
                    % _preview(bad))
    for c in ("variant", "label"):
        if any(z is None or z == "" for z in lb[c].to_pylist()):
            errs.append("`labels$%s` must be non-empty strings" % c)
    keys = _label_keys(lb)
    if len(set(keys)) != len(keys):
        seen: set = set()
        dup = [k for k in keys if k in seen or seen.add(k)]
        errs.append("`labels` has more than one label for: %s" % _preview(
            list(dict.fromkeys("%s/%s [%s]" % (
                f, "<geoframe>" if u is None else u, va) for f, u, va in dup))))
    return errs


def _trim_labels(lb: pa.Table | None, geoframes: Sequence[str],
                 members: Mapping[str, Sequence[str]]) -> pa.Table:
    """The label rows of the geoframes and regions that remain; a geoframe's
    own label stays while the geoframe does."""
    if lb is None or lb.num_rows == 0:
        return _empty_labels()
    keep = [f in geoframes and (u is None or u in members.get(f, ()))
            for f, u in zip(lb["frame"].to_pylist(), lb["member"].to_pylist(),
                            strict=True)]
    return lb.filter(pa.array(keep, pa.bool_()))


def attach_labels_geoscale(x, labels: Any, variant: str | None = None,
                           default: str | None = None, overwrite: bool = False):
    """Add display names to the label table of a GeoScale.

    `labels` has the columns `geoframe`, `region`, `label` and, unless
    `variant` is given, optionally `variant`; a null `region` labels the
    geoframe itself. `variant` fills the `variant` column when the table has
    none (default `"label"`). `default` names the variant a lookup uses when
    it names none; None keeps the current one (initially the first variant
    attached). A (geoframe, region, variant) already present is an error
    unless `overwrite=True`, which replaces it.
    """
    _check_geoscale(x)
    new = _as_labels(labels, variant=variant)
    old = x.labels
    k_new = set(_label_keys(new))
    clash = [k in k_new for k in _label_keys(old)]
    if any(clash):
        if not overwrite:
            _stop("label(s) already present: %s; pass overwrite = TRUE to replace",
                  _preview(list(dict.fromkeys(
                      "%s/%s" % (f, "NA" if u is None else u)
                      for (f, u, _), hit in zip(_label_keys(old), clash, strict=True)
                      if hit))))
        old = old.filter(pa.array([not c for c in clash], pa.bool_()))
    out = pa.concat_tables([old, new])
    meta = dict(x.meta)
    if default is not None:
        have = list(dict.fromkeys(out["variant"].to_pylist()))
        if not isinstance(default, str) or default not in have:
            _stop("`default` must be a variant of the label table: %s",
                  _preview(have))
        meta["default_label"] = default
    return scale_set_props(x, check=True, labels=out, meta=meta)


def geoscale_labels(x, geoframe: str | None = None,
                    variant: str | Sequence[str] | None = None) -> pa.Table:
    """The label rows (`geoframe`, `region`, `variant`, `label`), optionally
    of one geoframe and/or some variants. A row with a null `region` is the
    label of the geoframe itself."""
    _check_geoscale(x)
    lb = x.labels
    if geoframe is not None:
        _check_geoframe(x, geoframe)
        lb = lb.filter(pc.equal(lb["frame"], geoframe))
    if variant is not None:
        lb = lb.filter(pc.is_in(lb["variant"],
                                value_set=pa.array(_as_list(variant), pa.string())))
    return _public_labels(lb)


def geoscale_label(x, region: str | None | Sequence[str | None], geoframe: str,
                   variant: str | None = None) -> list[str]:
    """One display name per code of `region` at `geoframe`.

    A code without a label of the chosen variant is returned unchanged; None
    stands for the geoframe itself and gives the geoframe's label, or its
    name when it has none. `variant=None` uses the default variant of the
    GeoScale.
    """
    _check_geoscale(x)
    _check_geoframe(x, geoframe)
    return scale_label(x, region, geoframe, variant)


def geoscale_leaf_column(x) -> str:
    """The name of the leaf column: the column of the leaftable that
    identifies the leaves. It is the finest geoframe's own column unless the
    leaves are finer than the finest geoframe."""
    _check_geoscale(x)
    return scale_leaf_column(x)
