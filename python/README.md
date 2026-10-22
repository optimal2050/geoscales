# geoscales (Python)

Python binding of the R package
[geoscales](https://github.com/optimal2050/geoscales): regions and spatial
hierarchies for modeling, built on
[nestedscales](https://github.com/optimal2050/nestedscales). A GeoScale
records its atoms and their membership in coarser geoframes -- nested,
cross-cutting or partial -- with area or population weights and optional
geometry; data is recast between geoframes through the atoms.

```python
import pyarrow as pa
import geoscales as gs

s = gs.geoscale_example()
d = pa.table({"atom": ["A1", "A2", "A3", "A4", "A5", "A6"],
              "cap": [1.0, 2, 3, 4, 5, 6]})
gs.recast_geoscale(d, s, target="country", rule="sum")
gs.recast_geoscale(pa.table({"country": ["N", "S"], "cap": [10.0, 20]}), s,
                   target="state", rule="sum", weight="pop")
gs.join_geoscale(d, s, geoframes=True)
```

## Scope

Ported: the class, `geoscale_from_leaftable()` / `geoscale_build()` /
`geoscale_example()`, providers (`geoscale_from_provider()`, the Natural
Earth provider), navigation, `filter_geoscale()` / `prune_geoscale()` /
`zoom_geoscale()`, `recast_geoscale()`, the geoatom halves (observed regions
only, as in R), `recast_pairs()`, crosswalks, rules, `join_geoscale()`, and
geometry: `attach_geometry_geoscale()`, `geoscale_geometry()` (dissolve),
`add_area_geoscale()` (km2 in an equal-area CRS) and `coords_to_region()`.
Plotting stays in R.

Function names match R; R's `from`/`to` arguments are `source`/`target`
and the `clear_*` functions take `name`, as in nestedscales. Error and
warning messages are R's.

Geometry is optional: `pip install geoscales[geo]` adds shapely, pyproj and
geopandas, the counterparts of sf. A GeoScale holds one shapely geometry per
atom in leaftable row order, with its CRS in `meta["crs"]`; geometry
follows filtering, and pruning dissolves it. The Natural Earth provider
downloads the Natural Earth shapefiles from naciscdn.org on first use
(cached under `~/.cache/geoscales`); R reads them from rnaturalearth's data
packages.

`as_geoscale()` restores a GeoScale from a scale reopened with
`nestedscales.open_scale_dataset()`.

## Provenance

The R package is the original implementation. This Python binding was
translated from it with the AI coding assistant Claude Code, function by
function, and is checked against results generated from the R sources
(see Verification below). Human review and contributions are very
welcome; issues and pull requests go to
<https://github.com/optimal2050/geoscales>.

## Verification

* `specs/golden/` -- the language-neutral cases the R suite also replays;
* `specs/json/` -- a broad set written by `tools/specs/make_json_goldens.R`
  from the R sources (with nestedscales as submitted to CRAN and sf):
  construction, navigation, every recast route, maps, joins, and geometry
  on synthetic squares (compared as type, area and bounds).

```sh
python -m venv .venv
.venv/Scripts/python -m pip install -e "../../nestedscales/python" -e ".[test,geo]"
.venv/Scripts/python -m pytest -q
Rscript tools/specs/make_json_goldens.R      # from the repository root
```
