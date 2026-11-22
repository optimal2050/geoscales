# The leaf column of a GeoScale

The name of the leaftable column that identifies the leaves. It is the
finest geoframe unless the scale was built with another `leaf`, and it
is the name the leaf column carries in the results of
[`recast_to_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md).

## Usage

``` r
geoscale_leaf_column(x)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Value

A single string.

## Details

An object saved by an earlier version, which stored the name as `key`,
is read as well.

## Examples

``` r
geoscale_leaf_column(geoscale_example())
#> [1] "cell"
```
