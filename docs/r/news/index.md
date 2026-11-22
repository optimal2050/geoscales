# Changelog

## geoscales 0.8.0

### Breaking changes

- Requires nestedscales 0.3.0 and follows its vocabulary, with no
  deprecated aliases: a *leaf* is a region of the finest layer and one
  row of the leaftable (was “atom”), and the *leaf column* is the
  leaftable column that identifies the leaves (was “key”). A member of a
  geoframe stays a *region*. `key=` now only names the column of a data
  table that holds the codes, and “unit” only a unit of measure.
- Renamed functions: `recast_to_geoatoms()` to
  [`recast_to_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md),
  `recast_from_geoatoms()` to
  [`recast_from_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md),
  `geoscale_key()` to
  [`geoscale_leaf_column()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_leaf_column.md).
  Renamed argument: `key` to `leaf` in
  [`GeoScale()`](https://optimal2050.github.io/geoscales/r/reference/GeoScale.md)
  and
  [`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md).
  The property `GeoScale@key` is `@leaf`,
  [`summary()`](https://rdrr.io/r/base/summary.html) returns `n_leaves`
  (was `n_atoms`),
  [`geoscale_tree()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_tree.md)
  lists the part `leaf` with the kind `leaf column`, and printed output
  and messages say “Leaves” and “leaf”.
- The finest geoframe of
  [`geoscale_example()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_example.md)
  is `cell` (was `atom`), which changes its
  [`geoscale_id()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_id.md).
  The codes `A1` to `A6` and `ROW` are unchanged.
- [`geoscale_labels()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_labels.md)
  returns the columns `geoframe`, `region`, `variant`, `label` (were
  `frame`, `unit`, …), the names
  [`attach_labels_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_labels.md)
  takes. A label table given with a `unit` column is no longer accepted;
  `frame` and `member` are.
- The leaftable has no `region` column any more. The leaf column is the
  finest geoframe’s own column, or the column named by `leaf=` when the
  leaves are finer than the finest geoframe;
  [`geoscale_leaf_column()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_leaf_column.md)
  returns its name. The leaf column in the result of
  [`recast_to_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md)
  carries that name, and
  [`recast_from_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md)
  expects it. `region` is no longer a reserved name and may be used for
  a geoframe at any depth. Objects saved with a `region` leaf column
  must be rebuilt; objects saved while the leaf column was the property
  `key` are still read.
- [`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md)
  no longer falls back to a `region` column for the leaf column: when
  the finest geoframe does not identify the leaves, `leaf=` must be
  given.
- `meta$labels` (the name of one per-leaf leaftable column) is replaced
  by the label table below. `labels=` in
  [`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md)
  now takes that table.
- The first argument of
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
  [`recast_to_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md),
  [`recast_from_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md),
  [`recast_pairs()`](https://optimal2050.github.io/geoscales/r/reference/recast_pairs.md)
  and
  [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
  is `data` (was `x`).
- `weight=` always names a weight of the GeoScale. The data column to
  weight by in
  [`recast_from_geoleaves()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoleaves.md)
  and
  [`recast_pairs()`](https://optimal2050.github.io/geoscales/r/reference/recast_pairs.md)
  is `data_weight=`.

### New features

- Labels per geoframe.
  [`attach_labels_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_labels.md)
  adds display names for regions of any geoframe, in named variants, so
  a region may have alternative names while another geoframe has none; a
  row with `region = NA` names the geoframe itself.
  [`geoscale_labels()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_labels.md)
  returns the table and
  [`geoscale_label()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_labels.md)
  looks names up, giving the code where there is no label. Subsets,
  prunes and zooms keep the labels of what remains, and the plots use
  the default variant.
- [`geoscale_id()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_id.md)
  gives the identity of a GeoScale: its name and a hash of its
  structure.
- [`check_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/check_geometry_geoscale.md)
  checks that each shape of the geometry is on the row of its code.
  Against a reference `sf` that carries the codes it compares shape by
  shape and names the code a misplaced shape belongs to; without one it
  reports empty or repeated shapes, an area weight held in another row
  order, and grouped regions in several pieces.
- Geoframes hidden from plots.
  [`hide_geoframes_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/hide_geoframes_geoscale.md)
  marks geoframes that exist for calculation only, and
  [`gg_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/gg_geoscale.md),
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) leave
  them out;
  [`show_geoframes_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/hide_geoframes_geoscale.md)
  reverses it and `geoscale_geoframes(visible = )` lists either set.
  Recasts, joins and navigation are unaffected.
  `gg_geoscale(geoframes = )` chooses the geoframes of one figure,
  hidden or not.
- [`geoscale_tree()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_tree.md)
  lists the parts of a GeoScale as a tree and marks each one `fixed` (it
  enters the identity), `derived` or `mutable`, naming the function that
  changes it; [`str()`](https://rdrr.io/r/utils/str.html) prints the
  same tree.
- `gg_geoscale(data = )` on the icicle and the stack takes data keyed by
  any geoframe, named by `key=` or found from the columns. The value is
  recast up from that geoframe to every coarser one it nests in; finer
  geoframes are outlined without a fill.
- `gg_geoscale(type = "stack")` fills a single-region geoframe above the
  colouring geoframe (a nation over its zones) with the next colour of
  the same palette; it was neutral grey.

### Bug fixes

- [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
  drawn at a coarser geoframe than the data’s codes filled every region
  with `NA`; the codes are now carried up to the drawn geoframe before
  `fun` is applied. The code column defaults to the `geoframe`-named
  column, then the leaf column, then `region`.
- [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md),
  [`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md),
  [`ne_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/ne_geoscale.md)
  and
  [`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md)
  rebuilt the object from its core parts and dropped its attributes and
  aliases; they now update it in place.

## geoscales 0.7.3

### New features

- [`geoscale_add_weight()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_add_weight.md)
  declares a numeric weight over the atoms of an existing GeoScale –
  `population`, `gdp` or any other basis – so a hierarchy built with
  only `area` can still apportion a quantity sensibly. Takes named
  vectors or a data.frame keyed by the atom column, sets the default
  weight, and refuses a weight that leaves an atom without a value.

- [`geoscale_rule_action()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_rule_action.md)
  reports what each of the seven rules does going up and going down, and
  whether a parent’s value is therefore divisible between its children.
  Only `sum` is: a quantity splits by the weight, while a rate, a price
  or an invariant is replicated unchanged, and `sd` and the two share
  rules have no downward meaning and come back `NA` rather than guessed
  at. It lets a consumer decide per column what a partial selection of
  children does to a parent’s value without asking its caller.

### Bug fixes

- [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md)
  gave each code another code’s geometry when the pruned leaftable was
  not already in nested order. The dissolve now happens before
  construction and the result is passed to
  [`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md),
  which permutes geometry with the rows it re-orders;
  [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md)
  binds positionally and cannot.
- A map with a categorical `z` fell through to ggplot2’s `hue_pal()`,
  which put neighbouring hues on unrelated regions.
  `gg_geoscale(type = "map")` now picks a qualitative scale for a
  discrete fill, and a discrete viridis above six levels, where no
  qualitative set clears the contrast floors.
- The stack fills by the ancestor at the coarsest geoframe rather than
  by the code of each plane, so a child carries its parent’s colour down
  the stack instead of every frame’s codes sharing one ramp.

## geoscales 0.7.2

### Breaking changes

- [`gg_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/gg_geoscale.md)
  replaces `geoscale_autoplot()` and `geoscale_plot()`: one function,
  `type = c("icicle", "stack", "map")`. The old names are gone.
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  returns the same figure;
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) now draws it
  and returns it invisibly, like base
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html).
- The value column is `z` for every figure (the map’s `fill=` is gone)
  and is required whenever `data` is given. `labels=` replaces `label=`.
  The map’s `title`, `subtitle` and `fill_label` are gone: add
  `+ labs(title =, subtitle =, fill =)`.
- `palette = NULL` is each figure’s default scale; `palette = NA` adds
  none. The stack’s bring-your-own-scale spelling was `NULL`.
- `...` goes to the figure’s drawing layer. An argument that belongs to
  another `type` is an error. `precision` applies to the map as well as
  the stack.
- The first argument of the plotting function and of
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  is `object`.

### New features

- [`geoscale_adjacent()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_adjacent.md)
  builds the neighbour matrix of a geoframe from attached geometry:
  which of its codes border which. `contiguity` chooses between
  `"queen"` (contact of any dimension, so features meeting at one corner
  are neighbours) and `"rook"` (a shared border of non-zero length),
  `within` cuts every edge that crosses a coarser geoframe, and
  `isolated = "nearest"` joins an island to its closest permitted
  neighbour. This is what
  `nestedscales::cluster_contiguous(adjacency =)` consumes.

## geoscales 0.7.1

### New features

- `geoscale_autoplot(type = "stack")` gains `view = "pyramid"`, the
  mirror image of `"perspective"`: the coarsest geoframe is the small
  top and the finest the wide base.
- `geoscale_autoplot(type = "stack", outline = "zone")` draws the
  borders of a coarser geoframe over every finer plane, so the groups it
  forms stay visible at the finer resolution; `outline_colour` and
  `outline_linewidth` style them.
- `gap` accepts one value per pair of planes, top to bottom. Under
  `"perspective"` and `"pyramid"` the spacing is scaled with the planes
  it separates, so it stays uniform relative to their size.

## geoscales 0.7.0

### Breaking changes

- Requires nestedscales 0.2.0.
- The class is now spelled `GeoScale` (was `Geoscale`), matching
  `NestedScale`. Function names keep the `geoscale_` prefix. Saved
  GeoScale objects embed the class name: rebuild any `.rds`/`.rda` that
  holds one. No deprecation alias.
- Leaftable rows are in nested order by default: sorted by geoframe,
  coarsest first, each in its member order, with unassigned codes last;
  geometry follows the rows. `row_order = "given"` keeps the rows as
  supplied.
- The
  [`recast()`](https://optimal2050.github.io/nestedscales/r/reference/recast.html)
  method follows the generic’s new arguments:
  `recast(x, scale, target, source = NULL, ...)`.

### Deprecations

- `from` and `to` are now `source` and `target` in the navigation, map
  and recast functions
  ([`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
  [`recast_pairs()`](https://optimal2050.github.io/geoscales/r/reference/recast_pairs.md),
  the geoatom halves), matching nestedscales. The old names still work,
  with a deprecation warning, and will be removed in a later release.

## geoscales 0.6.0

### Breaking changes

- `geoscale_map(gs, from, to)` now takes the Geoscale first and maps
  between two of its geoframes only; the map between two Geoscales is
  `geoscale_map_between(from, to)`. The registry follows the same split:
  `register_geoscale_map(gs, from, to, map)` /
  `get_geoscale_map(gs, from, to)` for geoframes of one object,
  `register_geoscale_map_between(from, to, map)` /
  `get_geoscale_map_between(from, to)` for two objects.
  [`list_geoscale_maps()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_map.md)
  and
  [`clear_geoscale_maps()`](https://optimal2050.github.io/geoscales/r/reference/clear_geoscale_maps.md)
  are unchanged. No deprecation aliases.
- The shared core package is now called nestedscales (formerly
  multiscales). `data-raw/iceland_wind.rds` (used by the README and the
  “Get started” vignette) was re-stamped with
  `data-raw/restamp_iceland_wind.R`.

### New features

- [`zoom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/zoom_geoscale.md)
  builds a telescoping geoframe with full detail in a focus area and
  progressively coarser rings elsewhere. Its ordered input is named
  `geoframes=` to match the package vocabulary.

### Bug fixes

- Panel-data expansion to geoatoms now declares its expected
  many-to-many join and no longer emits a dplyr relationship warning.

### Dependencies

- `timescales` is no longer a suggested dependency. The optional
  time-and-space example is non-executing package documentation, and
  sibling API parity is checked separately in project CI.

## geoscales 0.5.4

### The shared core

- **`Geoscale` is now a subclass of the `nestedscales` `NestedScale`.**
  Every nestedscales verb accepts a Geoscale directly, and geometry
  follows any subset. `@geoframes` and the constructor are unchanged.

- **Breaking: Geoscale objects saved with an earlier version must be
  rebuilt.** An S7 object stores its class with it, so an old Geoscale
  is not a `NestedScale`: simple accessors still answer, but
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
  [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md),
  [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
  and the other verbs fail with “`x` must be a NestedScale object”.
  Rebuild it from its own stored parts:

  ``` r

  m <- attr(old, "meta")
  gs <- geoscale_from_leaftable(attr(old, "leaftable"),
                                geoframes = attr(old, "geoframes"),
                                weights = m$weights, name = m$name)
  if (!is.null(attr(old, "geometry"))) {
    gs <- attach_geometry_geoscale(gs, attr(old, "geometry"))
  }
  ```

- [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
  [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md),
  [`geoscale_map()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_map.md),
  the navigation verbs,
  [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md),
  [`geoscale_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_share.md),
  [`geoscale_coverage()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_coverage.md)
  and the rule and map registries now run on `nestedscales`. Results are
  unchanged. On lazy inputs (arrow, dtplyr)
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
  no longer scans the data for its warnings, and it accepts the `region`
  key as `from`.

- **`timescales` moves from `Imports` to `Suggests`.** It was a hard
  dependency for exactly one symbol – the
  [`recast()`](https://optimal2050.github.io/nestedscales/r/reference/recast.html)
  generic – which is now owned by `nestedscales`. Installing geoscales
  no longer pulls in a calendar package and `lubridate`. timescales
  stays in `Suggests` because the mirror-parity test compares the two
  packages’ export surfaces.

- `nestedscales` is added to `Imports` and the
  [`recast()`](https://optimal2050.github.io/nestedscales/r/reference/recast.html)
  generic is re-exported from there.
  [`geoscales::recast`](https://optimal2050.github.io/nestedscales/r/reference/recast.html)
  resolves and dispatches on `Geoscale` exactly as before; the source
  frame is still `from_geoframe`, since `from` is the dispatch argument
  and names the scale.

- New rule `"share"`: share within parent. Each source region’s value
  over its parent-group total, keyed at the *source* geoframe –
  `recast_geoscale(x, gs, from = "nuts3", to = "nuts0", rule = "share")`
  gives each nuts3’s share of its country, summing to 1 per parent. The
  parent is `to`, or the new `parent=` argument (default: the geoframe
  above `from`); `from` must nest within it. `"logshare"` is the same
  computation with a log-scale display intent. Mirrored in timescales.

- The stack and icicle data fills accept `rule = "share"`: each plane is
  coloured by its regions’ share within the nearest coarser plane it
  nests in (the coarsest by the grand total), legend “Share”. `"share"`
  draws on a fixed linear 0..1 scale, `"logshare"` (the same
  computation) on a fixed log10 percent scale (0.01%..100%) for when
  sibling counts differ by orders of magnitude; fixed limits either way,
  so any two share figures are colour-comparable. `palette = NULL` plus
  your own scale overrides it.

- The default viridis palette option is `"H"` (was `"G"`), and the
  icicle’s data fill now honours `palette=` instead of hard-coding one.

- [`recast_pairs()`](https://optimal2050.github.io/geoscales/r/reference/recast_pairs.md)
  aggregates data keyed by a *pair* of regions – transmission corridors,
  trade flows, commuting matrices. Both endpoints are mapped, pairs that
  land inside a single target region are dropped as internal, and the
  rest are aggregated by rule. `directed = FALSE` merges `A->B` with
  `B->A`.

- `recast_from_geoatoms(weight =)` now names a column of `x`, so the
  weight can vary by identifier – a capacity-weighted efficiency differs
  by year and vintage. Previously only a column literally named `weight`
  was honoured.

- `na_rm = TRUE` in `recast_from_geoatoms()` and
  [`recast_pairs()`](https://optimal2050.github.io/geoscales/r/reference/recast_pairs.md)
  reads an `NA` as “this member says nothing” instead of letting it make
  the whole group `NA`. Only an all-`NA` group stays `NA`, and a
  weighted mean drops the weight of each `NA` member so the divisor
  still matches.

- `rule` and `weight` accept a named vector, one entry per value column.
  One slot of a model can hold an extensive and an intensive quantity
  side by side, which previously took two calls.

- [`summary()`](https://rdrr.io/r/base/summary.html) output now prints
  with its formatted view from user code: the local `print` binding S7
  leaves in the namespace had captured the `S3method()` registration of
  `print.summary_Geoscale`, so the method was invisible outside the
  package. Registered against base’s `print` in `.onLoad` (same fix in
  timescales).

- Icicle labels no longer overprint: `geoscale_autoplot()` now draws
  labels widest-rectangle-first with `check_overlap = TRUE` (matching
  the timescales icicle), so narrow regions lose their label instead of
  smearing the band.

- `Remotes:` added to DESCRIPTION so CI and `pak` users can resolve the
  GitHub-only timescales Import and energypal Suggests from GitHub (the
  packages are not on CRAN/r-universe yet). Drop the field at CRAN
  submission time.

### Base-generic methods on Geoscale

- [`summary()`](https://rdrr.io/r/base/summary.html) — the quantitative
  complement of [`print()`](https://rdrr.io/r/base/print.html): member
  and unassigned-atom counts, per-weight totals, sampled coverage (with
  the parent’s name), the adjacent-geoframe NESTING table (cross-cutting
  pairs flagged with offender counts), geometry status (sf-free).
  Returns a `"summary_Geoscale"` with its own print.
- [`names()`](https://rdrr.io/r/base/names.html) — the geoframe names
  (identical to
  [`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md)).
- [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) and
  [`ggplot2::fortify()`](https://ggplot2.tidyverse.org/reference/fortify.html)
  — the leaftable, so `ggplot(gs) + geom_*()` works directly. All
  mirrored by the timescales twins.

## geoscales 0.5.0

Hard-break release: the sibling APIs of timescales and geoscales were
harmonized against each other (the pairing table and naming rules live
in the stack-wide CONVENTIONS.md, “Sibling API mirror”). NO deprecation
aliases are kept – old names are gone, not wrapped.

### Breaking changes

- Registries follow `register_<class>_<thing>` everywhere: the
  `geo_map`/`geo_rule`/`geo_provider` registry families are now
  `register_geoscale_map`/`get_geoscale_map`/`list_geoscale_maps`/
  `clear_geoscale_maps`, `register_geoscale_rule`/`get_geoscale_rule`/
  `list_geoscale_rules`/`clear_geoscale_rules`, and
  `register_geoscale_provider`/`get_geoscale_provider`/
  `list_geoscale_providers`. `GEO_RULES` is now `GEOSCALE_RULES`.
- The deprecated shim family is REMOVED (29 `geo_*` aliases plus
  `geoscale_levels`, `is_valid_level`, `geoscale_from_leaves`,
  `CORE_LEVELS`; archived under `drafts/`).
- `geoscale_regions(x, geoframe = NULL)` – `geoframe` now defaults to
  the finest geoframe (the atoms). The required-geoframe rule is about
  arguments that take region CODES; this one only selects the output.

### New

- `coords_to_region(x, gs, geoframe = NULL)` – the spatial twin of
  [`timescales::datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.html):
  match point observations (sf/sfc or a data.frame with `lon`/`lat`
  columns) to the regions whose geometry contains them; `NA` outside
  every region.
- `geoscale_leaftable(x)` – exported accessor for the leaf table (stop
  reaching for `x@leaftable`).

## geoscales 0.4.2

### Breaking changes

- A filtered Geoscale is now book-kept as a SAMPLE (the spatial mirror
  of a partial calendar’s `year_fraction`):
  [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md)
  writes `meta$coverage` (per-weight kept fraction of the ROOT parent,
  so filters compose), `meta$parent_totals` (making coverage verifiable
  by the validator), `meta$parent_name`, and mangles `meta$name` to
  `"parent[geoframe:codes]"` – so two different samples of one parent
  can no longer poison each other’s crosswalk-registry entries or
  collide in
  [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
  column names.
  [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md)
  renames to `"parent@geoframe"` (the `prune_calendar()` convention),
  now preserves the FULL meta (`crs`, `source`, `labels`), reflects
  dropped unassigned atoms in coverage, and keeps attached geometry by
  dissolving it per new atom (`keep_geometry = FALSE` to opt out). Read
  the fraction with the new `geoscale_coverage(x, weight)`. Code that
  relied on a subset keeping its parent’s name can find the parent in
  `meta$parent_name`.

### New features

- [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
  and
  [`theme_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md):
  composable ggplot2 choropleth layer and map theme, mirroring
  [`timescales::geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.html)’s
  design (column-name arguments, one standard
  [`geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)
  layer, solid white background for dark-mode pages).
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on a Geoscale
  now dispatches to `geoscale_autoplot()`.
- `get_geo_map()` and `list_geo_maps()` complete the crosswalk registry;
  `register_geo_map()`/`clear_geo_maps()` gain examples.
- [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md),
  [`geom_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/geom_geoscale.md)
  and the stack view gain an opt-in `precision=` for snapping
  near-coincident boundaries before the dissolve (workaround for sources
  with floating-point-jittered shared edges; default off).
- `geoscale_autoplot(type = "stack")` draws the layer-stack view: one
  map plane per geoframe, the same atoms dissolved at every resolution
  (requires attached geometry). Points of view come as presets
  (`view = "oblique"/"top-down"/"cavalier"/"cabinet"/"military"/ "isometric"/"dimetric"/"trimetric"/"perspective"`)
  or via `angle`/`ratio` (oblique) and raw `shear`/`depth`; `rotate=`
  turns the plane in place (point North anywhere), `direction=` flips
  the stack, and the default `gap` leaves planes almost touching with a
  slight overlap.
- The stack view takes data: `data`/`z` colour every plane by an
  atom-keyed value, recast onto each coarser plane with
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
  (`rule`, default `"weighted_mean"`) so the whole stack shares one
  continuous scale; `labels=` writes region names on chosen planes and
  `palette=` picks the viridis option — or `NULL` to bring your own
  scale, e.g. energypal’s Global Wind Atlas colours on their absolute
  breaks. The stack canvas now hugs the content: tight x/y limits, left
  room sized to the geoframe names, legend pulled in close.
- The structure icicle carries data too:
  `geoscale_autoplot(data =, z =)` fills every band with the value
  recast to that geoframe (atoms keep their values, coarser bands
  aggregate by `rule` – `"weighted_mean"` default), with contrast-aware
  labels – the 2D twin of the stack’s data fill. The README gained a
  five-point “What geoscales offers” intro mirrored with timescales.
- Stack guides and borders: `frame=` draws each plane’s outline (its
  “sheet”) through the same projection, `frame_fill=` fills the sheets
  (best mostly transparent – glass panes), and `connectors=` adds dashed
  corner-to-corner guides between planes – curved shapes become easy to
  read in oblique views. `colour=`/`linewidth=` style the region
  borders, recycled per plane (defaults `"grey35"`/`0.2`, ggplot2’s own
  sf polygon border). Same additions in
  `timescales::calendar_autoplot(type = "stack")`. The README front page
  shows it on Iceland’s onshore wind resource, clustered from the Global
  Wind Atlas per region (`data-raw/iceland_wind.R`; build walk-through
  in
  [`vignette("geoscales")`](https://optimal2050.github.io/geoscales/r/articles/geoscales.md)).

### Bug fixes

- [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md)
  no longer fails with an opaque “differing number of rows” when
  [`sf::st_union()`](https://r-spatial.github.io/sf/reference/geos_combine.html)
  returns several parts for one code (seen with s2-invalid source
  polygons): the parts are collapsed into the code’s single dissolved
  geometry. Healing the source with
  [`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)
  before attaching remains the better fix.

### Documentation

- The documentation is restructured to mirror timescales: the intro is a
  short 5-minute tour; new
  [`vignette("concepts")`](https://optimal2050.github.io/geoscales/r/articles/concepts.md)
  (with the shared \*scales glossary),
  [`vignette("data-structures")`](https://optimal2050.github.io/geoscales/r/articles/data-structures.md)
  and
  [`vignette("data-manipulation")`](https://optimal2050.github.io/geoscales/r/articles/data-manipulation.md)
  (including a runnable time-and-space
  [`recast()`](https://optimal2050.github.io/nestedscales/r/reference/recast.html)
  chain and backend examples); the plotting article is rewritten on the
  current API as “Visualization with ggplot2” with a real-map tour of
  Iceland built from Natural Earth, with area data attached (old URL
  redirects). Vignette code follows the stack-wide tidyverse + `|>`
  style; README drops the retired word “levels”.

## geoscales 0.2.0.9000

First working line: the `Geoscale` class, a conserving conversion core
mirroring timescales, navigation, plotting, and the Natural Earth
provider – under one naming convention shared with timescales.

### Breaking changes

- `Geoscale@levels` is now `@geoframes` and `@leaves` is `@leaftable`
  (`@members` unchanged), matching timescales; `level`/`levels`
  arguments are `geoframe`/`geoframes` across the API, and derived
  tables use `parent_geoframe`/`child_geoframe` columns.
- A value column with neither `rule=` nor a `register_geo_rule()` entry
  is now an error; the silent `sum` fallback is gone.
- Materialised
  [`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md)
  results complete to the full target vocabulary in member order (`NA`
  where nothing landed); lazy backends return observed groups until
  collected.
- [`join_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/join_geoscale.md)
  attaches a label column named after the Geoscale, with membership and
  share/weight columns `"<name>."`-prefixed (`meta$name` is now required
  for conversion and attach;
  [`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
  derives a default). Existing columns are never overwritten (error).
- Conflicting registered per-column weights build one crosswalk per
  weight instead of silently splitting equally.
- The
  [`recast()`](https://optimal2050.github.io/nestedscales/r/reference/recast.html)
  method argument `from_level` is now `from_geoframe`.

### New features

#### Conversion

- `recast_geoscale(x, gs, from, to, rule)` converts between geoframes –
  aggregation and disaggregation as one operation through the atom
  layer, cross-cutting geoframes included; identifier (panel) columns
  are preserved as groups; `to =` also accepts another named Geoscale
  (targeting its atom layer via shared atom keys).
- `recast_to_geoatoms()` / `recast_from_geoatoms()` expose the route
  halves; chaining them across two Geoscales converts between region
  systems that share atom keys.
- `geoscale_map(from, to, gs =, weight =)` materialises the crosswalk
  (atom counts and weights per overlapping pair, within one Geoscale or
  across two); `register_geo_map()` installs exact crosswalks,
  `clear_geo_maps()` resets.
- All converters run over `data.frame`, tibble, `data.table`, dtplyr,
  and arrow inputs; results come back in the input’s class, and lazy
  inputs return the uncollected query unless `collect = TRUE`.
- Rules `sum`, `weighted_mean`, `mean`, `copy`, and (new) `sd`, each
  defined in both directions; per-column defaults via
  `register_geo_rule()` / `get_geo_rule()` / `list_geo_rules()` /
  `clear_geo_rules()`; `na_action = c("drop", "error", "keep")` for
  partial coverage.
- The
  [`recast()`](https://optimal2050.github.io/nestedscales/r/reference/recast.html)
  generic (owned by timescales, now in Imports) chains time and space:
  `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")`; the source
  geoframe is inferred from `x`’s columns or passed as `from_geoframe=`.

#### Core, navigation, providers

- `Geoscale`: an S7 class holding `@leaftable` (one row per atom),
  `@geoframes` (ordered coarsest first), `@members`, optional
  `@geometry`, and `@meta`; geoframes are partitions of atoms, not a
  tree, so cross-cutting region systems are first-class.
- Construction layers:
  [`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md),
  [`geoscale_build()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_build.md)
  (ragged parent-child crosswalks),
  [`geoscale_from_provider()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_provider.md);
  plus
  [`geoscale_example()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_example.md).
- Navigation and subsetting:
  [`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md),
  [`geoscale_regions()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_regions.md),
  [`geoscale_rank()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_rank.md),
  [`geoscale_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_family.md),
  [`geoscale_nests()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_nests.md),
  [`geoscale_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_ancestry.md)
  (atom-mediated, never a transitive closure),
  [`geoscale_children()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.md)
  / `_parents()` / `_descendants()` / `_ancestors()`,
  [`geoscale_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_share.md),
  [`filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.md)
  / `gs[geoframe, region]`,
  [`prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.md).
  A `geoframe` argument is required throughout – codes are not unique
  across geoframes.
- Geometry and plotting (`sf` and ggplot2 in Suggests):
  [`attach_geometry_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/attach_geometry_geoscale.md),
  [`geoscale_geometry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geometry.md)
  (dissolve),
  [`add_area_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/add_area_geoscale.md),
  `geoscale_autoplot()` (icicle, no geometry needed), `geoscale_plot()`
  (choropleth),
  [`geoscale_layout()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_layout.md).
- Providers: `register_geo_provider()` / `get_geo_provider()` /
  `list_geo_providers()`; Natural Earth via
  [`ne_source()`](https://optimal2050.github.io/geoscales/r/reference/ne_source.md)
  /
  [`ne_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/ne_geoscale.md)
  with source and scale recorded in `meta`. The package ships no maps
  and selects no boundaries; known Natural Earth pitfalls
  (`iso_a3 == -99`, unreliable areas at 1:110m) are handled.

### Deprecations

Old names warn and forward; removal before 1.0: the `geo_*` family -\>
`verb_geoscale()` / `geoscale_*()` / `register_geo_*()` (e.g.
`geo_recast()` -\>
[`recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.md),
`geo_levels()` -\>
[`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md)),
and the 2026-08 lattice renames `geoscale_from_leaves()` -\>
[`geoscale_from_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_from_leaftable.md),
`geoscale_levels()` -\>
[`geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.md),
`is_valid_level()` -\>
[`is_valid_geoframe()`](https://optimal2050.github.io/geoscales/r/reference/is_valid_geoframe.md),
`CORE_LEVELS` -\> `CORE_GEOFRAMES`.

### Documentation

- [`vignette("geoscales")`](https://optimal2050.github.io/geoscales/r/articles/geoscales.md)
  gains crosswalk, route-halves, attach, backends, and glossary
  sections; version files (`DESCRIPTION`, `VERSION`, NEWS) agree on
  0.2.0.9000.
