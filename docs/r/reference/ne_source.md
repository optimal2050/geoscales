# Fetch a Natural Earth source table

Thin wrapper over
[`rnaturalearth::ne_countries()`](https://docs.ropensci.org/rnaturalearth/reference/ne_countries.html)
/ `ne_states()` that normalises the country-code column.

## Usage

``` r
ne_source(scale = 110, level = c("country", "states"), country = NULL, ...)
```

## Arguments

- scale:

  Natural Earth scale: `110`, `50` or `10`. Note that `110` is
  unsuitable for area weights (see details).

- level:

  `"country"` (admin-0) or `"states"` (admin-1). Admin-1 requires
  `rnaturalearthhires`, which is **not on CRAN** — install it from
  <https://ropensci.r-universe.dev>.

- country:

  Optional country filter passed through to `rnaturalearth`.

- ...:

  Passed to the underlying `rnaturalearth` function.

## Value

An `sf` object with two added columns: `feature`, the Natural Earth unit
(`adm0_a3`, or `adm1_code` for states), and `country`, its admin-0 code.

## Details

`feature` is the atom and `country` is a grouping of atoms on top of it.
At admin-0 the two are the same code; at admin-1 (`level = "states"`)
`feature` is the state and `country` is the admin-0 unit it belongs to.

Codes of `"-99"` mean *unassigned* and are returned as `NA`. That is why
`country` is a level rather than the atom key: it may be missing,
whereas an atom key may not.

## Examples

``` r
if (FALSE) { # \dontrun{
ne_source(scale = 110)
ne_source(scale = 10, level = "states", country = "Iceland")
} # }
```
