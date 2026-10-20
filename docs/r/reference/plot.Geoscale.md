# Plot a GeoScale

Dispatches to
[`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md)
— the geometry-free structure icicle (parity with
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) on a
[`timescales::Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.html)).
For maps, see
[`geoscale_plot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_plot.md)
and
[`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md).

## Usage

``` r
# S3 method for class 'GeoScale'
plot(x, ...)

# S3 method for class '`geoscales::GeoScale`'
plot(x, ...)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md).

- ...:

  Passed to
  [`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md).

## Value

A ggplot object.
