# Validate level names

A level name must be a non-empty, non-`NA` string that is a
syntactically valid R name (so it can be used as a data.frame column
without quoting).

## Usage

``` r
is_valid_level(x)
```

## Arguments

- x:

  Character vector of candidate level names.

## Value

A logical vector the same length as `x`.

## Examples

``` r
is_valid_level(c("COUNTRY", "reg32", "", "2bad"))
#> [1]  TRUE  TRUE FALSE FALSE
```
