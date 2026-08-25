# Subset a Geoscale by region

Keeps only the atoms belonging to `region` at `geoframe`, and rebuilds
the member vocabularies accordingly. Geometry, when attached, is subset
in step.

## Usage

``` r
filter_geoscale(x, geoframe, region, drop_empty_geoframes = FALSE)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- geoframe:

  Geoframe that `region` belongs to.

- region:

  Character vector of region codes to keep.

- drop_empty_geoframes:

  Drop geoframes left with no codes at all.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Details

A genuine subset is a SAMPLE and is book-kept as one (the spatial mirror
of
[`timescales::filter_calendar()`](https://optimal2050.github.io/timescales/r/reference/filter_calendar.html)'s
`year_fraction`): `meta$coverage` records, per weight column, the kept
fraction of the ROOT parent's total (so filters compose against the
original object), `meta$parent_totals` stores those root totals (making
the coverage claim verifiable by the validator), `meta$parent_name`
records the parent, and `meta$name` is mangled to `"parent[geoframe:n]"`
so a sample never impersonates its parent in the crosswalk registry or
in
[`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
column names. A filter that keeps every atom is a true no-op. Read the
fraction back with
[`geoscale_coverage()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_coverage.md).

## Examples

``` r
gs <- geoscale_example()
n <- filter_geoscale(gs, "country", "N")
n
#> Geoscale: example[country:N] 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom 
#> Geoframes (4, coarsest first):
#>   - country (1)
#>     - state (2)
#>       - zone (2)
#>         - atom (4)
#> Atoms: 4
#> Weights: km2, pop (default: km2)
geoscale_coverage(n)
#>       km2       pop 
#> 0.3225806 0.6666667 
```
