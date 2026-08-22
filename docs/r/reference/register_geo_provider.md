# Register a Geoscale data provider

A provider is a function `function(...)` returning either an `sf` object
or a `data.frame`, wide enough that its columns can be used as geoframes
and weights.

## Usage

``` r
register_geo_provider(name, fetch, geoframes = NULL, weights = NULL, desc = "")
```

## Arguments

- name:

  Provider name.

- fetch:

  Function returning the source table.

- geoframes:

  Default geoframe columns, coarsest first.

- weights:

  Default weight columns.

- desc:

  One-line description.

## Value

Invisibly, the registered provider.

## Examples

``` r
register_geo_provider(
  "toy",
  fetch = function(...) data.frame(top = c("T", "T"),
                                   unit = c("a", "b"), km2 = c(1, 2)),
  geoframes = c("top", "unit"), weights = "km2"
)
list_geo_providers()
#>           name                                          desc
#> 1 naturalearth Natural Earth admin-0/admin-1 (rnaturalearth)
#> 2          toy                                              
```
