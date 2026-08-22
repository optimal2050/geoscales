# Geoframe rank

Position of a geoframe in the hierarchy: 1 is the coarsest.

## Usage

``` r
geoscale_rank(x, geoframe)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- geoframe:

  Character vector of geoframe names.

## Value

An integer vector of ranks; `NA` for names that are not geoframes of
`x`.

## Examples

``` r
gs <- geoscale_example()
geoscale_rank(gs, c("zone", "atom"))
#> [1] 3 4
```
