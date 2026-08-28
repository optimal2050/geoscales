# Telescoping zoom: fine detail in a focus area, coarse elsewhere

Builds a new geoframe that keeps `focus` atoms at full resolution and
collapses everything else into progressively coarser rings drawn from
`levels`. The result is a partition of the atoms, carried as a geoframe.

## Usage

``` r
zoom_geoscale(x, focus, levels = NULL, name = "zoom", label_rest = "%s_rest")
```

## Arguments

- x:

  A
  [`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md).

- focus:

  Character vector of **atom** codes to keep at full resolution.

- levels:

  Ordered geoframes to build rings from, coarsest first. Defaults to
  every geoframe of `x` except the atom layer.

- name:

  Name of the new geoframe. Default `"zoom"`.

- label_rest:

  `sprintf` format for a ring's code, with `%s` the parent code. Default
  `"%s_rest"`.

## Value

A
[`Geoscale`](https://optimal2050.github.io/geoscales/r/reference/Geoscale.md)
with geoframes `levels[1]`, `name` and the atom layer; weights and
geometry carried through unchanged.

## Details

With focus atoms and `levels = c("nuts0", "nuts1", "nuts2")` (coarsest
first), each remaining atom joins the **finest** ring that also contains
a focus atom, so the cut telescopes outward:

- the focus atoms themselves, individually;

- the rest of each `nuts2` holding a focus atom;

- the rest of each `nuts1` holding one of those;

- the rest of each `nuts0` holding one of those;

- every other atom, grouped at `levels[1]`.

The intermediate geoframes are **dropped**. A ring like "rest of nuts1"
spans several `nuts2`, so the cut cannot nest with the levels it was
carved from; only `levels[1]` and the atom layer are kept beside it.
That is checked, not assumed — see
[`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md).

## See also

[`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md)
to sample,
[`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md)
to coarsen uniformly,
[`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md)
for the guarantee this relies on.

## Examples

``` r
gs <- geoscale_example()
z <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"))
geoscale_geoframes(z)
#> [1] "country" "zoom"    "atom"   
geoscale_regions(z, "zoom")
#> [1] "A1"      "N1_rest" "N_rest"  "S"      
```
