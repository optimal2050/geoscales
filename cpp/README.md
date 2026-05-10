# C++ core (Phase 2 — not yet implemented)

This directory will hold the standalone C++17 implementation of `geoscales`.

## Planned layout

```
cpp/
├── CMakeLists.txt
├── include/geoscales/    # public headers (mirrored to ../inst/include/geoscales/)
├── src/                  # implementation
├── tests/                # Catch2 unit tests
└── examples/
```

Headers will also be exposed under `../inst/include/geoscales/` so other R
packages can depend via `LinkingTo: geoscales`.

The R package will retain a pure-R fallback for portability; the C++ core is
opt-in for hot paths.
