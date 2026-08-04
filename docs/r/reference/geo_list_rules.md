# List registered rules

List registered rules

## Usage

``` r
geo_list_rules()
```

## Value

A `data.frame` with columns `param`, `rule` and `weight`.

## Examples

``` r
geo_register_rule("invcost", "weighted_mean", weight = "km2")
geo_list_rules()
#>     param          rule weight
#> 1  demand           sum   <NA>
#> 2 invcost weighted_mean    km2
```
