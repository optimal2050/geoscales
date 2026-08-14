# Plot a Geoscale

Draws the hierarchy as an icicle: one row per level, coarsest at the
top, each region's width proportional to its share of the weight.

## Usage

``` r
geoscale_autoplot(
  x,
  weight = NULL,
  fill = c("level", "region"),
  label = TRUE,
  ...
)

autoplot.Geoscale(x, ...)
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- weight:

  Weight column determining widths. `NULL` uses the default.

- fill:

  What to colour by: `"level"` or `"region"`.

- label:

  Draw region codes on the rectangles.

- ...:

  Unused.

## Value

A `ggplot` object.

## Details

This is the *structure* plot — it shows the Geoscale itself and needs no
geometry. For a map of values over regions, see
[`geoscale_plot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_plot.md).

Also registered as an `autoplot()` method, so `ggplot2::autoplot(gs)`
works when ggplot2 is installed.

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  geoscale_autoplot(geoscale_example())
}
```
