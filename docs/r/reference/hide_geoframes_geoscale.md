# Hide geoframes from plots

A geoframe can be needed for calculation without being something to
show: grid cells that carry the weights, or clusters used to build a
crosswalk. `hide_geoframes_geoscale()` marks such geoframes, and
[`gg_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/gg_geoscale.md),
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) then leave
them out unless asked. Nothing else changes: recasts, joins and
navigation use every geoframe as before, and the identity of the object
([`geoscale_id()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_id.md))
is the same.

## Usage

``` r
hide_geoframes_geoscale(x, geoframes)

show_geoframes_geoscale(x, geoframes = NULL)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

- geoframes:

  Character vector of geoframe names. In `show_geoframes_geoscale()`,
  `NULL` (default) shows all.

## Value

The `GeoScale`, with its hidden set changed. The current sets are read
with `geoscale_geoframes(x, visible = TRUE)` and
`geoscale_geoframes(x, visible = FALSE)`.

## Details

`show_geoframes_geoscale()` reverses it, for the named geoframes or for
all of them. At least one geoframe always stays visible.

## See also

[`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md),
[`gg_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/gg_geoscale.md)

## Examples

``` r
gs <- hide_geoframes_geoscale(geoscale_example(), "cell")
gs
#> GeoScale: example 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned leaf 
#> Geoframes (4, coarsest first):
#>   - country (2)  [1 leaf region(s) unassigned]
#>     - state (3)  [1 leaf region(s) unassigned]
#>       - zone (3)  [1 leaf region(s) unassigned]
#>         - cell (7)
#> Leaves: 7
#> Weights: km2, pop (default: km2)
#> Hidden in plots: cell
geoscale_geoframes(gs, visible = TRUE)
#> [1] "country" "state"   "zone"   
geoscale_geoframes(gs, visible = FALSE)
#> [1] "cell"
# calculations still reach the hidden geoframe
geoscale_regions(gs, "cell")
#> [1] "A1"  "A2"  "A3"  "A4"  "A5"  "A6"  "ROW"
geoscale_geoframes(show_geoframes_geoscale(gs), visible = FALSE)
#> character(0)
```
