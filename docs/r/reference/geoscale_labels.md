# Labels of regions and geoframes

Display names for the members of a
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).
A label belongs to a region at a geoframe and to a named `variant` – a
free name such as `"name"`, `"short"` or a language code – so a region
may carry several names. The table is sparse: a geoframe may label every
region, some, or none, and whatever has no label is shown by its code. A
row with `region = NA` names the geoframe itself.

## Usage

``` r
attach_labels_geoscale(
  x,
  labels,
  variant = NULL,
  default = NULL,
  overwrite = FALSE
)

geoscale_labels(x, geoframe = NULL, variant = NULL)

geoscale_label(x, region, geoframe, variant = NULL)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

- labels:

  A `data.frame` with columns `geoframe`, `region`, `label` and
  optionally `variant`. The `nestedscales` names `frame` and `member`
  are accepted for the first two.

- variant:

  For `attach_labels_geoscale()`: the variant the rows belong to when
  `labels` has no `variant` column (default `"label"`). For the readers:
  the variant to return; `NULL` is every variant in `geoscale_labels()`
  and the default one in `geoscale_label()`.

- default:

  Name of the variant used when none is asked for. `NULL` keeps the
  current default (initially the first variant attached).

- overwrite:

  Replace a label already present for the same region and variant.
  `FALSE` (default) makes that an error.

- geoframe:

  The geoframe: for `geoscale_labels()` a filter (`NULL` for all), for
  `geoscale_label()` the geoframe the codes are at.

- region:

  Character vector of region codes at `geoframe`; `NA` stands for the
  geoframe itself.

## Value

`attach_labels_geoscale()` the
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md);
`geoscale_labels()` a `data.frame` with columns `geoframe`, `region`,
`variant`, `label`; `geoscale_label()` a character vector as long as
`region`.

## Details

`attach_labels_geoscale()` adds rows (and may set the default variant),
`geoscale_labels()` returns the table, and `geoscale_label()` looks
names up for a vector of codes, returning the code where there is no
label. Subsetting and pruning keep the labels of what remains, and the
plots use the default variant.

## Examples

``` r
gs <- attach_labels_geoscale(
  geoscale_example(),
  data.frame(geoframe = "country", region = c("N", "S"),
             label = c("Northland", "Southland")),
  variant = "name"
)
gs <- attach_labels_geoscale(
  gs,
  data.frame(geoframe = "country", region = "N", label = "Nordland"),
  variant = "de"
)
geoscale_labels(gs)
#>   geoframe region variant     label
#> 1  country      N    name Northland
#> 2  country      S    name Southland
#> 3  country      N      de  Nordland
geoscale_label(gs, c("N", "S"), "country")
#> [1] "Northland" "Southland"
geoscale_label(gs, c("N", "S"), "country", variant = "de")
#> [1] "Nordland" "S"       
geoscale_label(gs, c("N1", "ZB"), "zone")     # no labels: the codes
#> [1] "N1" "ZB"
```
