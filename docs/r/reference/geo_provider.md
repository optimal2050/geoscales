# Look up a registered provider

Look up a registered provider

## Usage

``` r
geo_provider(name)
```

## Arguments

- name:

  Provider name.

## Value

The provider entry, or an error if unknown.

## Examples

``` r
geo_provider("naturalearth")$desc
#> [1] "Natural Earth admin-0/admin-1 (rnaturalearth)"
```
