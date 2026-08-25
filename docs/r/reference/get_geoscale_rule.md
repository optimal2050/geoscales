# Look up a registered rule

Look up a registered rule

## Usage

``` r
get_geoscale_rule(param)
```

## Arguments

- param:

  Name of the value column.

## Value

A list with elements `rule` and `weight`, or `NULL` if `param` has not
been registered.

## Examples

``` r
register_geoscale_rule("demand", "sum")
get_geoscale_rule("demand")
#> $rule
#> [1] "sum"
#> 
#> $weight
#> NULL
#> 
get_geoscale_rule("not_registered")
#> NULL
```
