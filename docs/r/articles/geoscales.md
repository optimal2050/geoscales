# Getting started with geoscales

## What problem does this solve?

Energy-system, climate, and policy models carve space into discrete
*regions*, and different models pick different carvings: one nation,
five grid regions, thirty-two model regions, forty-six zones. The codes
are arbitrary, the weights (area, population) are data, and region
systems drawn by different hands rarely nest — converting values between
them is where unit errors live.

`geoscales` represents any such carving as a **Geoscale**: a set of
*atoms* (the finest regions) plus ordered *geoframes* that group them —
the spatial companion to a
[`timescales::Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.html).
With one object you get:

- a stable schema for region codes and their weights,
- well-defined conversions between any two resolutions — including
  cross-cutting ones, because every conversion routes through the atom
  layer,
- attachment of hierarchy columns to your tables, and ggplot2-ready
  maps.

## A 5-minute tour

### 1. Build a Geoscale

Three construction layers, from most to least convenient — a provider,
parent-child crosswalks, or a wide table you already have:

``` r

gs <- geoscale_from_leaftable(
  data.frame(
    country = c("N", "N", "N", "N", "S", "S"),
    state   = c("N1", "N1", "N2", "N2", "S1", "S1"),
    atom    = c("A1", "A2", "A3", "A4", "A5", "A6"),
    km2     = c(100, 200, 300, 400, 500, 600)
  ),
  geoframes = c("country", "state", "atom"),
  name = "tour"
)
gs
#> Geoscale: tour 
#> Geoframes (3, coarsest first):
#>   - country (2)
#>     - state (3)
#>       - atom (6)
#> Atoms: 6
#> Weights: km2 (default: km2)
```

([`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
assembles the same thing from ragged parent-child crosswalks;
[`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md)
pulls a source like Natural Earth — see
[`vignette("from-naturalearth")`](https://optimal2050.github.io/geoscales/r/articles/from-naturalearth.md).)

### 2. Inspect the structure

``` r

gs@geoframes                 # the hierarchy, coarsest first
#> [1] "country" "state"   "atom"
head(gs@leaftable, 3)        # one row per atom
#>   country state atom km2 region
#> 1       N    N1   A1 100     A1
#> 2       N    N1   A2 200     A2
#> 3       N    N2   A3 300     A3
geoscale_regions(gs, "state")
#> [1] "N1" "N2" "S1"
geoscale_share(gs, "state", weight = "km2", within = "country")
#>   state country  km2 share
#> 1    N1       N  300   0.3
#> 2    N2       N  700   0.7
#> 3    S1       S 1100   1.0
```

### 3. Convert data between resolutions

One rule per value column; aggregation and disaggregation are the same
operation, and totals conserve under `"sum"`:

``` r

cap <- tibble(atom = paste0("A", 1:6), capacity = c(1, 2, 3, 4, 5, 6))
cap |> recast_geoscale(gs, from = "atom", to = "country", rule = "sum")
#> # A tibble: 2 × 2
#>   country capacity
#>   <chr>      <dbl>
#> 1 N             10
#> 2 S             11

# ... and back down, split by area
tibble(country = c("N", "S"), capacity = c(10, 20)) |>
  recast_geoscale(gs, from = "country", to = "state",
                  rule = "sum", weight = "km2")
#> # A tibble: 3 × 2
#>   state capacity
#>   <chr>    <dbl>
#> 1 N1           3
#> 2 N2           7
#> 3 S1          20
```

The `rule` is deliberately mandatory — pass one, or register it per
column with
[`register_geo_rule()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_rule.md);
a silently guessed rule would be a silent unit error.

### 4. Attach a Geoscale to a table

[`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
decorates rather than converts — membership and share/weight columns
arrive `"<name>."`-prefixed, so several Geoscales can coexist on one
dataset:

``` r

tibble(state = c("N1", "N2", "S1"), v = 1:3) |>
  join_geoscale(gs, geoframes = TRUE, meta = TRUE)
#> # A tibble: 3 × 6
#>   state     v tour.country tour.weight tour.share tour 
#>   <chr> <int> <fct>              <dbl>      <dbl> <chr>
#> 1 N1        1 N                    300      0.143 N1   
#> 2 N2        2 N                    700      0.333 N2   
#> 3 S1        3 S                   1100      0.524 S1
```

### 5. Visualize

[`geoscale_autoplot()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_autoplot.md)
(also [`plot()`](https://rdrr.io/r/graphics/plot.default.html)) draws
the hierarchy itself — no geometry needed. With geometry attached,
[`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
puts values on a map inside a normal
[`ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
pipeline:

``` r

geoscale_autoplot(gs)
```

![](geoscales_files/figure-html/unnamed-chunk-6-1.png)

``` r

# with attached geometry (see the visualization article):
ggplot(cap) +
  geom_geoscale(gs = gs, z = "capacity", geoframe = "state") +
  scale_fill_viridis_c() +
  theme_geoscale()
```

## Where to next?

- [Concepts](https://optimal2050.github.io/geoscales/r/articles/concepts.md)
  — atoms, partitions vs trees, the shared \*scales glossary.
- [Data
  structures](https://optimal2050.github.io/geoscales/r/articles/data-structures.md)
  — anatomy of a `Geoscale` and its registries.
- [Data
  manipulation](https://optimal2050.github.io/geoscales/r/articles/data-manipulation.md)
  — attach, recast, route halves, crosswalks, backends, and chaining
  time with space.
- [Building from Natural
  Earth](https://optimal2050.github.io/geoscales/r/articles/from-naturalearth.md)
  — providers in practice.
- [Visualization](https://optimal2050.github.io/geoscales/r/articles/visualization.md)
  — maps with
  [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md),
  on a real multi-layer example.
