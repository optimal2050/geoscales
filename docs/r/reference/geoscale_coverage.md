# Sampled coverage of a Geoscale

The spatial mirror of a partial calendar's `year_fraction`: the fraction
of the ROOT parent's weight totals that this object still carries.
[`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md)
(and
[`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md)
when it drops uncovered atoms) record it in `meta$coverage`; an object
that was never sampled reports `1` for every weight.

## Usage

``` r
geoscale_coverage(x, weight = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- weight:

  A single weight name for a scalar answer; `NULL` (default) returns the
  named vector over all declared weights.

## Value

A named numeric over the declared weights, or a single unnamed numeric
when `weight` is given.

## Examples

``` r
gs <- geoscale_example()
geoscale_coverage(gs)                            # all 1 -- not a sample
#> km2 pop 
#>   1   1 
geoscale_coverage(filter_geoscale(gs, "country", "N"))
#>       km2       pop 
#> 0.3225806 0.6666667 
```
