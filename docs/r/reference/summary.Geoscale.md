# Summarize a Geoscale

Complements [`print()`](https://rdrr.io/r/base/print.html) with the
quantitative view: per-weight totals and coverage, the adjacent-geoframe
nesting table, and the geometry status. Returns a `"summary_Geoscale"`
object (a list) with its own print method — the mirror of
`summary.Calendar()` in timescales. sf-free: geometry is reported from
the object itself, never touched.

## Usage

``` r
# S3 method for class 'Geoscale'
summary(object, ...)

# S3 method for class '`geoscales::Geoscale`'
summary(object, ...)

# S3 method for class 'summary_Geoscale'
print(x, ...)
```

## Arguments

- object:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- ...:

  Ignored.

- x:

  A `"summary_Geoscale"` object (the print method's argument).

## Value

[`summary()`](https://rdrr.io/r/base/summary.html) returns a list of
class `"summary_Geoscale"`: `name`, `desc`, `geoframes` (named member
counts), `unassigned` (named NA-atom counts), `n_atoms`, `weights`,
`weight_totals`, `default_weight`, `coverage` (see
[`geoscale_coverage()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_coverage.md)),
`sampled`, `parent_name`, `nesting` (adjacent-pair table with offender
counts, see
[`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md)),
`geometry` (attached / n_features / crs), `source`.

## Examples

``` r
summary(geoscale_example())
#> <summary of Geoscale 'example' >
#>   desc:          Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom
#>   geoframes:      country (2) / state (3) / zone (3) / atom (7)
#>   atoms:          7
#>   unassigned:     country (1), state (1), zone (1)
#>   weight totals:  km2 = 3,100, pop =   300  (default: km2)
#>   nesting:        country > state: nested
#>   nesting:        state > zone: CROSS-CUTTING (1 offender(s))
#>   nesting:        zone > atom: nested
#>   geometry:       none
summary(filter_geoscale(geoscale_example(), "country", "N"))
#> <summary of Geoscale 'example[country:N]' >
#>   desc:          Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom
#>   geoframes:      country (1) / state (2) / zone (2) / atom (4)
#>   atoms:          4
#>   weight totals:  km2 = 1,000, pop =   200  (default: km2)
#>   SAMPLED:        km2 32.3%, pop 66.7% of 'example'
#>   nesting:        country > state: nested
#>   nesting:        state > zone: nested
#>   nesting:        zone > atom: nested
#>   geometry:       none
```
