# Navigate a region hierarchy

`geo_children()` and `geo_parents()` step one level; `geo_descendants()`
and `geo_ancestors()` follow the transitive closure.

## Usage

``` r
geo_children(x, level, region, to = NULL)

geo_parents(x, level, region, to = NULL)

geo_descendants(x, level, region, to = NULL)

geo_ancestors(x, level, region, to = NULL)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- level:

  Level that `region` belongs to.

- region:

  Character vector of region codes at `level`.

- to:

  Target level. For `geo_children()`/`geo_parents()` this defaults to
  the adjacent level; for the transitive versions, `NULL` means all
  levels below/above.

## Value

`geo_children()` and `geo_parents()` return a character vector of codes
at a single level. `geo_descendants()` and `geo_ancestors()` span
several levels and so return a `data.frame` with columns `level` and
`region` — a bare character vector would be ambiguous, since the same
code can occur at more than one level.

## Details

`level` is required in every case — region codes are not unique across
levels, so a bare code is ambiguous.

## Examples

``` r
gs <- geoscale_example()
geo_children(gs, "country", "N")
#> [1] "N1" "N2"
geo_parents(gs, "state", "N1", to = "country")
#> [1] "N"
geo_descendants(gs, "country", "N")
#>   level region
#> 1 state     N1
#> 2 state     N2
#> 3  zone     N1
#> 4  zone     ZB
#> 5  atom     A1
#> 6  atom     A2
#> 7  atom     A3
#> 8  atom     A4
geo_ancestors(gs, "atom", "A5")
#>     level region
#> 1 country      S
#> 2   state     S1
#> 3    zone     ZB
```
