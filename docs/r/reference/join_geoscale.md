# Attach a Geoscale to region-keyed data

Adds a region-label column named after the Geoscale (its `meta$name`),
plus optionally coarser-geoframe membership columns (each code's
country, continent, ...) and share/weight, all prefixed `"<name>."`.
Because every Geoscale attaches under its own name, several can be
joined to the same dataset – and a dataset carrying two label columns is
a direct crosswalk between those objects. The spatial mirror of
[`timescales::join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.html).

## Usage

``` r
join_geoscale(
  x,
  gs,
  key = NULL,
  geoframe = NULL,
  geoframes = NULL,
  meta = FALSE,
  weight = NULL,
  as_factor = TRUE,
  collect = NULL
)
```

## Arguments

- x:

  The dataset, in any supported backend (see
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)'s
  Backends section).

- gs:

  A named
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- key:

  Name of the code column in `x`. `NULL` (default) auto-detects as
  described above.

- geoframe:

  Geoframe the codes belong to. Inferred when exactly one of the
  object's geoframe names is a column of `x`.

- geoframes:

  Coarser geoframes to attach as `"<name>.<geoframe>"` membership
  columns (default: none). `TRUE` attaches all geoframes coarser than
  `geoframe`.

- meta:

  Attach `"<name>.share"` and `"<name>.weight"` columns (summed atom
  weights of each keyed code, shares normalised over the geoframe;
  default `FALSE`). Skipped with a warning when the object declares no
  weights.

- weight:

  Weight column for the meta columns; `NULL` uses the default weight.

- as_factor:

  Attach membership columns as vocabulary-ordered factors (default
  `TRUE`) or plain character. (Lazy backends store them as
  dictionary/character columns.)

- collect:

  For lazy inputs: materialise (`TRUE`) or return the query (default).

## Value

`x` with the new column(s) appended, in the input's class (lazy in, lazy
out).

## Details

The key is auto-detected: an existing column named like the Geoscale is
used as-is; else a column named like the keyed geoframe; else `region`.
Codes are validated against the geoframe (unknown codes warn). Existing
columns are never overwritten; the join errors instead.

## Examples

``` r
gs <- geoscale_example()
x <- data.frame(state = c("N1", "N2", "S1"), v = 1:3)
join_geoscale(x, gs, geoframes = TRUE)
#>   state v example.country example
#> 1    N1 1               N      N1
#> 2    N2 2               N      N2
#> 3    S1 3               S      S1
join_geoscale(x, gs, meta = TRUE)
#>   state v example.weight example.share example
#> 1    N1 1            300     0.1428571      N1
#> 2    N2 2            700     0.3333333      N2
#> 3    S1 3           1100     0.5238095      S1
```
