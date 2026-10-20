# Weight columns of a GeoScale

Weight columns of a GeoScale

## Usage

``` r
geoscale_weights(x)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

## Value

A character vector of weight column names (possibly empty).

## Examples

``` r
geoscale_weights(geoscale_example())
#> [1] "km2" "pop"
```
