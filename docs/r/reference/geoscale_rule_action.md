# What a rule does in each direction

Every rule in
[`GEOSCALE_RULES`](https://optimal2050.github.io/geoscales/r/reference/GEOSCALE_RULES.md)
defines behaviour in both directions, and the direction follows the
geoframe ranks. This reports, per rule, what going **up** and going
**down** mean, and whether a parent's value is therefore divisible
between its children: only `sum` is, because only `sum` splits a
quantity. A rate, a price or a region-invariant scalar is replicated
instead – the same value holds for every child – while `sd` and the two
share rules have no downward meaning and are reported as `NA` rather
than guessed at.

## Usage

``` r
geoscale_rule_action(rule = GEOSCALE_RULES)
```

## Arguments

- rule:

  Character vector of rule names; defaults to every rule.

## Value

A `data.frame` with one row per `rule`, in the order given, and columns
`rule`, `up`, `down`, `divisible` (`NA` where the rule has no downward
meaning) and `action`, one of `"split"`, `"replicate"` or `"none"`.

## Details

A downstream package uses this to decide, column by column, what a
partial selection of children does to a parent's value, without asking
its caller.

## Examples

``` r
geoscale_rule_action()
#>            rule                  up                               down
#> 1           sum                 sum split proportionally to the weight
#> 2 weighted_mean       weighted mean                               copy
#> 3          mean                mean                               copy
#> 4          copy    the common value                               copy
#> 5            sd  standard deviation                               <NA>
#> 6         share share within parent                               <NA>
#> 7      logshare share within parent                               <NA>
#>   divisible    action
#> 1      TRUE     split
#> 2     FALSE replicate
#> 3     FALSE replicate
#> 4     FALSE replicate
#> 5        NA      none
#> 6        NA      none
#> 7        NA      none
geoscale_rule_action("sum")$divisible
#> [1] TRUE
```
