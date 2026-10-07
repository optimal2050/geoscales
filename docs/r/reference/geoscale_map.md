# Crosswalk between two geoframes of a Geoscale

Materialises the `from -> atoms -> to` route as a table: one row per
pair of overlapping regions with

## Usage

``` r
geoscale_map(gs, from, to, weight = NULL)
```

## Arguments

- gs:

  The
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  the geoframes belong to.

- from, to:

  Geoframe names of `gs`.

- weight:

  Weight column for `w`. `NULL` uses the default weight; when the object
  declares no weights at all, every atom gets weight 1 (an equal split).

## Value

A `data.frame` with columns `<from>`, `<to>` (`NA` = uncovered by `to`),
`n_from`, `n_overlap`, `w`, `w_from`.

## Details

- `n_from` – atoms in the `from` region (its full set, before any target
  coverage is considered),

- `n_overlap` – atoms the pair shares,

- `w` – the weight of the overlap (summed atom weights, chosen weight
  column), the quantity `"weighted_mean"` aggregation uses,

- `w_from` – the full weight of the `from` region; `w / w_from` is the
  split share `"sum"` disaggregation uses.

The two label columns are named by the geoframes; rows with an `NA`
target label are atoms `to` does not cover. A crosswalk registered with
[`register_geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_map.md)
is returned as-is instead of being derived.

## See also

[`geoscale_map_between()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map_between.md)
for the map between two Geoscales.

## Examples

``` r
gs <- geoscale_example()
geoscale_map(gs, "state", "zone")
#>   state zone n_from n_overlap   w w_from
#> 1    N1   N1      2         2 300    300
#> 2    N2   ZB      2         2 700    700
#> 3    S1   ZB      2         1 500   1100
#> 4    S1   ZC      2         1 600   1100
geoscale_map(gs, "country", "state", weight = "km2")
#>   country state n_from n_overlap    w w_from
#> 1       N    N1      4         2  300   1000
#> 2       N    N2      4         2  700   1000
#> 3       S    S1      2         2 1100   1100
```
