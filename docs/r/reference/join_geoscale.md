# Attach Geoscale metadata to region-keyed data

Joins hierarchy columns onto `x`: one column per coarser level (the
membership of each keyed code), plus `weight` (summed atom weights) and
`share` (weights normalised over the level). The spatial mirror of
[`timescales::join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.html).

## Usage

``` r
join_geoscale(
  x,
  gs,
  key = NULL,
  level = NULL,
  levels = NULL,
  weight = NULL,
  as_factor = TRUE
)
```

## Arguments

- x:

  A `data.frame` keyed by region code.

- gs:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- key:

  Name of the code column in `x`. Defaults to `level` when that column
  exists, otherwise `"region"`.

- level:

  Level the codes belong to. Inferred when exactly one of the object's
  level names is a column of `x`.

- levels:

  Coarser levels to attach. Default: all levels coarser than `level`.

- weight:

  Weight column for `weight`/`share`; `NULL` uses the default weight
  (when the object has none, the columns are skipped).

- as_factor:

  Attach the level columns as factors ordered by the object's member
  vocabulary (default `TRUE`).

## Value

`x` with the requested columns appended.

## Examples

``` r
gs <- geoscale_example()
x <- data.frame(state = c("N1", "N2", "S1"), v = 1:3)
join_geoscale(x, gs)
#>   state v country weight     share
#> 1    N1 1       N    300 0.1428571
#> 2    N2 2       N    700 0.3333333
#> 3    S1 3       S   1100 0.5238095
```
