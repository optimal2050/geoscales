"""Replay specs/golden/*: the language-neutral cases written by
tools/specs/make_goldens.R (a port of its `run_spec_op()`)."""
import csv
import math
import warnings
from pathlib import Path

import pyarrow as pa
import pytest
import yaml

import geoscales as gs

SPECS = Path(__file__).resolve().parents[2] / "specs"
CASES = sorted(p for p in (SPECS / "golden").iterdir() if p.is_dir())
KEY_ORDER = ("id", "country", "state", "zone", "atom", "region", "band")
# R's yaml writes NA as these tags (read_yaml() decodes them back)
R_NA = (None, "NA", ".na", ".na.character", ".na.real", ".na.integer")


def load_structure(name):
    y = yaml.safe_load((SPECS / "regions" / ("%s.yaml" % name)).read_text())
    rows = y["leaftable"]
    weights = y["weights"] if isinstance(y["weights"], list) else [y["weights"]]
    geoframes = y["geoframes"] if isinstance(y["geoframes"], list) else [y["geoframes"]]
    cols = {}
    for k in rows[0]:
        vals = [r.get(k) for r in rows]
        if k in weights:
            cols[k] = pa.array([float(v) for v in vals], pa.float64())
        else:
            cols[k] = pa.array([None if v in R_NA else str(v) for v in vals],
                               pa.string())
    return gs.geoscale_from_leaftable(pa.table(cols), geoframes=geoframes,
                                      weights=weights, name=y["name"])


def as_table(rows):
    if not rows:
        return pa.table({})
    cols = {}
    for k in rows[0]:
        vals = [r[k] for r in rows]
        cols[k] = (pa.array([float(v) for v in vals]) if k != "id" and all(
            isinstance(v, (int, float)) for v in vals) else pa.array(
            [str(v) for v in vals]))
    return pa.table(cols)


def run_spec_op(spec):
    x = as_table(spec.get("input") or [])
    p = spec["params"]
    g = load_structure(spec["structure"])
    op = spec["op"]
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        if op == "recast":
            return gs.recast_geoscale(x, g, source=p.get("from"), target=p["to"],
                                      rule=p["rule"], weight=p.get("weight"),
                                      na_action=p.get("na_action", "drop"))
        if op == "to_atoms":
            return gs.recast_to_geoatoms(x, g, source=p.get("from"), rule=p["rule"],
                                         weight=p.get("weight"))
        if op == "from_atoms":
            return gs.recast_from_geoatoms(x, g, target=p["to"], rule=p["rule"],
                                           values=p.get("values"))
        if op == "join":
            return gs.join_geoscale(x, g, geoframe=p.get("geoframe"),
                                    geoframes=p.get("geoframes"),
                                    meta=bool(p.get("meta")), weight=p.get("weight"),
                                    as_factor=False)
        if op == "filter":
            return gs.geoscale_leaftable(gs.filter_geoscale(g, p["geoframe"],
                                                            p["regions"]))
        if op == "prune":
            return gs.geoscale_leaftable(gs.prune_geoscale(g, p["geoframe"],
                                                           keep_geometry=False))
    raise AssertionError("unknown op " + op)


def norm(v):
    if v is None or v == "NA":
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return str(v)
    return None if math.isnan(f) else f


def key_of(r, keys):
    return tuple((r[k] is None or r[k] == "NA", str(r[k])) for k in keys)


@pytest.mark.parametrize("case", CASES, ids=[c.name for c in CASES])
def test_spec_golden(case):
    spec = yaml.safe_load((case / "input.yaml").read_text())
    with (case / "expected.csv").open(newline="") as fh:
        expected = list(csv.DictReader(fh))
    got = run_spec_op(spec).to_pylist()
    cols = list(expected[0].keys())
    keys = [k for k in KEY_ORDER if k in cols]
    got = sorted(got, key=lambda r: key_of(r, keys))
    expected = sorted(expected, key=lambda r: key_of(r, keys))
    assert len(got) == len(expected)
    for r, w in zip(got, expected, strict=True):
        assert set(r) == set(cols), (sorted(r), cols)
        for c in cols:
            a, b = norm(r[c]), norm(w[c])
            if isinstance(a, float) and isinstance(b, float):
                assert math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-12), (c, r, w)
            else:
                assert a == b, (c, r, w)
