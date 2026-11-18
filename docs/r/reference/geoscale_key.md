# The atom key of a GeoScale

The name of the leaftable column that identifies the atoms. It is the
finest geoframe unless the scale was built with another `key`, and it is
the name the atom column carries in the results of
[`recast_to_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md).

## Usage

``` r
geoscale_key(x)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Value

A single string.

## Examples

``` r
geoscale_key(geoscale_example())
#> [1] "atom"
```
