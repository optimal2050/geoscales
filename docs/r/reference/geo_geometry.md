# Geometry dissolved to a level

Unions the atom geometries within each code at `level`.

## Usage

``` r
geo_geometry(x, level = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  with geometry attached.

- level:

  Level to dissolve to. Defaults to the atom level.

## Value

An `sf` object with a code column named `level` plus `geometry`.

## Examples

``` r
if (FALSE) { # \dontrun{
geo_geometry(gs, level = "reg32")
} # }
```
