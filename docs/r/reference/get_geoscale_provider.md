# Look up a registered provider

Look up a registered provider

## Usage

``` r
get_geoscale_provider(name)
```

## Arguments

- name:

  Provider name.

## Value

The provider entry, or an error if unknown.

## Examples

``` r
get_geoscale_provider("naturalearth")$desc
#> [1] "Natural Earth admin-0/admin-1 (rnaturalearth)"
```
