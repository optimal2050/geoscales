# Python package (Phase 3 — not yet implemented)

This directory will hold the Python distribution of `geoscales`, built on top
of the C++ core via [nanobind](https://nanobind.readthedocs.io/) and
[scikit-build-core](https://scikit-build-core.readthedocs.io/).

## Planned layout

```
python/
├── pyproject.toml
├── CMakeLists.txt        # delegates to ../cpp/
├── src/geoscales/        # Python sources
└── tests/                # pytest
```

Distribution: PyPI wheels via `cibuildwheel`.
