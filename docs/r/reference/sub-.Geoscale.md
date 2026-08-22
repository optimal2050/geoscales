# Subset a Geoscale with `[`

`gs[geoframe, region]` is shorthand for
[`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md).

## Usage

``` r
# S3 method for class 'Geoscale'
x[i, j, ...]

# S3 method for class '`geoscales::Geoscale`'
x[i, j, ...]
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- i:

  Geoframe name.

- j:

  Character vector of region codes.

- ...:

  Unused.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

## Details

S7 ships a `[.S7_object` that errors, so a method must be registered for
the class itself. Under S7 0.2
[`class()`](https://rdrr.io/r/base/class.html) reports the
package-qualified
[`geoscales::Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
both when sourced and when installed, so that is the registration that
actually dispatches; the bare `Geoscale` one is kept as a cheap guard in
case an S7 version reports the short name. This mirrors the two-function
pattern [`print()`](https://rdrr.io/r/base/print.html) uses in
geoscale-class.R. Declaring both as real methods with `@export`, rather
than via `@rawNamespace`, is what stops roxygen2 reporting them as
unexported.

## Examples

``` r
gs <- geoscale_example()
gs["country", "N"]
#> Geoscale: example 
#> Description: Synthetic example: reused code, non-nesting geoframe pair, and an unassigned atom 
#> Geoframes (4, coarsest first):
#>   - country (1)
#>     - state (2)
#>       - zone (2)
#>         - atom (4)
#> Atoms: 4
#> Weights: km2, pop (default: km2)
```
