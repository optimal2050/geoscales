# Map coordinates to the regions that contain them

The spatial twin of
[`timescales::datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.html):
raw observations enter the structure here. Each point is matched to the
region at `geoframe` (the atoms by default) whose geometry contains it;
points outside every region return `NA`. A point exactly on a shared
border is assigned to the first matching region in the object's
canonical order.

## Usage

``` r
coords_to_region(x, gs, geoframe = NULL, coords = c("lon", "lat"), crs = 4326)
```

## Arguments

- x:

  An `sf`/`sfc` object of points, or a data.frame with coordinate
  columns.

- gs:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  with geometry attached (see
  [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md)).

- geoframe:

  Geoframe to resolve to; `NULL` (default) uses the finest geoframe.

- coords:

  Names of the coordinate columns when `x` is a plain data.frame
  (x/longitude first, y/latitude second).

- crs:

  Coordinate reference system of those columns (default WGS84); points
  are transformed to the geometry's CRS before matching.

## Value

A character vector of region codes, one per row/point of `x`.

## Examples

``` r
if (FALSE) { # \dontrun{
obs <- data.frame(lon = c(-21.9, -18.1), lat = c(64.1, 65.7), v = 1:2)
obs$region <- coords_to_region(obs, gs)
} # }
```
