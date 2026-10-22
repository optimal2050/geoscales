"""Replay specs/json/*.json, written by tools/specs/make_json_goldens.R from
the R sources: construction, navigation, recast, maps, joins and geometry --
results, warnings and error messages. Geometry is compared as type, area
(geodesic on WGS84 for lon/lat, as sf with s2 off) and bounds."""
import json
import math
import warnings
from pathlib import Path

import nestedscales as ns
import pyarrow as pa
import pytest

import geoscales as gs

JSON = Path(__file__).resolve().parents[2] / "specs" / "json"
TOPICS = ["construct", "navigate", "recast", "geometry"]
CASES = [(t, i, c) for t in TOPICS
         for i, c in enumerate(json.loads((JSON / ("%s.json" % t)).read_text(
             encoding="utf-8"))["cases"])]

R_ARGS = {"from": "source", "to": "target"}
R_MESSAGE = [("`from`", "`source`"), ("`to`", "`target`")]


def r_message(m):
    for a, b in R_MESSAGE:
        m = m.replace(a, b)
    return m


def table(spec):
    return pa.table({
        k: pa.array(v if isinstance(v, list) else [v],
                    pa.string() if spec["types"][k] == "string" else pa.float64())
        for k, v in spec["columns"].items()})


def frame(d):
    """A JSON data.frame -- column-wise or row-wise -- as a table."""
    if isinstance(d, list):
        keys = list(dict.fromkeys(k for r in d for k in r))
        d = {k: [r.get(k) for r in d] for k in keys}
    cols = {}
    for k, v in d.items():
        v = v if isinstance(v, list) else [v]
        cols[k] = pa.array(v, pa.float64() if all(
            isinstance(z, (int, float)) or z is None for z in v) and any(
            isinstance(z, (int, float)) for z in v) else pa.string())
    return pa.table(cols)


def build_gs(spec):
    b = spec["build"]
    args = spec.get("args") or {}
    if isinstance(args, list):
        args = {}
    if b == "example":
        x = gs.geoscale_example()
    elif b == "leaftable":
        x = gs.geoscale_from_leaftable(frame(spec["leaftable"]), **args)
    else:
        x = gs.geoscale_build(*[frame(d) for d in spec["xwalks"]], **args)
    g = spec.get("geometry")
    if g:
        import geopandas as gpd
        import shapely

        codes = g["codes"] if isinstance(g["codes"], list) else [g["codes"]]
        wkt = g["wkt"] if isinstance(g["wkt"], list) else [g["wkt"]]
        shp = gpd.GeoDataFrame({g["by"]: codes},
                               geometry=[shapely.from_wkt(w) for w in wkt],
                               crs=g["crs"])
        x = gs.attach_geometry_geoscale(x, shp, by=g["by"], geoframe=g["geoframe"])
    for st in spec.get("steps") or []:
        pos, kw = call_args(st["args"])
        x = getattr(gs, st["fn"])(x, *pos, **kw)
    return x


def decode(a):
    if isinstance(a, dict):
        if "sf" in a:
            import geopandas as gpd
            import shapely

            s = a["sf"]
            wkt = s["wkt"] if isinstance(s["wkt"], list) else [s["wkt"]]
            return gpd.GeoDataFrame(table(s["table"]).to_pandas(),
                                    geometry=[shapely.from_wkt(w) for w in wkt],
                                    crs=s["crs"])
        if "scale" in a:
            return build_gs(a["scale"])
        if "table" in a:
            return table(a["table"])
    return a


def call_args(args):
    if isinstance(args, list):
        return [decode(v) for v in args], {}
    pos = [decode(v) for k, v in args.items() if k.isdigit()]
    kw = {R_ARGS.get(k, k): decode(v) for k, v in args.items() if not k.isdigit()}
    return pos, kw


def norm(v):
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float)):
        v = float(v)
        return None if math.isnan(v) else float("%.9g" % v)
    if isinstance(v, dict):
        return {k: norm(z) for k, z in v.items()}
    if isinstance(v, (list, tuple)):
        return [norm(z) for z in v]
    return v


def rows(t):
    if not isinstance(t, pa.Table):
        t = ns.backend_pull(t)
    return [tuple(sorted((k, norm(v)) for k, v in r.items())) for r in t.to_pylist()]


def json_rows(value):
    return [tuple(sorted((k, norm(v)) for k, v in r.items())) for r in value]


def geom_info(geoms, crs):
    if geoms is None:
        return None
    import pyproj

    geographic = crs is not None and pyproj.CRS.from_user_input(crs).is_geographic
    out = []
    for g in geoms:
        if g is None or g.is_empty:
            out.append({"empty": True})
            continue
        area = (abs(pyproj.Geod(ellps="WGS84").geometry_area_perimeter(g)[0])
                if geographic else g.area)
        out.append({"type": g.geom_type.upper(), "area": area,
                    "bounds": list(g.bounds)})
    return out


def same_geom(have, want):
    assert (have is None) == (want is None)
    if have is None:
        return
    assert len(have) == len(want)
    for h, w in zip(have, want, strict=True):
        if w.get("empty"):
            assert h.get("empty")
            continue
        assert h["type"] == w["type"]
        assert math.isclose(h["area"], w["area"], rel_tol=1e-6)
        assert h["bounds"] == pytest.approx(w["bounds"], abs=1e-9)


def describe(x):
    m = x.meta
    return {"frames": list(x.frames), "members": {k: list(v) for k, v in
                                                  x.members.items()},
            "name": m.get("name"), "parent_name": m.get("parent_name"),
            "weights": list(m.get("weights") or ()),
            "default_weight": m.get("default_weight"), "coverage": m.get("coverage"),
            "parent_totals": m.get("parent_totals"), "crs": m.get("crs")}


def compare(got, want, ordered):
    kind = want["kind"]
    if kind == "geoscale":
        v = dict(want["value"])
        lt, geom = v.pop("leaftable"), v.pop("geometry")
        assert norm(describe(got)) == norm({k: v.get(k) for k in describe(got)})
        assert rows(got.leaftable) == json_rows(lt)
        same_geom(geom_info(got.geometry, got.meta.get("crs")), geom)
    elif kind == "sf":
        assert rows(pa.Table.from_pandas(got.drop(columns=got.geometry.name),
                                         preserve_index=False)) == json_rows(
            want["value"])
        same_geom(geom_info(list(got.geometry.values), got.crs), want["geometry"])
    elif kind == "table":
        have, exp = rows(got), json_rows(want["value"])
        if ordered:
            assert have == exp
        else:
            assert sorted(have, key=repr) == sorted(exp, key=repr)
    elif kind == "verdict":
        assert got.ok == want["value"]
        offs = want["offenders"] if isinstance(want["offenders"], list) else \
            [want["offenders"]]
        assert set(got.offenders) == set(offs)
    else:
        vals = want["value"] if isinstance(want["value"], list) else [want["value"]]
        if isinstance(got, dict):
            got = list(got.values())
        if not isinstance(got, list):
            got = [got]
        assert norm(got) == norm(vals)


def label(c):
    return "%s:%s(%s)" % (c[0], c[2]["fn"], c[1])


@pytest.fixture(autouse=True)
def _clean():
    gs.clear_geoscale_rules()
    gs.clear_geoscale_maps()
    yield
    gs.clear_geoscale_rules()
    gs.clear_geoscale_maps()


@pytest.mark.parametrize("case", CASES, ids=[label(c) for c in CASES])
def test_json_golden(case):
    topic, _, c = case
    if topic == "geometry" or "geometry" in json.dumps(c["args"]):
        pytest.importorskip("shapely")
        pytest.importorskip("pyproj")
        pytest.importorskip("geopandas")
    fn = getattr(gs, c["fn"])
    with warnings.catch_warnings(record=True) as rec:
        warnings.simplefilter("always")
        pos, kw = call_args(c["args"])
        if c["error"]:
            with pytest.raises(ns.NestedScalesError) as e:
                fn(*pos, **kw)
            msg = c["message"]
            if msg.startswith("'arg' should be one of"):  # R's own match.arg()
                assert "should be one of" in str(e.value)
            else:
                assert str(e.value) == r_message(msg)
            return
        got = fn(*pos, **kw)
    assert [str(w.message) for w in rec] == [r_message(w) for w in c["warnings"]]
    compare(got, c["value"], c["ordered"])
