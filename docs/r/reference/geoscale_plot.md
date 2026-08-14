# Map data onto a Geoscale

Draws a choropleth of `data` at `level`. Requires `sf`, `ggplot2`, and
geometry attached with
[`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md).

## Usage

``` r
geoscale_plot(
  x,
  data = NULL,
  level = NULL,
  fill = NULL,
  palette = NULL,
  title = NULL,
  subtitle = NULL,
  fill_label = fill,
  label = FALSE,
  ...
)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
  with geometry attached.

- data:

  Optional `data.frame` with a code column named `level` and the column
  named by `fill`. When `NULL`, region outlines are drawn.

- level:

  Level to draw. Defaults to the atom level.

- fill:

  Name of the value column in `data` to colour by.

- palette:

  Viridis palette option (`"A"`..`"H"`) for the fill scale. `NULL`
  (default) leaves ggplot2's own scale in place.

- title, subtitle:

  Plot titles. `NULL` for none.

- fill_label:

  Legend title. Defaults to `fill`; pass `NULL` to drop it.

- label:

  Draw region labels. `TRUE` uses the display names declared by the
  geoscale's `@meta$labels` column when there is one, otherwise the
  region codes.

- ...:

  Passed to
  [`ggplot2::geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html).

## Value

A `ggplot` object.

## Details

This is the package's single choropleth renderer: callers that know what
their numbers *mean* (which variable, extensive or intensive, what
units) should prepare a `data.frame` and hand it here rather than draw
their own `geom_sf()`. `energyRt::geo_map()` works exactly that way.

## Examples

``` r
if (FALSE) { # \dontrun{
geoscale_plot(gs, capacity_by_state, level = "state", fill = "capacity")

# titled, viridis, with region names drawn on
geoscale_plot(gs, gen, level = "zone", fill = "value",
         palette = "D", title = "Generation", label = TRUE)
} # }
```
