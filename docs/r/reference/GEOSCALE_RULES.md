# Supported aggregation rules

Each rule defines behaviour in **both** directions. Direction is taken
from the geoframe ranks, so aggregation and disaggregation are one
operation:

## Usage

``` r
GEOSCALE_RULES
```

## Format

A character vector of length 7.

## Details

- `sum`:

  Up: sum. Down: split proportionally to the weight. For extensive
  quantities (capacity, demand, area, population).

- `weighted_mean`:

  Up: weight-weighted mean. Down: copy unchanged. For intensive
  quantities (efficiency, price, capacity factor).

- `mean`:

  Up: unweighted mean. Down: copy unchanged.

- `copy`:

  Up: the common value, erroring if it is not constant. Down: copy
  unchanged. For region-invariant scalars.

- `sd`:

  Up: standard deviation over the atoms (aggregation only; going down it
  degenerates to `NA` for single-atom groups).

- `share`:

  Share within parent: each source region's value divided by the total
  over its parent group. Unlike every other rule the result stays keyed
  at the **source** geoframe – the recast target (or `parent=`) names
  the parent – so it cannot be mixed with other rules in one call (the
  two share rules mix freely, being one computation). For building
  distribution keys and normalised profiles; requires `from` to nest
  within the parent.

- `logshare`:

  The same computation as `share` – the values ARE shares – but figures
  draw it on a fixed log10 percent scale (0.01%..100%), where `share`
  gets a fixed linear 0..1 scale. Use it when sibling counts differ by
  orders of magnitude and the linear scale flattens the crowded groups.

## Examples

``` r
GEOSCALE_RULES
#> [1] "sum"           "weighted_mean" "mean"          "copy"         
#> [5] "sd"            "share"         "logshare"     
```
