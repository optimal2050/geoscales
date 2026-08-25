# Register how a parameter should be recast

Records the rule (and optionally the weight) to use for a named value
column, so callers of
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
need not repeat it. Downstream packages can register their own parameter
maps at load time.

## Usage

``` r
register_geoscale_rule(param, rule, weight = NULL)
```

## Arguments

- param:

  Name of the value column.

- rule:

  One of
  [`GEOSCALE_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEOSCALE_RULES.md).

- weight:

  Optional weight column name used by `sum` (down) and `weighted_mean`
  (up). `NULL` means the Geoscale's default weight.

## Value

Invisibly, the registered entry.

## Examples

``` r
register_geoscale_rule("capacity", "sum")
register_geoscale_rule("eff", "weighted_mean", weight = "pop")
get_geoscale_rule("eff")
#> $rule
#> [1] "weighted_mean"
#> 
#> $weight
#> [1] "pop"
#> 
```
