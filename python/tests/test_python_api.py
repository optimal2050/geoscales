"""What the R goldens do not reach: backends, the store, payloads following
the engine, providers, the recast generic, printing, and the Python forms of
arguments."""
import nestedscales as ns
import pyarrow as pa
import pytest
from nestedscales import NestedScalesError

import geoscales as gs

CELLS = ["A1", "A2", "A3", "A4", "A5", "A6", "ROW"]


def boxes():
    shapely = pytest.importorskip("shapely")

    return [shapely.box(x, y, x + 1, y + 1)
            for x, y in [(0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (2, 1), (10, 10)]]


def cells():
    gpd = pytest.importorskip("geopandas")

    return gpd.GeoDataFrame({"cell": CELLS}, geometry=boxes(), crs=4326)


def labelled():
    x = gs.attach_labels_geoscale(gs.geoscale_example(), pa.table({
        "geoframe": ["country", "country", "state"], "region": ["N", None, "N1"],
        "label": ["North", "Country", "North one"]}))
    return gs.hide_geoframes_geoscale(x, "zone")


def test_backends_round_trip_their_type():
    pd = pytest.importorskip("pandas")
    pl = pytest.importorskip("polars")
    s = gs.geoscale_example()
    d = pa.table({"cell": ["A1", "A2", "A3", "A4", "A5", "A6"],
                  "cap": [1.0, 2, 3, 4, 5, 6]})
    ref = gs.recast_geoscale(d, s, target="country", rule="sum")
    got = gs.recast_geoscale(d.to_pandas(), s, target="country", rule="sum")
    assert isinstance(got, pd.DataFrame) and got["cap"].tolist() == [10.0, 11.0]
    got = gs.recast_from_geoleaves(pl.from_arrow(d), s, target="state", rule="sum")
    assert isinstance(got, pl.DataFrame) and got["cap"].to_list() == [3.0, 7.0, 11.0]
    assert ref["cap"].to_pylist() == [10.0, 11.0]
    lazy = gs.recast_from_geoleaves(pl.from_arrow(d).lazy(), s, target="state",
                                    rule="sum")
    assert isinstance(lazy, pl.LazyFrame)
    assert sorted(lazy.collect()["cap"].to_list()) == [3.0, 7.0, 11.0]
    down = gs.recast_to_geoleaves(pa.table({"country": ["N", "S"], "v": [10.0, 22]}),
                                  s, rule="sum")
    assert down.column_names == ["cell", "v", "weight"]
    assert down["v"].to_pylist() == pytest.approx([1, 2, 3, 4, 10, 12])


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


def test_payload_follows_the_engine_verbs():
    s = gs.attach_geometry_geoscale(labelled(), cells())
    f = ns.filter_scale(s, "country", "S")
    assert type(f) is gs.GeoScale and len(f.geometry) == 2
    assert f.geometry[0].bounds == (2, 0, 3, 1)
    assert gs.geoscale_geoframes(f, visible=False) == ["zone"]
    assert gs.geoscale_labels(f).to_pylist() == [
        {"geoframe": "country", "region": None, "variant": "label",
         "label": "Country"}]
    assert s["country", "S"] == f
    # one geoframe left: the hidden ones may not cover every geoframe
    one = ns.filter_scale(gs.hide_geoframes_geoscale(gs.geoscale_example(),
                                                     ["country", "state", "zone"]),
                          "cell", "A1")
    assert gs.geoscale_geoframes(one, visible=False) == ["country", "state", "zone"]


def test_geometry_by_position():
    gpd = pytest.importorskip("geopandas")
    s = gs.geoscale_example()
    assert s.meta["row_permuted"] is False
    g = gs.attach_geometry_geoscale(s, boxes(), crs=4326)
    assert g.meta["crs"] == "EPSG:4326" and g.geometry[6].bounds == (10, 10, 11, 11)
    g = gs.attach_geometry_geoscale(s, gpd.GeoSeries(boxes(), crs=3857))
    assert g.meta["crs"] == "EPSG:3857"
    df = pa.table({"country": ["B", None, "A", "B"], "cell": ["b1", "x", "a1", "b2"]})
    moved = gs.geoscale_from_leaftable(df, geoframes=["country", "cell"])
    assert moved.meta["row_permuted"] is True
    with pytest.raises(NestedScalesError, match="binds by position"):
        gs.attach_geometry_geoscale(moved, boxes()[:4])
    ok = gs.attach_geometry_geoscale(moved, boxes()[:4], positional=True)
    assert len(ok.geometry) == 4 and ok.meta["crs"] is None
    with pytest.raises(NestedScalesError, match="must be an `sf` or `sfc` object"):
        gs.attach_geometry_geoscale(s, 1)
    # geometry given to the constructor follows the rows it re-orders
    built = gs.geoscale_from_leaftable(df, geoframes=["country", "cell"],
                                       geometry=boxes()[:4])
    assert built.leaftable["cell"].to_pylist() == ["b1", "b2", "a1", "x"]
    assert [g.bounds[:2] for g in built.geometry] == [(0, 0), (1, 1), (0, 1), (1, 0)]


def test_store_round_trip_and_as_geoscale(tmp_path):
    s = gs.geoscale_example()
    ns.write_scale_dataset(pa.table({"cell": ["A1"], "v": [1.0]}), s, tmp_path / "g")
    back = gs.as_geoscale(ns.open_scale_dataset(tmp_path / "g").scale)
    assert isinstance(back, gs.GeoScale) and back == s
    with pytest.raises(NestedScalesError, match="must be a NestedScale"):
        gs.as_geoscale("example")
    x = labelled()
    core = ns.NestedScale(leaftable=x.leaftable, frames=x.frames, members=x.members,
                          leaf=x.leaf, meta=x.meta, labels=x.labels)
    again = gs.as_geoscale(core)
    assert again.leaf == "cell" and again.labels.equals(x.labels)
    assert gs.geoscale_id(again) == gs.geoscale_id(x) == ns.scale_id(core)
    assert gs.as_geoscale(x) is x


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
    g = gs.geoscale_from_provider(gdf, geoframes=["country", "cell"], name="cells")
    assert g.meta["source"] == "custom" and len(g.geometry) == 7
    assert gs.geoscale_leaf_column(g) == "cell"
    # rows that the constructor re-sorts keep their own shapes
    moved = gs.geoscale_from_provider(gdf.iloc[[4, 0, 5, 1, 2, 3]],
                                      geoframes=["country", "cell"], name="moved")
    assert moved.leaftable["cell"].to_pylist() == ["A5", "A6", "A1", "A2", "A3", "A4"]
    assert [g.bounds[:2] for g in moved.geometry] == [
        (2, 0), (2, 1), (0, 0), (1, 0), (0, 1), (1, 1)]


def test_rules_registry_and_generic():
    gs.register_geoscale_rule("cap", "sum")
    assert gs.get_geoscale_rule("cap") == {"rule": "sum", "weight": None}
    d = pa.table({"cell": ["A1", "A2", "A3", "A4", "A5", "A6"],
                  "cap": [1.0, 2, 3, 4, 5, 6]})
    a = ns.recast(d, gs.geoscale_example(), target="state")
    assert a["cap"].to_pylist() == [3.0, 7.0, 11.0]
    gs.clear_geoscale_rules(param="cap")
    assert gs.get_geoscale_rule("cap") is None
    act = gs.geoscale_rule_action("sum")
    assert act.to_pylist() == [{"rule": "sum", "up": "sum", "divisible": True,
                               "down": "split proportionally to the weight",
                               "action": "split"}]
    with pytest.raises(NestedScalesError, match="must be a character vector"):
        gs.geoscale_rule_action([])


# The printed forms are R's `print()` and `print(summary())` of the same
# object; R's `cat()` leaves a space at the end of the first two lines.
PRINTED = "\n".join([
    "GeoScale: example" + " ",
    "Description: Synthetic example: reused code, non-nesting geoframe pair, and "
    "an unassigned leaf" + " ",
    "Geoframes (4, coarsest first):",
    "  - country (2)  [1 leaf region(s) unassigned]",
    "    - state (3)  [1 leaf region(s) unassigned]",
    "      - zone (3)  [1 leaf region(s) unassigned]",
    "        - cell (7)",
    "Leaves: 7",
    "Weights: km2, pop (default: km2)",
    "Labels: country [label], state [label] (default: label)",
    "Hidden in plots: zone"])

SUMMARY = """\
<summary of GeoScale 'example' >
  desc:          Synthetic example: reused code, non-nesting geoframe pair, and an \
unassigned leaf
  geoframes:      country (2) / state (3) / zone (3) / cell (7)
  leaves:         7
  unassigned:     country (1), state (1), zone (1)
  weight totals:  km2 = 3,100, pop =   300  (default: km2)
  nesting:        country > state: nested
  nesting:        state > zone: CROSS-CUTTING (1 offender(s))
  nesting:        zone > cell: nested
  geometry:       none"""


def test_print_and_summary():
    x = labelled()
    assert str(x) == PRINTED
    assert str(gs.geoscale_summary(x)) == SUMMARY
    sm = gs.geoscale_summary(x)
    assert sm.n_leaves == 7 and sm.hidden == ["zone"]
    s = gs.attach_geometry_geoscale(gs.geoscale_example(), cells())
    assert str(s).splitlines()[-2:] == ["CRS: EPSG:4326",
                                        "Geometry: attached (7 features)"]
    sm = gs.geoscale_summary(s)
    assert sm.geometry == {"attached": True, "n_features": 7, "crs": "EPSG:4326"}
    assert "  geometry:       attached (7 features, EPSG:4326)" in str(sm)
    assert repr(s["country", "N"]) == "<GeoScale[country/state/zone/cell] leaves=4>"
    fine = gs.geoscale_from_leaftable(
        pa.table({"big": ["X", "X", "Y"], "id": ["p1", "p2", "p3"]}),
        geoframes=["big"], leaf="id")
    assert "Leaves: 3 (leaf column: id)" in str(fine)


def test_tree_lists_the_parts():
    tree = gs.geoscale_tree(labelled())
    lines = tree.lines(ascii=True)
    assert lines[0] == "<GeoScale> example@e4024622"
    assert lines[2].split() == ["|", "+-", "cell", "leaf", "column", "fixed"]
    assert lines[-1].split() == ["+-", "hidden", "chr", "[1]", "mutable",
                                 "hide_geoframes_geoscale()"]
    parts = tree.table["part"].to_pylist()
    assert parts.count("geometry") == 1 and parts.count("hidden") == 1


def test_rows_are_nested_by_default():
    df = pa.table({"country": ["B", None, "A", "B"], "cell": ["b1", "x", "a1", "b2"],
                   "km2": [1.0, 2, 3, 4]})
    g = gs.geoscale_from_leaftable(df, geoframes=["country", "cell"])
    assert g.leaftable["cell"].to_pylist() == ["b1", "b2", "a1", "x"]
    assert g.leaftable.column_names == ["country", "cell", "km2"]
    given = gs.geoscale_from_leaftable(df, geoframes=["country", "cell"],
                                       row_order="given")
    assert given.leaftable["cell"].to_pylist() == ["b1", "x", "a1", "b2"]
    assert given.meta["row_permuted"] is False


def test_class_and_equality():
    x = gs.geoscale_example()
    direct = gs.GeoScale(leaftable=x.leaftable, geoframes=x.geoframes,
                         members=x.members, meta=x.meta)
    assert direct == x and direct.leaf == "cell" and direct.hidden == ()
    assert direct.geoframes == direct.frames
    assert gs.hide_geoframes_geoscale(x, "zone") != x
    assert gs.show_geoframes_geoscale(gs.hide_geoframes_geoscale(x, "zone")) == x
    assert gs.geoscale_id(gs.hide_geoframes_geoscale(x, "zone")) == gs.geoscale_id(x)
    with pytest.raises(NestedScalesError, match="<nestedscales::NestedScale> object "
                                                "is invalid"):
        gs.GeoScale(leaftable=x.leaftable, geoframes=["country", "nope"],
                    members=x.members)
    with pytest.raises(NestedScalesError, match="<geoscales::GeoScale> object is "
                                                "invalid"):
        gs.GeoScale(leaftable=x.leaftable, geoframes=x.geoframes, members=x.members,
                    meta=x.meta, hidden=["planet"])
    with pytest.raises(NestedScalesError, match="subset a GeoScale as"):
        x["country"]


def test_python_forms_of_arguments():
    pd = pytest.importorskip("pandas")
    x = gs.geoscale_example()
    w = gs.geoscale_add_weight(x, pd.DataFrame({"cell": CELLS[::-1],
                                                "gdp": [7.0, 6, 5, 4, 3, 2, 1]}))
    assert w.leaftable["gdp"].to_pylist() == [1.0, 2, 3, 4, 5, 6, 7]
    assert gs.geoscale_weights(w) == ["km2", "pop", "gdp"]
    with pytest.raises(NestedScalesError, match="every weight must be named"):
        gs.geoscale_add_weight(x, [1, 2, 3, 4, 5, 6, 7])
    with pytest.raises(NestedScalesError, match="weight `gdp` must be numeric"):
        gs.geoscale_add_weight(x, gdp=["a"] * 7)
    lab = gs.attach_labels_geoscale(x, {"geoframe": ["country"], "region": ["N"],
                                        "label": ["North"]})
    assert gs.geoscale_label(lab, "N", "country") == ["North"]
    assert gs.geoscale_label(lab, None, "country") == ["country"]
    assert gs.geoscale_labels(lab).column_names == ["geoframe", "region", "variant",
                                                    "label"]
    with pytest.raises(NestedScalesError, match="`labels` must be a data.frame"):
        gs.attach_labels_geoscale(x, "North")
    assert gs.geoscale_geoframes(gs.hide_geoframes_geoscale(x, ("zone", "cell")),
                                 finest=True, visible=True) == "state"
    with pytest.raises(NestedScalesError, match="`geoframes` must be a character"):
        gs.hide_geoframes_geoscale(x, 1)
