# Immediate parent-child table between two geoframes

Immediate parent-child table between two geoframes

## Usage

``` r
geoscale_family(x, parent = NULL, child = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- parent, child:

  Geoframe names. Defaults to every adjacent pair in `x@geoframes`.

## Value

A `data.frame` with columns `parent_geoframe`, `parent`,
`child_geoframe`, `child`. Atoms unassigned at either geoframe are
omitted.

## Examples

``` r
gs <- geoscale_example()
geoscale_family(gs, "state", "zone")
#>   parent_geoframe parent child_geoframe child
#> 1           state     N1           zone    N1
#> 2           state     N2           zone    ZB
#> 3           state     S1           zone    ZB
#> 4           state     S1           zone    ZC
```
