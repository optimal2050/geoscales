# Collapse a GeoScale to a coarser geoframe

Returns a new
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
whose atom layer is `geoframe`, dropping every finer geoframe. Weights
are summed over the collapsed atoms.

## Usage

``` r
prune_geoscale(x, geoframe, keep_geometry = !is.null(S7::prop(x, "geometry")))
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

- geoframe:

  The geoframe to become the new atom layer.

- keep_geometry:

  Dissolve and keep the attached geometry. Default: yes, when geometry
  is attached (needs the sf package; drops with a message otherwise).

## Value

A
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Details

The result is renamed `"name@geoframe"` (the
[`timescales::prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.html)
convention) with the parent recorded in `meta$parent_name`; every other
meta field (`crs`, `source`, `labels`, inherited `coverage`) is
preserved. Atoms with no code at `geoframe` are dropped, and that loss
is reflected in `meta$coverage` (see
[`geoscale_coverage()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_coverage.md)).
With geometry attached, the pruned atoms carry the dissolved (unioned)
geometry of their fine atoms unless `keep_geometry = FALSE`.

## Examples

``` r
prune_geoscale(geoscale_example(), "state")
#> GeoScale: example@state 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom 
#> Geoframes (2, coarsest first):
#>   - country (2)
#>     - state (3)
#> Atoms: 3
#> Weights: km2, pop (default: km2)
```
