"""Definition files across the two bindings: R writes -> Python reads, and
Python writes -> R reads, for a plain GeoScale, one with labels in two
variants and a hidden geoframe, two samples, a pruned one, one whose leaves
are finer than its finest geoframe and one with geometry.

A definition holds the tables and the metadata of a GeoScale: the leaf
column, the geoframes, the members, the leaftable, the labels and `meta`
(with the CRS of the geometry). It holds neither the geometry nor the
hidden geoframes, and neither binding registers the class for reading, so a
definition is read as the core scale (`cls="core"`) and `as_geoscale()`
rebuilds the GeoScale.

The R half runs tests/r/roundtrip.R and is skipped when Rscript or the R
packages are unavailable; the environment variable GEOSCALES_RSCRIPT names
the Rscript to run when the one on the path is not the one wanted."""
import json
import math
import os
import subprocess
from pathlib import Path

import nestedscales as ns
import pyarrow as pa
import pytest

import geoscales as gs

REPO = Path(__file__).resolve().parents[2]
R_SCRIPT = Path(__file__).with_name("r") / "roundtrip.R"
RSCRIPT = os.environ.get("GEOSCALES_RSCRIPT") or "Rscript"


def with_geometry():
    try:
        import geopandas as gpd
        import shapely
    except ImportError:
        return None
    boxes = [shapely.box(x, y, x + d, y + d) for x, y, d in
             [(0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1), (2, 0, 1), (2, 1, 1),
              (10, 10, 2)]]
    shp = gpd.GeoDataFrame({"cell": ["A1", "A2", "A3", "A4", "A5", "A6", "ROW"]},
                           geometry=boxes, crs=4326)
    return gs.attach_geometry_geoscale(gs.geoscale_example(), shp)


def with_labels():
    x = gs.attach_labels_geoscale(gs.geoscale_example(), pa.table({
        "geoframe": ["country", "country", "country", "state", "cell"],
        "region": ["N", "S", None, "N1", "A3"],
        "label": ["North", "South", "Country", "North one", "Cell three"]}))
    x = gs.attach_labels_geoscale(x, pa.table({
        "geoframe": ["country", "zone"], "region": ["N", "ZB"],
        "label": ["Nth", "Zone B"]}), variant="short", default="short")
    return gs.hide_geoframes_geoscale(x, "zone")


def finer_leaves():
    return gs.geoscale_from_leaftable(pa.table({
        "big": ["Y", "X", "Y", "X", "X"], "mid": ["m3", "m1", "m3", "m2", "m1"],
        "id": ["p4", "p1", "p5", "p3", "p2"], "w": [2.0, 1, 2, 2, 3],
        "n": [1.0, 1, 1, 1, 1]}),
        geoframes=["big", "mid"], leaf="id", weights="w", name="fine")


def cases():
    out = {
        "plain": gs.geoscale_example(),
        "labels": with_labels(),
        "filtered": gs.filter_geoscale(gs.geoscale_example(), "country", "N"),
        "filtered_labels": gs.filter_geoscale(with_labels(), "zone", ["ZB", "ZC"]),
        "pruned": gs.prune_geoscale(gs.geoscale_example(), "state"),
        "finer_leaves": finer_leaves(),
    }
    g = with_geometry()
    if g is not None:
        out["geometry"] = g
    return out


def close(a, b):
    """Equal, numbers to a relative 1e-12 (a sum is accumulated in extended
    precision by R)."""
    if isinstance(a, bool) or isinstance(b, bool):
        return a is b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-15)
    if isinstance(a, dict) and isinstance(b, dict):
        return list(a) == list(b) and all(close(a[k], b[k]) for k in a)
    if isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)):
        return len(a) == len(b) and all(close(x, y) for x, y in zip(a, b, strict=True))
    return a == b


def read_definition(path):
    """The GeoScale of a definition file: read as the core scale, then
    rebuilt."""
    core = ns.read_scale(path, cls="core")
    assert type(core) is ns.NestedScale
    return gs.as_geoscale(core)


def same_geoscale(got, want):
    """Everything a definition carries: tables, metadata and identity."""
    assert type(got) is gs.GeoScale
    assert got.frames == want.frames and got.leaf == want.leaf
    assert got.members == want.members
    assert got.leaftable.schema.equals(want.leaftable.schema)
    assert close(got.leaftable.to_pydict(), want.leaftable.to_pydict())
    assert gs.geoscale_id(got) == gs.geoscale_id(want)
    assert gs.geoscale_labels(got).equals(gs.geoscale_labels(want))
    assert got.attributes.equals(want.attributes)
    assert got.aliases.equals(want.aliases)
    assert list(got.meta) == list(want.meta)
    for k in want.meta:
        assert close(got.meta[k], want.meta[k]), k
    assert gs.geoscale_weights(got) == gs.geoscale_weights(want)
    assert close(gs.geoscale_coverage(got), gs.geoscale_coverage(want))
    # not part of a definition
    assert got.geometry is None
    assert gs.geoscale_geoframes(got, visible=False) == []


def _r_available():
    try:
        run = subprocess.run(
            [RSCRIPT, "-e", "stopifnot(requireNamespace('pkgload', quietly = TRUE),"
                            " requireNamespace('jsonlite', quietly = TRUE),"
                            " packageVersion('nestedscales') >= '0.3.0')"],
            capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return False
    return run.returncode == 0


def test_python_round_trip(tmp_path):
    for nm, x in cases().items():
        for tables, path in (("inline", "%s.json" % nm), ("arrow", "%s.scale" % nm)):
            file = ns.write_scale(x, tmp_path / path, tables=tables)
            same_geoscale(read_definition(file), x)
        hdr = json.loads((tmp_path / ("%s.json" % nm)).read_text(encoding="utf-8"))
        assert hdr["class"] == "geoscales::GeoScale"
        assert hdr["schema_version"] == 2 and hdr["leaf"] == x.leaf
        assert ("labels" in hdr["tables"]) == (x.labels.num_rows > 0)
        assert hdr["payload"] == {}


def test_geometry_and_hidden_stay_out_of_a_definition(tmp_path):
    x = with_geometry()
    if x is None:
        pytest.skip("geopandas and shapely needed")
    x = gs.hide_geoframes_geoscale(x, "zone")
    back = read_definition(ns.write_scale(x, tmp_path / "g.json"))
    assert back.geometry is None and back.meta["crs"] == "EPSG:4326"
    assert gs.geoscale_geoframes(back, visible=False) == []
    assert gs.geoscale_id(back) == gs.geoscale_id(x)


@pytest.mark.skipif(not _r_available(),
                    reason="Rscript with pkgload, jsonlite and nestedscales >= 0.3.0 "
                           "needed")
def test_definitions_cross_the_bindings(tmp_path):
    r_dir, py_dir = tmp_path / "r", tmp_path / "py"
    r_dir.mkdir()
    py_dir.mkdir()
    run = subprocess.run([RSCRIPT, str(R_SCRIPT), str(REPO), "write", str(r_dir)],
                         capture_output=True, text=True)
    assert run.returncode == 0, run.stderr
    built = cases()
    written = sorted(p.stem for p in r_dir.iterdir())
    # the geometry case needs sf in R and geopandas here
    assert set(built) - {"geometry"} <= set(written)
    names = [nm for nm in built if nm in written]
    # R -> Python: tables, metadata and identity are those of the GeoScale
    # this binding builds
    for nm in names:
        hdr = json.loads((r_dir / ("%s.json" % nm)).read_text(encoding="utf-8"))
        assert hdr["class"] == "geoscales::GeoScale"
        same_geoscale(read_definition(r_dir / ("%s.json" % nm)), built[nm])
    # Python -> R
    for nm in names:
        ns.write_scale(built[nm], py_dir / ("%s.json" % nm))
    for p in r_dir.iterdir():
        if p.stem not in names:
            p.unlink()
    run = subprocess.run([RSCRIPT, str(R_SCRIPT), str(REPO), "check", str(py_dir),
                          str(r_dir)], capture_output=True, text=True)
    assert run.returncode == 0, run.stderr
    assert sorted(run.stdout.split()) == sorted(
        w for nm in names for w in ("OK", nm)), run.stdout
