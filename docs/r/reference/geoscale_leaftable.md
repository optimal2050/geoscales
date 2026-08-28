# The leaftable of a Geoscale

The one-row-per-atom table the geoscale is built on, as a plain
`data.frame` — the exported accessor to prefer over reaching for
`x@leaftable` (the twin of
[`timescales::calendar_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_leaftable.html)).
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) and
[`ggplot2::fortify()`](https://ggplot2.tidyverse.org/reference/fortify.html)
on a Geoscale are equivalent, so `ggplot(gs) + geom_*()` pipelines work
directly.

## Usage

``` r
geoscale_leaftable(x)

# S3 method for class 'Geoscale'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)

# S3 method for class '`geoscales::Geoscale`'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)

# S3 method for class 'Geoscale'
fortify(model, data, ...)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- row.names, optional:

  Ignored (S3 signature compatibility).

- ...:

  Ignored.

- model:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  (the
  [`fortify()`](https://ggplot2.tidyverse.org/reference/fortify.html)
  generic's argument name).

- data:

  Ignored (S3 signature compatibility).

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
head(as.data.frame(geoscale_example()))
#>   country state zone atom km2 pop region
#> 1       N    N1   N1   A1 100  10     A1
#> 2       N    N1   N1   A2 200  90     A2
#> 3       N    N2   ZB   A3 300  30     A3
#> 4       N    N2   ZB   A4 400  70     A4
#> 5       S    S1   ZB   A5 500  50     A5
#> 6       S    S1   ZC   A6 600  50     A6
```
