# Testing guide (timescales + geoscales — one system, two packages)

The suites are mirrored: identical helper layers, identical conventions,
`tests/README.md` in each package is the quick reference. This guide is
the recipes; everything here applies to both siblings with the
vocabulary swapped (calendar↔geoscale, timeframe↔geoframe,
timeslice↔region, timebase↔geoatoms).

## Adding a test for a verb

1. Take fixtures from `helper-fixtures.R` — never rebuild a calendar or
   value table inline.
2. State facts through the invariant expectations
   (`helper-invariants.R`) where one applies: conservation, envelope,
   round-trip, composition, join contract, completion. A raw
   `expect_equal` on hand-computed numbers is for genuinely one-off
   values.
3. If the fact holds for every rule/direction, it belongs in the
   `test-properties.R` sweep, not a one-off file.
4. Tag it: `# @covers <export> depth=U|P|B [backends=...]` above the
   `test_that()`. `tools/coverage/build_matrix.R --check` (also run by
   the suite) fails on typos.

## Adding a backend case

`expect_backend_contract(input, make_call, key_cols, value_cols, ...)`
states everything (classes, laziness, collect, completion asymmetry).
Give `make_call` a `collect = NULL` argument and pass it through. Gate
expensive sweeps with `skip_if_tier_below("full")`; leave one fast-tier
smoke per lazy engine.

## Registries in tests

`setup-registries.R` guarantees a clean slate per suite run. A test that
registers something should still clean up after itself when it can
(`clear_*` with the specific name) so file order never matters.

## Regenerating artifacts

```sh
Rscript tools/coverage/build_matrix.R    # coverage matrix (committed)
Rscript tools/specs/make_goldens.R       # cross-language goldens
```

Goldens are byte-stable: regenerating twice produces identical files.
A behavior change must regenerate them in the same commit — the diff IS
the review artifact.

## Traps (each learned the hard way)

- **`$` partial-matches list names.** `meta$coverage` silently returns
  `meta$coverage_class`. Always `[[ ]]` on meta fields.
- **`.datatable.aware <- TRUE` is load-bearing** for the dtplyr backend
  (R/backend.R); without it `[.data.table` falls through.
- **arrow 25.0.0 corrupts POSIXct at ingestion** — backend cells whose
  INPUT carries datetimes skip arrow (`skip=` argument of
  `expect_backend_contract`).
- **Load `sf` before geoscales geometry work in fresh Rscript
  sessions** — segfaults otherwise (geoscales side).
- **`recast_calendar` needs a single `year`** — multi-year goes through
  the timebase route, driven by the `year` column of `x`.
- **On a grid as fine as the shares, `mean == weighted_mean`** (each
  grid point is equal-duration). Distinguishing them needs a grid
  coarser than the shares (`by = "month"` for m12).
- **`recast_from_geoatoms` silently partial-aggregates missing atoms**
  (unlike the fused verb, which warns and yields NA for a missing
  source). Pinned in test-properties.R; flagged as a route-vs-fused
  asymmetry awaiting a maintainer ruling.
- Running a single file with bare `Rscript` skips helper files? No —
  testthat loads `helper-*.R` for `devtools::test(filter=)` too; but a
  bare `testthat::test_file()` call does NOT source `setup-*.R` in
  older testthat versions. Prefer `devtools::test(filter = ...)`.
