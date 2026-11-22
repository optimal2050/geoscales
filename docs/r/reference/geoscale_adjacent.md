# Adjacency between the features of a geoframe

Builds the neighbour matrix of a geoframe from attached geometry: which
of its codes share a border with which. The result is what
`nestedscales::cluster_contiguous(adjacency =)` consumes.

## Usage

``` r
geoscale_adjacent(
  x,
  geoframe = NULL,
  within = NULL,
  contiguity = c("queen", "rook"),
  isolated = c("none", "nearest"),
  precision = 0
)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
  with geometry attached (see
  [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md)).

- geoframe:

  Geoframe whose features are compared. Defaults to the leaf geoframe.
  Geometry is dissolved to it first, so any geoframe works.

- within:

  Optional coarser geoframe whose boundaries cut edges: two features in
  different `within` codes are never neighbours. `NULL` (default) keeps
  every border. Use it to confine a clustering to a parent, which also
  sets the floor on the number of groups obtainable — a clustering
  cannot merge below the number of connected components.

- contiguity:

  `"queen"` (default) counts contact of any dimension, so features
  meeting at a single corner are neighbours; `"rook"` requires a shared
  border of non-zero length. On a gridded or hexagonal lattice the two
  differ, and on real coastlines they occasionally do too, where three
  borders meet at a point.

- isolated:

  What to do with a feature that borders nothing — an island, an
  exclave, or a feature cut off by `within`. `"none"` (default) leaves
  it isolated. `"nearest"` joins it to the closest other feature, which
  is what a clustering needs to avoid a group of one. A distance
  tolerance is deliberately not offered: one wide enough to bridge a
  strait also links every pair of cells one apart on a lattice.

- precision:

  Optional GEOS precision passed to
  [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md),
  for a constructed lattice whose shared vertices do not coincide
  exactly.

## Value

A logical matrix, symmetric, with a `FALSE` diagonal and both dimnames
the codes at `geoframe` in member order.

## Details

`isolated` is resolved **after** `within` has cut its edges, and the
nearest feature is sought among those `within` allows. Fixing isolation
first would hand a feature a neighbour that the mask then takes away
again, leaving it isolated after all.

A feature whose `within` code is `NA` is its own group: unassigned codes
do not silently pool.

On geographic (longitude/latitude) coordinates the two `contiguity`
settings do not use the same engine: `"queen"` goes through
[`sf::st_touches()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html),
which is spherical under s2, while `"rook"` goes through
[`sf::st_relate()`](https://r-spatial.github.io/sf/reference/st_relate.html),
which has no spherical implementation and warns that it assumes the
coordinates are planar. For contiguity the difference is immaterial –
whether two polygons share a border does not depend on the metric – but
project to an equal-area or local CRS first if the warning matters or
the geometry crosses the antimeridian.

## See also

[`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md),
[`geoscale_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_leaftable.md)

## Examples

``` r
if (FALSE) { # \dontrun{
a <- geoscale_adjacent(gs, geoframe = "region")
sum(a) / 2                                    # number of borders
geoscale_adjacent(gs, "region", within = "zone")        # confined
geoscale_adjacent(gs, "region", contiguity = "rook")    # edges only
} # }
```
