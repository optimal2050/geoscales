# Weight shares within a level

Normalised weights, either of the whole object or within each parent
group.

## Usage

``` r
geoscale_share(x, level, weight = NULL, within = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- level:

  Level to report shares for.

- weight:

  Weight column. `NULL` uses the default.

- within:

  Optional coarser level to normalise within. `NULL` normalises over the
  whole object.

## Value

A `data.frame` with a code column named `level` (matching the convention
of
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)),
the weight, and `share`. When `within` is given, a column of that name
carries the parent code.

## Examples

``` r
gs <- geoscale_example()
geoscale_share(gs, "state", weight = "km2")
#>   state  km2     share
#> 1    N1  300 0.1428571
#> 2    N2  700 0.3333333
#> 3    S1 1100 0.5238095
geoscale_share(gs, "state", weight = "km2", within = "country")
#>   state country  km2 share
#> 1    N1       N  300   0.3
#> 2    N2       N  700   0.7
#> 3    S1       S 1100   1.0
```
