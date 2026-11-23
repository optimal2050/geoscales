# geoscales (Python)

Python binding of the R package [geoscales](https://github.com/optimal2050/geoscales): regions and spatial hierarchies for modeling, built on [nestedscales](https://github.com/optimal2050/nestedscales). A GeoScale records its finest regions (the leaves) and their membership in coarser geoframes -- nested, cross-cutting or partial -- with area or population weights, labels and optional geometry; data is recast between geoframes through the leaves. This binding follows the R package at version 0.8.0 and needs nestedscales 0.3.0 or later.

A *geoframe* is one level of a GeoScale, a *region* one member of a geoframe, a *leaf* a region of the finest layer and one row of the leaftable, and the *leaf column* the column of the leaftable that identifies the leaves. The leaf column is the finest geoframe's own column unless the leaves are finer than the finest geoframe. `key=` names the column of a data table that holds the codes, and "unit" means a unit of measure only.

```python
import pyarrow as pa
import geoscales as gs

s = gs.geoscale_example()
print(s)

d = pa.table({"cell": ["A1", "A2", "A3", "A4", "A5", "A6"],
              "cap": [1.0, 2, 3, 4, 5, 6]})
gs.recast_geoscale(d, s, target="country", rule="sum")              # aggregate
gs.recast_geoscale(pa.table({"country": ["N", "S"], "cap": [10.0, 20]}), s,
                   target="state", rule="sum", weight="pop")        # split by weight
gs.join_geoscale(d, s, geoframes=True)                              # attach codes

gs.geoscale_id(s)            # "example@e4024622", the same string as in R
print(gs.geoscale_tree(s))   # the parts of the GeoScale: fixed, derived or mutable
```

## One API, two languages

Every function has the same name and the same arguments as in R, and is a free function (`gs.geoscale_geoframes(s)`). Error and warning messages are the R package's, verbatim. Python-specific spellings:

* R's `summary(x)` is `geoscale_summary(x)`, and `print(x)` is `str(x)`;
* R's `x@leaf` is `x.leaf`, and `x@geoframes` is `x.geoframes`;
* a named numeric vector is a dict (`geoscale_add_weight(s, gdp={"A1": 1.0, ...})`);
* an `sf` object is a geopandas `GeoDataFrame` and an `sfc` a `GeoSeries` or a sequence of shapely geometries, whose CRS `attach_geometry_geoscale(crs=)` gives;
* tables are returned as `pyarrow.Table`, or in the type of the data passed in (pandas, polars, a lazy frame);
* R's deprecated argument names `from` and `to` are not accepted: the arguments are `source` and `target`.

## Labels, identity, parts

`attach_labels_geoscale()` adds display names for the regions of any geoframe, in named variants; a row with a null `region` names the geoframe itself. `geoscale_labels()` returns the table (`geoframe`, `region`, `variant`, `label`) and `geoscale_label()` looks names up, giving the code where there is no label. Subsets, prunes and zooms keep the labels of what remains.

`geoscale_id()` is the identity of a GeoScale, `"<name>@<hash>"`: the hash covers the leaf column, the geoframes and the leaf-to-geoframe memberships, and is the same in R and Python for the same GeoScale. `geoscale_tree()` lists the parts of a GeoScale and marks each `fixed` (it enters the identity), `derived` or `mutable`, naming the function that changes it. `geoscale_leaf_column()` gives the name of the leaf column.

`geoscale_add_weight()` declares a further numeric weight over the leaves of an existing GeoScale, and `geoscale_rule_action()` reports what each recast rule does going up and going down. `hide_geoframes_geoscale()` marks geoframes that exist for calculation only, `show_geoframes_geoscale()` reverses it and `geoscale_geoframes(visible=)` lists either set; recasts, joins and navigation see every geoframe.

## Geometry

Geometry is optional: `pip install geoscales[geo]` adds shapely, pyproj and geopandas, the counterparts of sf. A GeoScale holds one shapely geometry per leaf in leaftable row order, with its CRS in `meta["crs"]`; geometry follows filtering, and pruning dissolves it per code. A geometry given without codes binds by position, which `attach_geometry_geoscale()` refuses when the rows were re-sorted at construction unless `positional=True`. The Natural Earth provider downloads the Natural Earth shapefiles from naciscdn.org on first use (cached under `~/.cache/geoscales`); R reads them from rnaturalearth's data packages.

## Files shared with R

A GeoScale is written with `nestedscales.write_scale()` as a definition file of schema version 2, the same file the R package writes. A definition holds the tables and the metadata of a GeoScale: the leaf column, the geoframes, the members, the leaftable, the labels and `meta`. It holds neither the geometry nor the hidden geoframes, and neither binding registers the GeoScale class for reading, so a definition is read as the core scale and rebuilt:

```python
import nestedscales as ns

ns.write_scale(s, "example.json")
back = gs.as_geoscale(ns.read_scale("example.json", cls="core"))
gs.geoscale_id(back) == gs.geoscale_id(s)
```

`as_geoscale()` also restores a GeoScale from a scale reopened with `nestedscales.open_scale_dataset()`.

## Scope

Ported: the class, `geoscale_from_leaftable()` / `geoscale_build()` / `geoscale_example()`, providers (`geoscale_from_provider()`, the Natural Earth provider), navigation, `filter_geoscale()` / `prune_geoscale()` / `zoom_geoscale()`, `recast_geoscale()`, `recast_to_geoleaves()` and `recast_from_geoleaves()` (observed regions only, as in R), `recast_pairs()`, crosswalks, rules, `join_geoscale()`, labels, `geoscale_id()`, `geoscale_tree()`, weights added to a built GeoScale, hidden geoframes, and geometry: `attach_geometry_geoscale()`, `geoscale_geometry()` (dissolve), `add_area_geoscale()` (km2 in an equal-area CRS) and `coords_to_region()`.

R only for now: plotting (`gg_geoscale()`, `geom_geoscale()`, `theme_geoscale()`, `geoscale_layout()`), `geoscale_adjacent()` and `check_geometry_geoscale()`.

## Provenance

The R package is the original implementation. This Python binding was translated from it with the AI coding assistant Claude Code, function by function, and is checked against results generated from the R sources (see Verification below). Human review and contributions are very welcome; issues and pull requests go to <https://github.com/optimal2050/geoscales>.

## Verification

* `specs/golden/` -- the language-neutral cases the R suite also replays;
* `specs/json/` -- a broad set written by `tools/specs/make_json_goldens.R` from the R sources (with nestedscales and sf): construction, navigation, every recast route, maps, joins, labels, identity, parts, weights, hidden geoframes, and geometry on synthetic squares (compared as type, area and bounds), with every warning and error message;
* `python/tests/r/roundtrip.R` -- definition files in both directions: R writes and Python reads, Python writes and R reads, with identical tables, metadata and identity.

```sh
python -m venv .venv
.venv/Scripts/python -m pip install -e "../../nestedscales/python" -e ".[test,geo]"
.venv/Scripts/python -m pytest -q
Rscript tools/specs/make_goldens.R           # from the repository root
Rscript tools/specs/make_json_goldens.R      # from the repository root
```

The round trip with R runs when `Rscript` finds pkgload, jsonlite and nestedscales 0.3.0 or later; the environment variable `GEOSCALES_RSCRIPT` names another `Rscript`.
