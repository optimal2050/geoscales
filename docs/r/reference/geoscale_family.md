# Immediate parent-child table between two levels

Immediate parent-child table between two levels

## Usage

``` r
geoscale_family(x, parent = NULL, child = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- parent, child:

  Level names. Defaults to every adjacent pair in `x@levels`.

## Value

A `data.frame` with columns `parent_level`, `parent`, `child_level`,
`child`. Atoms unassigned at either level are omitted.

## Examples

``` r
gs <- geoscale_example()
geoscale_family(gs, "state", "zone")
#>   parent_level parent child_level child
#> 1        state     N1        zone    N1
#> 2        state     N2        zone    ZB
#> 3        state     S1        zone    ZB
#> 4        state     S1        zone    ZC
```
