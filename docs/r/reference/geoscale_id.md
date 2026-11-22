# The identity of a GeoScale

Gives the identity of a
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md):
its name and a hash of its structure, as `"<name>@<hash>"`. The hash is
computed from the geoframes and the memberships of the regions, not from
weights, labels or geometry, so two objects with the same structure and
different weights have the same hash, and a subset differs from the
object it was taken from.

## Usage

``` r
geoscale_id(gs)
```

## Arguments

- gs:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Value

A single string.

## See also

[`geoscale_tree()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_tree.md)

## Examples

``` r
gs <- geoscale_example()
geoscale_id(gs)
#> [1] "example@e4024622"
geoscale_id(filter_geoscale(gs, "country", "N"))
#> [1] "example[country:N]@e835799a"
```
