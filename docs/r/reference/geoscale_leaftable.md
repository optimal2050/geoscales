# The leaftable of a Geoscale

The one-row-per-atom table the geoscale is built on, as a plain
`data.frame` — the exported accessor to prefer over reaching for
`x@leaftable` (the twin of
[`timescales::calendar_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_leaftable.html)).

## Usage

``` r
geoscale_leaftable(x)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Value

A `data.frame`: one row per atom, with the geoframe columns plus any
weight columns.

## Examples

``` r
head(geoscale_leaftable(geoscale_example()))
#>   country state zone atom km2 pop region
#> 1       N    N1   N1   A1 100  10     A1
#> 2       N    N1   N1   A2 200  90     A2
#> 3       N    N2   ZB   A3 300  30     A3
#> 4       N    N2   ZB   A4 400  70     A4
#> 5       S    S1   ZB   A5 500  50     A5
#> 6       S    S1   ZC   A6 600  50     A6
```
