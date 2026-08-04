# Do two levels nest?

Tests whether every code at the finer level falls entirely within a
single code at the coarser level. Real hierarchies often fail this:
IDEEA's `reg32` code `APY` merges Andhra Pradesh with part of
Puducherry, so `reg35` does not nest inside `reg32`.

## Usage

``` r
geo_nests(x, parent, child)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- parent, child:

  Level names.

## Value

`TRUE` or `FALSE`. When `FALSE`, the offending child codes are attached
as the `"offenders"` attribute.

## Details

Nesting is *not* required by
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
—
[`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geo_recast.md)
routes through the atom layer and works either way. This function is a
diagnostic.

## Examples

``` r
gs <- geoscale_example()
geo_nests(gs, "country", "state")  # TRUE
#> [1] TRUE
geo_nests(gs, "state", "zone")     # FALSE - they cross-cut
#> [1] FALSE
#> attr(,"offenders")
#> [1] "ZB"
```
