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


_RULE_ACTIONS = {
    "sum": ("sum", "split proportionally to the weight", True, "split"),
    "weighted_mean": ("weighted mean", "copy", False, "replicate"),
    "mean": ("mean", "copy", False, "replicate"),
    "copy": ("the common value", "copy", False, "replicate"),
    "sd": ("standard deviation", None, None, "none"),
    "share": ("share within parent", None, None, "none"),
    "logshare": ("share within parent", None, None, "none"),
}


def geoscale_rule_action(rule: str | Sequence[str] = GEOSCALE_RULES) -> pa.Table:
    """What each recast rule does going up and going down.

    One row per rule asked for: `up` (aggregation), `down` (disaggregation;
    null where the rule has no downward meaning), `divisible` (whether the
    value of a parent can be divided between its children; only `sum` is)
    and `action` (`"split"`, `"replicate"` or `"none"`).
    """
    ok = isinstance(rule, str) or (isinstance(rule, (list, tuple)) and len(rule) > 0
                                   and all(isinstance(r, str) for r in rule))
    if not ok:
        _stop("`rule` must be a character vector of rule names")
    rule = [rule] if isinstance(rule, str) else list(rule)
    bad = [r for r in dict.fromkeys(rule) if r not in GEOSCALE_RULES]
    if bad:
        _stop("not a recast rule: %s. The rules are: %s", ", ".join(bad),
              ", ".join(GEOSCALE_RULES))
    rows = [_RULE_ACTIONS[r] for r in rule]
    return pa.table({
        "rule": pa.array(rule, pa.string()),
        "up": pa.array([r[0] for r in rows], pa.string()),
        "down": pa.array([r[1] for r in rows], pa.string()),
        "divisible": pa.array([r[2] for r in rows], pa.bool_()),
        "action": pa.array([r[3] for r in rows], pa.string())})


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


def clear_geoscale_rules(param: str | Sequence[str] | None = None) -> None:
    """Remove geoscale rules: the named value columns, or all of them."""
    ns.clear_scale_rules(param, scope="geoscale")
