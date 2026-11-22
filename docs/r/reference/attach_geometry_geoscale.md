# Attach geometry to a GeoScale

Stores an `sfc` on the object, aligned to `@leaftable` row order.

## Usage

``` r
attach_geometry_geoscale(
  x,
  geom,
  by = NULL,
  geoframe = NULL,
  positional = FALSE
)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

- geom:

  An `sf` object or `sfc`. When `sf` with a code column, it is matched
  on `by`; when `sfc`, it must already be in `@leaftable` row order.

- by:

  Name of the code column in `geom` to match on. Defaults to the leaf
  geoframe, then `"region"`.

- geoframe:

  Geoframe that `geom`'s codes refer to. Defaults to the leaf geoframe.
  When coarser, each leaf inherits its parent's geometry.

- positional:

  Acknowledge a by-position bind. An `sfc` carries no codes, so nothing
  can check its order; when the constructor re-sorted the leaftable
  (`meta$row_permuted`) the caller's order is no longer the object's and
  the bind is refused. Set `TRUE` when the `sfc` is known to be in
  `@leaftable` order. Ignored for an `sf`, which is matched on `by`.

## Value

A
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
with `@geometry` populated.

## Examples

``` r
if (FALSE) { # \dontrun{
gs <- attach_geometry_geoscale(gs, sf_polygons, by = "adm0_a3")
} # }
```
