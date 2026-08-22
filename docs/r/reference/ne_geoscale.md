# Build a Geoscale from Natural Earth

Convenience wrapper: fetches Natural Earth via
[`ne_source()`](https://optimal2050.github.io/geoscales/r/reference/ne_source.md)
and builds a
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
nested `continent -> subregion -> country -> feature`, weighted by
population and GDP.

## Usage

``` r
ne_geoscale(
  scale = 110,
  geoframes = c("continent", "subregion", "country", "feature"),
  weights = c("pop_est", "gdp_md"),
  geometry = TRUE,
  ...
)
```

## Arguments

- scale:

  Natural Earth scale: `110`, `50` or `10`. Note that `110` is
  unsuitable for area weights (see details).

- geoframes:

  Geoframe columns, coarsest first.

- weights:

  Weight columns.

- geometry:

  Attach geometry.

- ...:

  Passed to the underlying `rnaturalearth` function.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md),
with `scale` and `source` recorded in `@meta` so the object is
self-documenting and reproducible.

## Details

`feature` is the atom: the Natural Earth unit. `country` sits above it
as a grouping of atoms, so it can only ever be coarser than `feature`.

Do not derive area weights from `scale = 110`; see
[`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md).

## Examples

``` r
if (FALSE) { # \dontrun{
gs <- ne_geoscale(scale = 110)

# roll population up from countries to sub-regions
lf <- S7::prop(gs, "leaftable")
pop <- data.frame(country = lf$country, pop = lf$pop_est)
recast_geoscale(pop[!is.na(pop$country), ], gs,
           from = "country", to = "subregion", rule = "sum")
} # }
```
