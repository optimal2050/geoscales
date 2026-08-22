# Geometry dissolved to a geoframe

Unions the atom geometries within each code at `geoframe`.

## Usage

``` r
geoscale_geometry(x, geoframe = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  with geometry attached.

- geoframe:

  Geoframe to dissolve to. Defaults to the atom geoframe.

## Value

An `sf` object with a code column named `geoframe` plus `geometry`.

## Examples

``` r
if (FALSE) { # \dontrun{
geoscale_geometry(gs, geoframe = "reg32")
} # }
```
