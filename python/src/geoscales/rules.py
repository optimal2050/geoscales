"""Recast rules (port of R/rules.R): kept in nestedscales' registry under the
scope "geoscale"."""
from __future__ import annotations

from collections.abc import Sequence

import nestedscales as ns
import pyarrow as pa

from ._utils import _stop

GEOSCALE_RULES = ("sum", "weighted_mean", "mean", "copy", "sd", "share", "logshare")


def _match_arg(value: object, choices: Sequence[str], arg: str) -> str:
    """R's `match.arg()`: exact, else a unique prefix."""
    if isinstance(value, str):
        if value in choices:
            return value
        hits = [c for c in choices if value and c.startswith(value)]
        if len(hits) == 1:
            return hits[0]
    _stop("`%s` should be one of: %s", arg, ", ".join(choices))


def register_geoscale_rule(param: str, rule: str, weight: str | None = None) -> dict:
    """Record the recast rule (and weight) for a value column."""
    if not isinstance(param, str) or param == "":
        _stop("`param` must be a single non-empty string")
    rule = _match_arg(rule, GEOSCALE_RULES, "rule")
    if weight is not None and not isinstance(weight, str):
        _stop("`weight` must be a single string or NULL")
    e = ns.register_scale_rule(param, rule, weight, scope="geoscale")
    return {"rule": e["rule"], "weight": e["weight"]}


def get_geoscale_rule(param: str) -> dict | None:
    e = ns.get_scale_rule(param, scope="geoscale")
    return None if e is None else {"rule": e["rule"], "weight": e["weight"]}


def list_geoscale_rules() -> pa.Table:
    return ns.list_scale_rules(scope="geoscale").select(["param", "rule", "weight"])


def clear_geoscale_rules(name: str | Sequence[str] | None = None) -> None:
    """Remove geoscale rules: the named value columns, or all of them."""
    ns.clear_scale_rules(name, scope="geoscale")
