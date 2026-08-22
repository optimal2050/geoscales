# Validate geoframe names

A geoframe name must be a non-empty, non-`NA` string that is a
syntactically valid R name (so it can be used as a data.frame column
without quoting).

## Usage

``` r
is_valid_geoframe(x)
```

## Arguments

- x:

  Character vector of candidate geoframe names.

## Value

A logical vector the same length as `x`.

## Examples

``` r
is_valid_geoframe(c("COUNTRY", "reg32", "", "2bad"))
#> [1]  TRUE  TRUE FALSE FALSE
```
