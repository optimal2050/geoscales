# Register how a parameter should be recast

Records the rule (and optionally the weight) to use for a named value
column, so callers of
[`geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geo_recast.md)
need not repeat it. Downstream packages can register their own parameter
maps at load time.

## Usage

``` r
geo_register_rule(param, rule, weight = NULL)
```

## Arguments

- param:

  Name of the value column.

- rule:

  One of
  [`GEO_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEO_RULES.md).

- weight:

  Optional weight column name used by `sum` (down) and `weighted_mean`
  (up). `NULL` means the Geoscale's default weight.

## Value

Invisibly, the registered entry.

## Examples

``` r
geo_register_rule("capacity", "sum")
geo_register_rule("eff", "weighted_mean", weight = "pop")
geo_get_rule("eff")
#> $rule
#> [1] "weighted_mean"
#> 
#> $weight
#> [1] "pop"
#> 
```
