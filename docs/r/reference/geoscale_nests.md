# Do two geoframes nest?

Tests whether every code at the finer geoframe falls entirely within a
single code at the coarser geoframe. Real hierarchies often fail this:
IDEEA's `reg32` code `APY` merges Andhra Pradesh with part of
Puducherry, so `reg35` does not nest inside `reg32`.

## Usage

``` r
geoscale_nests(x, parent, child)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- parent, child:

  Geoframe names.

## Value

`TRUE` or `FALSE`. When `FALSE`, the offending child codes are attached
as the `"offenders"` attribute.

## Details

Nesting is *not* required by
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
—
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
routes through the atom layer and works either way. This function is a
diagnostic.

## Examples

``` r
gs <- geoscale_example()
geoscale_nests(gs, "country", "state")  # TRUE
#> [1] TRUE
geoscale_nests(gs, "state", "zone")     # FALSE - they cross-cut
#> [1] FALSE
#> attr(,"offenders")
#> [1] "ZB"
```
