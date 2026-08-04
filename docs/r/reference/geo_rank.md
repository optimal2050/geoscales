# Level rank

Position of a level in the hierarchy: 1 is the coarsest.

## Usage

``` r
geo_rank(x, level)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- level:

  Character vector of level names.

## Value

An integer vector of ranks; `NA` for names that are not levels of `x`.

## Examples

``` r
gs <- geoscale_example()
geo_rank(gs, c("zone", "atom"))
#> [1] 3 4
```
