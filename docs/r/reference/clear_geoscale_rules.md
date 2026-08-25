# Clear the rule registry

Mainly useful in tests.

## Usage

``` r
clear_geoscale_rules(param = NULL)
```

## Arguments

- param:

  Optional character vector of names to remove. `NULL` (default) clears
  everything.

## Value

Invisibly `NULL`.

## Examples

``` r
register_geoscale_rule("tmp_param", "sum")
clear_geoscale_rules("tmp_param")
```
