# Icicle layout for a Geoscale

Rectangle coordinates for a level-by-level structure plot: one row per
level, each region a rectangle whose width is its share of the weight.
Exposed so the layout can be drawn with something other than ggplot2.

## Usage

``` r
geoscale_layout(x, weight = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- weight:

  Weight column. `NULL` uses the default.

## Value

A `data.frame` with columns `level`, `region`, `rank`, `xmin`, `xmax`,
`ymin`, `ymax`, `weight`, `share`.

## Examples

``` r
head(geoscale_layout(geoscale_example()))
#>     level region rank       xmin       xmax ymin ymax weight      share
#> 1 country      N    1 0.00000000 0.32258065    3  3.9   1000 0.32258065
#> 2 country      S    1 0.32258065 0.67741935    3  3.9   1100 0.35483871
#> 3   state     N1    2 0.00000000 0.09677419    2  2.9    300 0.09677419
#> 4   state     N2    2 0.09677419 0.32258065    2  2.9    700 0.22580645
#> 5   state     S1    2 0.32258065 0.67741935    2  2.9   1100 0.35483871
#> 6    zone     N1    3 0.00000000 0.09677419    1  1.9    300 0.09677419
```
