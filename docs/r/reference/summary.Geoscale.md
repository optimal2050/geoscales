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
#> $name
#> [1] "example"
#> 
#> $desc
#> [1] "Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom"
#> 
#> $geoframes
#> country   state    zone    atom 
#>       2       3       3       7 
#> 
#> $unassigned
#> country   state    zone    atom 
#>       1       1       1       0 
#> 
#> $n_atoms
#> [1] 7
#> 
#> $weights
#> [1] "km2" "pop"
#> 
#> $weight_totals
#>  km2  pop 
#> 3100  300 
#> 
#> $default_weight
#> [1] "km2"
#> 
#> $coverage
#> km2 pop 
#>   1   1 
#> 
#> $sampled
#> [1] FALSE
#> 
#> $parent_name
#> NULL
#> 
#> $nesting
#>    parent child nests n_offenders
#> 1 country state  TRUE           0
#> 2   state  zone FALSE           1
#> 3    zone  atom  TRUE           0
#> 
#> $geometry
#> $geometry$attached
#> [1] FALSE
#> 
#> $geometry$n_features
#> [1] 0
#> 
#> $geometry$crs
#> NULL
#> 
#> 
#> $source
#> NULL
#> 
#> attr(,"class")
#> [1] "summary_Geoscale"
summary(filter_geoscale(geoscale_example(), "country", "N"))
#> $name
#> [1] "example[country:N]"
#> 
#> $desc
#> [1] "Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom"
#> 
#> $geoframes
#> country   state    zone    atom 
#>       1       2       2       4 
#> 
#> $unassigned
#> country   state    zone    atom 
#>       0       0       0       0 
#> 
#> $n_atoms
#> [1] 4
#> 
#> $weights
#> [1] "km2" "pop"
#> 
#> $weight_totals
#>  km2  pop 
#> 1000  200 
#> 
#> $default_weight
#> [1] "km2"
#> 
#> $coverage
#>       km2       pop 
#> 0.3225806 0.6666667 
#> 
#> $sampled
#> [1] TRUE
#> 
#> $parent_name
#> [1] "example"
#> 
#> $nesting
#>    parent child nests n_offenders
#> 1 country state  TRUE           0
#> 2   state  zone  TRUE           0
#> 3    zone  atom  TRUE           0
#> 
#> $geometry
#> $geometry$attached
#> [1] FALSE
#> 
#> $geometry$n_features
#> [1] 0
#> 
#> $geometry$crs
#> NULL
#> 
#> 
#> $source
#> NULL
#> 
#> attr(,"class")
#> [1] "summary_Geoscale"
```
