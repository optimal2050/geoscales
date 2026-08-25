# Geometry dissolved to a geoframe

Unions the atom geometries within each code at `geoframe`.

## Usage

``` r
geoscale_geometry(x, geoframe = NULL, precision = 0)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  with geometry attached.

- geoframe:

  Geoframe to dissolve to. Defaults to the atom geoframe.

- precision:

  Optional GEOS precision for snapping near-coincident boundaries before
  the union (passed to
  [`sf::st_set_precision()`](https://r-spatial.github.io/sf/reference/st_precision.html);
  e.g. `1e6` snaps coordinates to a `1e-6` grid, followed by
  [`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)).
  Default `0` = off — geometry is never silently altered. Use when a
  constructed lattice shows phantom internal borders after dissolve:
  that means adjacent atoms' shared vertices do not coincide exactly,
  and the honest fix is at the source; `precision=` is the workaround.

## Value

An `sf` object with a code column named `geoframe` plus `geometry`.

## Examples

``` r
if (FALSE) { # \dontrun{
geoscale_geometry(gs, geoframe = "reg32")
} # }
```
