# Bind a table to a GeoScale

Records, on the region-code columns themselves, which
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
and which geoframe their codes are on. Column names alone cannot say
that: two geographies may both have a `zone`, and may even share codes.
A bound column still behaves as a character vector and keeps the link
through row subsetting, `mutate()`, grouping, joins and row binding.
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
[`recast_to_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md),
[`recast_from_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.md)
and
[`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
then take the source geoframe from the link, stop when the data is bound
to a different GeoScale, and bind their result. Data that was never
bound is handled as before.

## Usage

``` r
bind_geoscale(data, gs, cols = NULL)

geoscale_link(data)

geoscale_id(gs)
```

## Arguments

- data:

  A `data.frame`, tibble or `data.table`.

- gs:

  The
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
  the codes belong to.

- cols:

  Which columns to bind. `NULL` (default) binds every column named after
  a geoframe of `gs`. Otherwise a character vector of geoframe names,
  named by column where the column is called something else:
  `c(origin = "zone")`.

## Value

`bind_geoscale()` returns `data`; `geoscale_link()` a `data.frame` with
one row per bound column (`column`, `scale`, `frame`, `id`);
`geoscale_id()` a single string.

## Details

Every code is checked when binding; a code that is not a region of the
geoframe is an error. `geoscale_link()` reports what a table is bound
to, and `geoscale_id()` gives the identity the link stores: the name of
the GeoScale and a hash of its structure (geoframes and memberships, not
weights, labels or geometry).
[`nestedscales::unbind_scale()`](https://optimal2050.github.io/nestedscales/r/reference/bind_scale.html)
returns the columns to plain character.

The link needs `nestedscales` 0.3.0 or later.

## Examples

``` r
gs <- geoscale_example()
geoscale_id(gs)
#> [1] "example@a18586f1"
d <- data.frame(state = c("N1", "N2", "S1"), cap = c(1, 2, 3))
b <- bind_geoscale(d, gs)
geoscale_link(b)
#>   column   scale frame               id
#> 1  state example state example@a18586f1
out <- recast_geoscale(b, gs, target = "country", rule = "sum")
geoscale_link(out)
#>    column   scale   frame               id
#> 1 country example country example@a18586f1
```
