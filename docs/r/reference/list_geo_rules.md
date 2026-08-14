# List registered rules

List registered rules

## Usage

``` r
list_geo_rules()
```

## Value

A `data.frame` with columns `param`, `rule` and `weight`.

## Examples

``` r
register_geo_rule("invcost", "weighted_mean", weight = "km2")
list_geo_rules()
#>     param          rule weight
#> 1  demand           sum   <NA>
#> 2 invcost weighted_mean    km2
```
