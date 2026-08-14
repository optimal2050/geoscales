# Attach geometry to a Geoscale

Stores an `sfc` on the object, aligned to `@leaves` row order.

## Usage

``` r
attach_geometry_geoscale(x, geom, by = NULL, level = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- geom:

  An `sf` object or `sfc`. When `sf` with a code column, it is matched
  on `by`; when `sfc`, it must already be in `@leaves` row order.

- by:

  Name of the code column in `geom` to match on. Defaults to the atom
  level, then `"region"`.

- level:

  Level that `geom`'s codes refer to. Defaults to the atom level. When
  coarser, each atom inherits its parent's geometry.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
with `@geometry` populated.

## Examples

``` r
if (FALSE) { # \dontrun{
gs <- attach_geometry_geoscale(gs, sf_polygons, by = "adm0_a3")
} # }
```
