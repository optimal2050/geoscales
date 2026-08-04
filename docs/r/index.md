# geoscales

> Nested regions and spatial hierarchies for optimization and simulation
> models.

`geoscales` is the **spatial-domain** package of the optimal2050
modeling stack and the spatial companion to
[`timescales`](https://github.com/optimal2050/timescales).

This is a **multi-language** project. The R package is the current focus
(Phase 1); a C++ core (Phase 2) and a Python port (Phase 3) are planned.

## Documentation

- **[Project site](https://optimal2050.github.io/geoscales/)** — entry
  point for all language flavours
- **[R reference and
  articles](https://optimal2050.github.io/geoscales/r/)**

## Status

🚧 Pre-release — APIs are unstable. Repository is private until first
pre-release.

## What it does

A `Geoscale` is a nested spatial partition: a flat table of weighted
leaf regions (“atoms”) plus the ordered levels that group them.

``` r

library(geoscales)
gs <- geoscale_example()

# Aggregation and disaggregation are ONE verb. Direction comes from the
# level ranks; totals are preserved either way.
cap <- data.frame(atom = c("A1","A2","A3","A4","A5","A6"),
                  capacity = 1:6)

geo_recast(cap, gs, from = "atom", to = "country", rule = "sum")
geo_recast(cap, gs, from = "atom", to = "state",  rule = "weighted_mean",
           weight = "pop")
```

Two things about space that the time domain does not have to deal with,
and which shape the whole design:

- **Levels need not nest.** In India’s IDEEA region table, the `reg32`
  code `APY` merges Andhra Pradesh with *part of* Puducherry, so `reg35`
  does not nest inside `reg32`. Every conversion therefore routes
  through the atom layer, and cross-cutting levels work without special
  handling.
- **Region codes are not unique across levels.** 46 of 62 IDEEA codes
  appear at more than one level (`AN` at seven). So `level` is a
  required argument everywhere — nothing is inferred from a bare code.

### No bundled maps

The package ships integration code, not data: no `data/` directory and
no boundaries. `rnaturalearth` is the recommended source and is wired up
out of the box, behind a pluggable provider interface.

``` r

gs <- ne_geoscale(scale = 110)                 # coarse, fast
gs <- ne_geoscale(scale = 10)                  # detailed; use this for areas
```

The source and scale are recorded in `meta`, so a `Geoscale` is
self-documenting. See
[`vignette("from-naturalearth")`](https://optimal2050.github.io/geoscales/r/articles/from-naturalearth.md)
for the Natural Earth pitfalls the provider handles for you.

## Installation

``` r

# From GitHub (private during pre-release; requires access)
# remotes::install_github("optimal2050/geoscales")
```

After pre-release, also via
[r-universe](https://optimal2050.r-universe.dev/):

``` r

# install.packages("geoscales", repos = "https://optimal2050.r-universe.dev")
```

## Repository layout

    geoscales/
    ├── DESCRIPTION, NAMESPACE, R/, man/, tests/, vignettes/   # R package (root)
    ├── inst/include/geoscales/                                # C++ headers (Phase 2)
    ├── src/                                                   # Rcpp glue (Phase 2)
    ├── cpp/                                                   # standalone C++ core (Phase 2)
    ├── python/                                                # Python package (Phase 3)
    ├── docs/                                                  # unified Quarto site
    ├── specs/                                                 # cross-language golden tests
    ├── benchmark/                                             # cross-language benchmarks
    └── .github/workflows/                                     # CI

## License

Apache-2.0. See
[LICENSE](https://optimal2050.github.io/geoscales/r/LICENSE) and
[NOTICE](https://optimal2050.github.io/geoscales/r/NOTICE).
