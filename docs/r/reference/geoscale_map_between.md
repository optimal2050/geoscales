# Crosswalk between two Geoscales through their shared atoms

The counterpart of
[`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md)
for two Geoscales: atoms are matched on their `region` keys, so a region
of `from` overlaps a region of `to` where they contain the same atoms.
Same columns as
[`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md),
with the two label columns named after the Geoscales. Atoms of `from`
absent from `to` get an `NA` target (with a warning). A crosswalk
registered with
[`register_geoscale_map_between()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_map.md)
is returned as-is instead of being derived.

## Usage

``` r
geoscale_map_between(from, to, weight = NULL)
```

## Arguments

- from, to:

  Two named
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  objects whose atom keys overlap.

- weight:

  Weight column of `from` for `w`; `NULL` uses its default weight, or
  weight 1 per atom when it declares none.

## Value

A `data.frame` with columns `<from name>`, `<to name>`, `n_from`,
`n_overlap`, `w`, `w_from`.

## Examples

``` r
gs <- geoscale_example()
# another hierarchy over the same atoms (ROW has no counterpart: NA target)
bands <- geoscale_from_leaftable(
  data.frame(
    band = rep(c("X", "Y"), 3),
    atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
    km2 = c(100, 200, 300, 400, 500, 600)
  ),
  geoframes = c("band", "atom"), name = "bands"
)
geoscale_map_between(gs, bands)
#> Warning: 1 atom(s) of "example" have no counterpart in "bands"; their share is uncovered (NA target)
#>   example bands n_from n_overlap    w w_from
#> 1      A1    A1      1         1  100    100
#> 2      A2    A2      1         1  200    200
#> 3      A3    A3      1         1  300    300
#> 4      A4    A4      1         1  400    400
#> 5      A5    A5      1         1  500    500
#> 6      A6    A6      1         1  600    600
#> 7     ROW  <NA>      1         1 1000   1000
```
