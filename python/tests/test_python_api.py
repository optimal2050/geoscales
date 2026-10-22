"""What the R goldens do not reach: backends, the store, geometry following
the engine, providers, the recast generic."""
import nestedscales as ns
import pyarrow as pa
import pytest
from nestedscales import NestedScalesError

import geoscales as gs


def cells():
    gpd = pytest.importorskip("geopandas")
    shapely = pytest.importorskip("shapely")

    atoms = ["A1", "A2", "A3", "A4", "A5", "A6", "ROW"]
    boxes = [shapely.box(x, y, x + 1, y + 1)
             for x, y in [(0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (2, 1), (10, 10)]]
    return gpd.GeoDataFrame({"atom": atoms}, geometry=boxes, crs=4326)


def test_backends_round_trip_their_type():
    pd = pytest.importorskip("pandas")
    pl = pytest.importorskip("polars")
    s = gs.geoscale_example()
    d = pa.table({"atom": ["A1", "A2", "A3", "A4", "A5", "A6"],
                  "cap": [1.0, 2, 3, 4, 5, 6]})
    ref = gs.recast_geoscale(d, s, target="country", rule="sum")
    got = gs.recast_geoscale(d.to_pandas(), s, target="country", rule="sum")
    assert isinstance(got, pd.DataFrame) and got["cap"].tolist() == [10.0, 11.0]
    got = gs.recast_from_geoatoms(pl.from_arrow(d.rename_columns(["region", "cap"])),
                                  s, target="state", rule="sum")
    assert isinstance(got, pl.DataFrame)
    assert ref["cap"].to_pylist() == [10.0, 11.0]


def test_geometry_follows_filter_and_prune():
    s = gs.attach_geometry_geoscale(gs.geoscale_example(), cells())
    assert s.meta["crs"] == "EPSG:4326" and len(s.geometry) == 7
    f = gs.filter_geoscale(s, "state", "N1")
    assert len(f.geometry) == 2 and f.geometry[0].bounds == (0, 0, 1, 1)
    p = gs.prune_geoscale(s, "state")
    assert [g.area for g in p.geometry] == [2.0, 2.0, 2.0]
    assert gs.prune_geoscale(s, "state", keep_geometry=False).geometry is None
    z = gs.zoom_geoscale(s, "A3", geoframes=["country", "state"])
    assert len(z.geometry) == 7


def test_store_round_trip_and_as_geoscale(tmp_path):
    s = gs.geoscale_example()
    ns.write_scale_dataset(pa.table({"region": ["A1"], "v": [1.0]}), s, tmp_path / "g")
    back = gs.as_geoscale(ns.open_scale_dataset(tmp_path / "g").scale)
    assert isinstance(back, gs.GeoScale) and back == s
    with pytest.raises(NestedScalesError, match="must be a NestedScale"):
        gs.as_geoscale("example")


def test_providers_registry():
    gs.register_geoscale_provider(
        "toy", fetch=lambda: pa.table({"c": ["X", "X", "Y"], "f": ["a", "b", "c"],
                                       "pop": [1.0, 2.0, 3.0]}),
        geoframes=["c", "f"], weights=["pop"], desc="toy data")
    g = gs.geoscale_from_provider("toy", name="toy")
    assert g.meta["source"] == "toy" and gs.geoscale_weights(g) == ["pop"]
    assert "toy" in gs.list_geoscale_providers()["name"].to_pylist()
    with pytest.raises(NestedScalesError, match='unknown provider "nope"'):
        gs.get_geoscale_provider("nope")
    gdf = cells()
    gdf["country"] = ["N", "N", "N", "N", "S", "S", None]
    g = gs.geoscale_from_provider(gdf, geoframes=["country", "atom"], name="cells")
    assert g.meta["source"] == "custom" and len(g.geometry) == 7


def test_rules_registry_and_generic():
    gs.register_geoscale_rule("cap", "sum")
    assert gs.get_geoscale_rule("cap") == {"rule": "sum", "weight": None}
    d = pa.table({"atom": ["A1", "A2", "A3", "A4", "A5", "A6"],
                  "cap": [1.0, 2, 3, 4, 5, 6]})
    a = ns.recast(d, gs.geoscale_example(), target="state")
    assert a["cap"].to_pylist() == [3.0, 7.0, 11.0]
    gs.clear_geoscale_rules("cap")
    assert gs.get_geoscale_rule("cap") is None


def test_print_and_summary():
    s = gs.attach_geometry_geoscale(gs.geoscale_example(), cells())
    assert "Geometry: attached (7 features)" in str(s)
    sm = gs.geoscale_summary(s)
    assert sm.geometry == {"attached": True, "n_features": 7, "crs": "EPSG:4326"}
    assert "CROSS-CUTTING" in str(sm)
    assert str(sm).splitlines()[0] == "<summary of GeoScale 'example' >"
    assert repr(s["country", "N"]) == "<GeoScale[country/state/zone/atom] atoms=4>"


def test_rows_are_nested_by_default():
    df = pa.table({"country": ["B", None, "A", "B"], "atom": ["b1", "x", "a1", "b2"],
                   "km2": [1.0, 2, 3, 4]})
    g = gs.geoscale_from_leaftable(df, geoframes=["country", "atom"])
    assert g.leaftable["region"].to_pylist() == ["b1", "b2", "a1", "x"]
    given = gs.geoscale_from_leaftable(df, geoframes=["country", "atom"],
                                       row_order="given")
    assert given.leaftable["region"].to_pylist() == ["b1", "x", "a1", "b2"]
