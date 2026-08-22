# Build a Geoscale from a provider

Fetches a source table from a registered provider and turns it into a
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).
Geoframe and weight defaults come from the provider when not given.

## Usage

``` r
geoscale_from_provider(
  provider = "naturalearth",
  geoframes = NULL,
  weights = NULL,
  geometry = TRUE,
  name = "",
  desc = "",
  ...
)
```

## Arguments

- provider:

  Provider name, or a source `sf`/`data.frame` to use directly.

- geoframes:

  Geoframe columns, coarsest first.

- weights:

  Weight columns.

- geometry:

  Attach geometry when the source is an `sf` object.

- name, desc:

  Short name and description for the result.

- ...:

  Passed to the provider's `fetch()`.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# Countries nested in UN subregion and continent, weighted by population
gs <- geoscale_from_provider(
  "naturalearth",
  geoframes  = c("continent", "subregion", "adm0_a3"),
  weights = c("pop_est", "gdp_md"),
  scale   = 110
)
} # }
```
