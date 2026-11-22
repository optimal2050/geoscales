# Visualization with ggplot2

## The viz surface at a glance

| kind | functions | use when |
|----|----|----|
| composable layers | [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md), [`theme_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md) | a choropleth as one layer among others in a custom [`ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html) |
| assembled figures | [`gg_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/gg_geoscale.md) with `type =` `"icicle"`, `"stack"` or `"map"`; [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) returns it, [`plot()`](https://rspatial.github.io/terra/reference/plot.html) draws it | a finished figure in one call |
| layout / geometry workers | [`geoscale_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_layout.md), [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md) | the plain frames behind the figures |

This article needs maps, so it runs on two fixtures that stay out of the
package by design (geoscales ships integration code, not data): the
offline reference layouts in `energyRt::topia$geoscales`, and — for the
real-world tour — Iceland from Natural Earth’s admin-1 layer.

## The integration contract

[`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
mirrors the design of
[`timescales::geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.html):
the geoscale inputs are column **names** (`z=`, `region=`), not
[`aes()`](https://ggplot2.tidyverse.org/reference/aes.html) mappings,
and each call returns a standard
[`ggplot2::geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)
layer whose data is derived from the plot data — the object’s geometry
is dissolved at the requested `geoframe` (via
[`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md)),
the value column is aggregated per region with `fun`, and everything
else — scales, facets, themes, extra layers — composes through the
normal ggplot2 path.

## Choropleths, composably

``` r

gs <- energyRt::topia$geoscales$honeycomb
gs
#> GeoScale: topia_honeycomb 
#> Description: TOPIA reference provinces (honeycomb layout), nested nation -> zone -> province 
#> Geoframes (3, coarsest first):
#>   - nation (1)
#>     - zone (5)
#>       - province (12)
#> Leaves: 12
#> Weights: area (default: area)
#> Labels: province [name] (default: name)
#> CRS: NA
#> Geometry: attached (12 features)

x <- tibble(province = geoscale_regions(gs, "province"),
            capacity = c(5, 3, 8, 2, 6, 4, 7, 1, 9, 2, 5, 3))

ggplot(x) +
  geom_geoscale(gs = gs, z = "capacity", geoframe = "province") +
  scale_fill_viridis_c(option = "G") +
  labs(title = "Capacity by region", fill = "GW") +
  theme_geoscale()
```

![](visualization_files/figure-html/topia-1.png)

With `z = NULL` the layer draws plain boundaries — useful under other
layers:

``` r

ggplot() +
  geom_geoscale(gs = gs, colour = "grey40", fill = "grey93") +
  theme_geoscale()
```

![](visualization_files/figure-html/boundaries-1.png)

## Recasting, seen on the map

The same data drawn at another geoframe is one `geoframe=` away — the
layer dissolves and aggregates itself (here with `fun = sum` for an
extensive quantity):

``` r

ggplot(x) +
  geom_geoscale(gs = gs, z = "capacity", geoframe = "zone", fun = sum) +
  scale_fill_viridis_c(option = "G") +
  labs(title = "The same capacity, by zone", fill = "GW") +
  theme_geoscale()
```

![](visualization_files/figure-html/recast-map-1.png)

For full control,
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
first and draw the result — the explicit route makes the rule visible
(and lets intensive quantities use `weighted_mean`):

``` r

x |>
  recast_geoscale(gs, source = "province", target = "zone", rule = "sum") |>
  ggplot() +
  geom_geoscale(gs = gs, z = "capacity", geoframe = "zone") +
  scale_fill_viridis_c(option = "G") +
  theme_geoscale()
```

![](visualization_files/figure-html/recast-explicit-1.png)

## One panel per geoframe

Dissolved shapes are plain sf objects, so faceting a hierarchy is a
small `|>` chain over
[`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md):

``` r

shapes <- geoscale_geoframes(gs) |>
  lapply(function(gf) {
    geoscale_geometry(gs, gf) |>
      sf::st_sf() |>
      mutate(geoframe = gf, .before = 1) |>
      rename(code = 2)
  }) |>
  bind_rows() |>
  mutate(geoframe = factor(geoframe, levels = geoscale_geoframes(gs)))

ggplot(shapes) +
  geom_sf(aes(fill = code), show.legend = FALSE) +
  facet_wrap(~geoframe) +
  scale_fill_viridis_d(option = "G") +
  theme_geoscale()
```

![](visualization_files/figure-html/facets-1.png)

## Structure figures

The assembled counterparts need no geometry at all.
[`gg_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/gg_geoscale.md)
(also
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html);
[`plot()`](https://rspatial.github.io/terra/reference/plot.html) draws
it) draws the hierarchy as an icicle; its plain-data frame is
[`geoscale_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_layout.md):

``` r

plot(gs)
```

![](visualization_files/figure-html/structure-1.png)

``` r

head(geoscale_layout(gs), 4)
#>   geoframe region rank       xmin       xmax ymin ymax    weight      share
#> 1   nation  TOPIA    1 0.00000000 1.00000000    2  2.9 67.894341 1.00000000
#> 2     zone     Z1    2 0.00000000 0.08333333    1  1.9  5.657862 0.08333333
#> 3     zone     Z2    2 0.08333333 0.25000000    1  1.9 11.315723 0.16666667
#> 4     zone     Z3    2 0.25000000 0.50000000    1  1.9 16.973585 0.25000000
```

The icicle carries data too — `data =`/`z =` fill every band with the
value recast to that geoframe (leaves keep their own values, coarser
bands get the weighted mean):

``` r

cap <- data.frame(province = geoscale_regions(gs, "province"),
                  mw = c(40, 15, 75, 30, 60, 22, 8, 55, 34, 12, 48, 26))
gg_geoscale(gs, data = cap, z = "mw") +
  labs(fill = "MW")
```

![](visualization_files/figure-html/structure-data-1.png)

With geometry attached, `type = "stack"` draws the layer-stack view —
the same leaves dissolved at every geoframe, stacked:

``` r

gg_geoscale(gs, type = "stack")
```

![](visualization_files/figure-html/structure-stack-1.png)

### Points of view

The stack takes a `view` preset — from flat `"top-down"` through the
oblique family (`"cavalier"`, `"cabinet"`) and the axonometric family
(`"military"`, `"isometric"`, `"dimetric"`, `"trimetric"`) to
`"perspective"`, where receding planes shrink, and its inverse
`"pyramid"`, where they grow. Custom obliques come via `angle`/`ratio`,
`rotate=` turns the plane (point North anywhere), `direction=` flips the
stack, and `gap` defaults to planes almost touching:

``` r

# grouped by aspect so tall and flat views don't squeeze each other
views <- c("top-down", "military", "isometric",
           "dimetric", "trimetric", "cabinet",
           "oblique", "perspective", "pyramid")
views |>
  lapply(function(vw)
    gg_geoscale(gs, type = "stack", view = vw) +
      labs(title = vw) +
      theme(plot.title = element_text(size = 9, hjust = 0.5))) |>
  patchwork::wrap_plots(ncol = 3)
```

![](visualization_files/figure-html/stack-views-1.png)

And `type = "map"` is the one-call choropleth over the same machinery:

``` r

gg_geoscale(gs, type = "map", data = x, geoframe = "province",
            z = "capacity", palette = "G")
```

![](visualization_files/figure-html/one-call-1.png)

### Geoframes for calculation only

A geoframe may be needed for the arithmetic without being something to
show.
[`hide_geoframes_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/hide_geoframes_geoscale.md)
marks it, and the figures leave it out; recasts, joins and navigation
still use it. `geoframes = TRUE` draws everything for one figure.

``` r

gs_h <- hide_geoframes_geoscale(gs, "province")
geoscale_geoframes(gs_h, visible = TRUE)
#> [1] "nation" "zone"
gg_geoscale(gs_h, type = "stack", view = "isometric")
```

![](visualization_files/figure-html/hidden-1.png)

### Data above the leaves

`data` may be keyed by any geoframe. Its own plane and every coarser one
it nests in are coloured; finer planes are outlined, since no value was
given for them.

``` r

zones <- data.frame(zone = geoscale_regions(gs, "zone"),
                    gw = c(5, 11, 12, 19, 8))
gg_geoscale(gs, type = "stack", view = "isometric",
            data = zones, z = "gw", rule = "sum")
```

![](visualization_files/figure-html/coarse-data-1.png)

## A real map: Iceland, with data attached

The same workflow on real boundaries. Natural Earth’s admin-1 layer
gives nine admin-1 areas for Iceland that group into its eight regions
(*landshluti*) — a genuinely **ragged** hierarchy, because Reykjavik and
the surrounding capital area are separate features of one region:

``` r

s <- ne_source(geoframe = "states", country = "Iceland")
d <- as.data.frame(s)

isl <- geoscale_from_leaftable(
  data.frame(country    = "ISL",
             landshluti = d$gn_name,
             admin1     = d$iso_3166_2),
  geoframes = c("country", "landshluti", "admin1"),
  leaf = "admin1", name = "iceland"
) |>
  attach_geometry_geoscale(s, by = "iso_3166_2", geoframe = "admin1") |>
  add_area_geoscale(name = "km2")
isl
#> GeoScale: iceland 
#> Geoframes (3, coarsest first):
#>   - country (1)
#>     - landshluti (8)
#>       - admin1 (9)
#> Leaves: 9
#> Weights: km2 (default: km2)
#> CRS: WGS 84
#> Geometry: attached (9 features)
```

[`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md)
attached real data — equal-area km² per admin-1 area — which is also the
object’s default weight. Drawn straight from the leaftable:

``` r

lt <- geoscale_leaftable(isl)

ggplot(tibble(admin1 = lt$admin1, km2 = lt$km2)) +
  geom_geoscale(gs = isl, z = "km2", geoframe = "admin1",
                colour = "white", linewidth = 0.3) +
  scale_fill_viridis_c(option = "G", trans = "sqrt") +
  labs(title = "Iceland's nine admin-1 areas, by area",
       fill = "km2") +
  theme_geoscale()
```

![](visualization_files/figure-html/iceland-area-1.png)

And the full loop in one pipeline: a national total split down to the
regions by area (`rule = "sum"` conserves it), drawn at the *landshluti*
geoframe — where the two admin-1 areas of the capital render as one
region:

``` r

tibble(country = "ISL", capacity_mw = 3000) |>
  recast_geoscale(isl, source = "country", target = "landshluti",
                  rule = "sum", weight = "km2") |>
  ggplot() +
  geom_geoscale(gs = isl, z = "capacity_mw", geoframe = "landshluti",
                colour = "white", linewidth = 0.3) +
  scale_fill_viridis_c(option = "G") +
  labs(title = "A 3 GW national total, split by area across 8 regions",
       fill = "MW") +
  theme_geoscale()
```

![](visualization_files/figure-html/iceland-recast-1.png)

## One resource, three geoframes

The wind-cluster GeoScale from the [get-started
vignette](https://optimal2050.github.io/geoscales/r/articles/geoscales.html)
carries Iceland’s mean wind speed on its cluster leaves; recasting the
same values up the hierarchy shows exactly what each aggregation keeps —
the temporal twin of this figure (one wind year at three calendar
resolutions) lives in the [timescales visualization
vignette](https://optimal2050.github.io/timescales/r/articles/visualization.html):

``` r

iw <- readRDS("../../data-raw/iceland_wind.rds")
for (gf in c("cluster", "landshluti", "country")) {
  d <- if (gf == "cluster") iw$wind else
    recast_geoscale(iw$wind, iw$gs, source = "cluster", target = gf,
                    rule = "weighted_mean", weight = "km2")
  print(gg_geoscale(iw$gs, type = "map", data = d, geoframe = gf,
                    z = "wind", palette = "G") +
          labs(title = paste("Iceland mean wind speed at:", gf),
               fill = "m/s"))
}
```

![](visualization_files/figure-html/wind-trio-1.png)![](visualization_files/figure-html/wind-trio-2.png)![](visualization_files/figure-html/wind-trio-3.png)

## See also

- [`vignette("geoscales")`](https://optimal2050.github.io/geoscales/r/articles/geoscales.md)
  — the 5-minute tour.
- [`vignette("data-manipulation")`](https://optimal2050.github.io/geoscales/r/articles/data-manipulation.md)
  — the conversion pipelines feeding these maps.
- timescales’ *Visualization with ggplot2* vignette — the temporal
  sibling: same contract, calendar heatmaps and wall calendars instead
  of choropleths.
