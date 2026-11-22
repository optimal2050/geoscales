# Check that the geometry of a GeoScale is on the right regions

The geometry of a
[`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
is one shape per leaf, in the row order of the leaftable, with no codes
of its own. A shape bound to the wrong row gives a map in which the
regions carry each other's values, and nothing fails.
`check_geometry_geoscale()` looks for that.

## Usage

``` r
check_geometry_geoscale(
  x,
  reference = NULL,
  by = NULL,
  geoframe = NULL,
  tolerance = 0.999,
  quiet = FALSE
)
```

## Arguments

- x:

  A
  [`GeoScale`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
  with geometry attached.

- reference:

  Optional `sf` object with one or more features per code: the source
  the geometry came from, or any trusted map of the same regions.

- by:

  Name of the code column of `reference`. Defaults to a column named as
  `geoframe`.

- geoframe:

  The geoframe `reference` describes. Defaults to the leaf geoframe; a
  coarser one compares the dissolved shapes.

- tolerance:

  Share of area two shapes must have in common to count as the same
  shape, between 0 and 1. Default `0.999`.

- quiet:

  `FALSE` (default) warns when a check fails.

## Value

A `data.frame` of class `geoscale_geometry_check` with columns `check`,
`geoframe`, `region`, `status` (`"ok"`, `"note"`, `"warn"` or `"fail"`)
and `detail`, one row per finding. `all(out$status != "fail")` says
whether it passed.

## Details

With a `reference` – an `sf` object that carries the codes – the check
is a proof: every shape of the object is compared with the reference
shape of the same code, and a misplaced shape is reported with the code
it really belongs to.

Without one the object is searched for the marks a misplacement leaves,
which is evidence, not proof:

- `shapes`: empty shapes, and one shape held by several leaves;

- `area`: a weight that holds the areas of the shapes in another row
  order, as happens when the shapes moved after
  [`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md)
  measured them;

- `pieces`: a grouped region whose leaves do not form one connected
  piece. Islands do this legitimately, so it is a warning;

- `order`: whether the constructor re-sorted the rows, after which a
  geometry attached by position cannot be checked.

## See also

[`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md),
[`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md)

## Examples

``` r
if (FALSE) { # \dontrun{
gs <- attach_geometry_geoscale(gs, shapes, by = "code")
check_geometry_geoscale(gs)                         # internal evidence
check_geometry_geoscale(gs, reference = shapes, by = "code")   # proof
} # }
```
