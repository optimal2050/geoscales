# Add a weight column to a GeoScale

Declares one or more numeric weights over the leaves of an existing
`GeoScale`. A weight is what a quantity is divided by when a value
declared at a parent has to be shared out between its children, so a
hierarchy that ships with only `area` cannot apportion a demand or a
fleet sensibly; this is how `population`, `gdp` or any other basis is
added after the fact, without rebuilding the hierarchy.

## Usage

``` r
geoscale_add_weight(x, ..., default = NULL, overwrite = FALSE)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

- ...:

  Named weights, one per argument: either a numeric vector named by leaf
  code, or an unnamed numeric in leaftable row order. A single unnamed
  `data.frame` may be given instead, keyed by the leaf column with one
  or more numeric weight columns.

- default:

  Optional name of the weight to make the default, which must be one of
  the weights the result declares.

- overwrite:

  Replace a weight column that already exists. `FALSE` (the default)
  refuses instead.

## Value

The `GeoScale`, with the weights declared in `meta$weights` and the
columns in its leaftable.

## Examples

``` r
gs <- geoscale_example()
gs2 <- geoscale_add_weight(gs, population = c(A1 = 10, A2 = 20,
                                              A3 = 30, A4 = 40),
                           default = "population")
#> Error: weight `population` has no value for 3 leaf code(s): A5, A6, ROW
geoscale_weights(gs2)
#> Error: object 'gs2' not found
```
