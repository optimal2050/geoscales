# Weight columns of a Geoscale

Weight columns of a Geoscale

## Usage

``` r
geo_weights(x)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Value

A character vector of weight column names (possibly empty).

## Examples

``` r
geo_weights(geoscale_example())
#> [1] "km2" "pop"
```
