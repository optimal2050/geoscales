# Build a Geoscale from parent-child crosswalks

Assembles a wide leaves table from a set of two-column crosswalks. Each
crosswalk is a `data.frame` whose column names are two level names; the
builder joins them together, starting from the finest level, until every
level in `levels` is present.

## Usage

``` r
geoscale_build(..., levels, weights = NULL, name = "", desc = "")
```

## Arguments

- ...:

  Additional arguments passed to
  [`geoscale_from_leaves()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaves.md).

- levels:

  Ordered character vector of level names, coarsest first. The last
  entry is the atom level.

- weights:

  Optional `data.frame` keyed by the atom level, carrying one or more
  numeric weight columns.

- name, desc:

  Short name and description.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Details

Crosswalks need not form a strict chain: a level that cross-cuts the
others (a grid zone crossing state lines, say) is expressed simply by
giving its crosswalk against the finest level.

## Examples

``` r
geoscale_build(
  data.frame(country = c("N", "N", "S"),
             state   = c("N1", "N2", "S1")),
  data.frame(state = c("N1", "N1", "N2", "S1"),
             atom  = c("A1", "A2", "A3", "A4")),
  levels  = c("country", "state", "atom"),
  weights = data.frame(atom = c("A1", "A2", "A3", "A4"),
                       km2  = c(10, 20, 30, 40))
)
#> Geoscale: <unnamed> 
#> Levels (3, coarsest first):
#>   - country (2)
#>     - state (3)
#>       - atom (4)
#> Atoms: 4
#> Weights: km2 (default: km2)
```
