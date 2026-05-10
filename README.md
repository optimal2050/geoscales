# geoscales

> Nested regions and spatial hierarchies for optimization and simulation models.

`geoscales` is the **spatial-domain** package of the optimal2050 modeling stack
and the spatial companion to [`timescales`](https://github.com/optimal2050/timescales).

This is a **multi-language** project. The R package is the current focus
(Phase 1); a C++ core (Phase 2) and a Python port (Phase 3) are planned.

## Status

🚧 Pre-release — APIs are unstable. Repository is private until first
pre-release.

## Installation

```r
# From GitHub (private during pre-release; requires access)
# remotes::install_github("optimal2050/geoscales")
```

After pre-release, also via [r-universe](https://optimal2050.r-universe.dev/):

```r
# install.packages("geoscales", repos = "https://optimal2050.r-universe.dev")
```

## Repository layout

```
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
```

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
