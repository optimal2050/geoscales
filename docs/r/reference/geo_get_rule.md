# Look up a registered rule

Look up a registered rule

## Usage

``` r
geo_get_rule(param)
```

## Arguments

- param:

  Name of the value column.

## Value

A list with elements `rule` and `weight`, or `NULL` if `param` has not
been registered.

## Examples

``` r
geo_register_rule("demand", "sum")
geo_get_rule("demand")
#> $rule
#> [1] "sum"
#> 
#> $weight
#> NULL
#> 
geo_get_rule("not_registered")
#> NULL
```
