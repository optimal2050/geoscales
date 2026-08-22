# Compute area weights from attached geometry

Adds an area column to `@leaftable`, measured on an equal-area
projection.

## Usage

``` r
add_area_geoscale(x, name = "km2", crs = "ESRI:54034")
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  with geometry attached.

- name:

  Name of the weight column to add.

- crs:

  Equal-area CRS used for the measurement. The default, World
  Cylindrical Equal Area, is global; a local equal-area projection is
  more accurate for a single region.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
with the area column added to `@leaftable` and registered in
`meta$weights`.

## Details

Areas are only as good as the geometry. Cartographic sources are
*generalised for display*: measured on Natural Earth at 1:110m, Chile
comes out 10.6% too large and Indonesia 3.2% too small against the same
data at 1:10m. Use the finest geometry available, and treat the result
as indicative rather than authoritative.

Geometry carrying no CRS is measured in its own planar units, with a
warning: reprojection is impossible, but a synthetic or teaching map is
still worth weighting by.

## Examples

``` r
if (FALSE) { # \dontrun{
gs <- add_area_geoscale(gs, name = "km2")
} # }
```
