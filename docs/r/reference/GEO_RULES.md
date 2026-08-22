# Supported aggregation rules

Each rule defines behaviour in **both** directions. Direction is taken
from the geoframe ranks, so aggregation and disaggregation are one
operation:

## Usage

``` r
GEO_RULES
```

## Format

A character vector of length 5.

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

## Examples

``` r
GEO_RULES
#> [1] "sum"           "weighted_mean" "mean"          "copy"         
#> [5] "sd"           
```
