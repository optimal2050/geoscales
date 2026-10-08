# =============================================================================
# Filtering, navigation and derived hierarchy tables
# =============================================================================
# Neither `timeslices` nor `timescales` has any `[` or filter method — the
# only trace is a commented-out generic. For regions this is central, so it is
# designed in from the start.
#
# Region codes repeat across geoframes (46 of 62 in IDEEA; "AN" appears at seven
# geoframes), so `geoframe` is ALWAYS a required argument. Nothing is inferred from
# a bare code.
#
# All derived tables are computed on demand. Nothing is cached on the object.
# =============================================================================

#' Regions present at a geoframe (the members)
#'
#' The required-geoframe rule applies to arguments that take region CODES
#' (codes repeat across geoframes, so nothing is ever inferred from a bare
#' code); `geoframe` here only selects the output, so it may default to the
#' finest geoframe (the atoms) — the twin of
#' `timescales::calendar_timeslices(x, timeframe = NULL)`.
#'
#' @param x A [`Geoscale`].
#' @param geoframe A single geoframe name, or `NULL` (default) for the
#'   finest geoframe.
#'
#' @return A character vector of region codes, in the object's canonical order.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_regions(gs, "state")
#' geoscale_regions(gs)          # the atoms
#' @export
geoscale_regions <- function(x, geoframe = NULL) {
  .check_geoscale(x)
  if (is.null(geoframe)) geoframe <- geoscale_geoframes(x, finest = TRUE)
  .check_geoframe(x, geoframe)
  S7::prop(x, "members")[[geoframe]]
}

#' Immediate parent-child table between two geoframes
#'
#' @param x A [`Geoscale`].
#' @param parent,child Geoframe names. Defaults to every adjacent pair in
#'   `x@geoframes`.
#'
#' @return A `data.frame` with columns `parent_geoframe`, `parent`,
#'   `child_geoframe`, `child`. Atoms unassigned at either geoframe are omitted.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_family(gs, "state", "zone")
#' @export
geoscale_family <- function(x, parent = NULL, child = NULL) {
  .check_geoscale(x)
  if (!is.null(parent) || !is.null(child)) {
    .check_geoframe(x, parent, "parent")
    .check_geoframe(x, child, "child")
  }
  .geoframe_cols(nestedscales::scale_family(x, parent, child))
}

# nestedscales names the frame columns `parent_frame`/`child_frame`.
#' @noRd
.geoframe_cols <- function(d) {
  names(d) <- sub("_frame$", "_geoframe", names(d))
  d
}

#' Do two geoframes nest?
#'
#' Tests whether every code at the finer geoframe falls entirely within a single
#' code at the coarser geoframe. Real hierarchies often fail this: IDEEA's
#' `reg32` code `APY` merges Andhra Pradesh with part of Puducherry, so
#' `reg35` does not nest inside `reg32`.
#'
#' Nesting is *not* required by [`Geoscale`] — [`recast_geoscale()`] routes through
#' the atom layer and works either way. This function is a diagnostic.
#'
#' @param x A [`Geoscale`].
#' @param parent,child Geoframe names.
#'
#' @return `TRUE` or `FALSE`. When `FALSE`, the offending child codes are
#'   attached as the `"offenders"` attribute.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_nests(gs, "country", "state")  # TRUE
#' geoscale_nests(gs, "state", "zone")     # FALSE - they cross-cut
#' @export
geoscale_nests <- function(x, parent, child) {
  .check_geoscale(x)
  .check_geoframe(x, parent, "parent")
  .check_geoframe(x, child, "child")
  nestedscales::scale_nests(x, parent, child)
}

#' Ancestry between all geoframe pairs
#'
#' Every `(coarser, finer)` code pair that shares at least one atom, for all
#' geoframe pairs.
#'
#' Computed **atom-mediated**, directly from `@leaftable` — deliberately not as a
#' transitive closure of [`geoscale_family()`]. `timeslices` can use a closure
#' because time geoframes genuinely nest; spatial geoframes cross-cut, and a closure
#' then manufactures false relationships. In the example Geoscale, zone `ZB`
#' straddles both countries, so closing `country -> state -> zone -> atom`
#' would wrongly report country `N` as an ancestor of atom `A5`, which lies in
#' country `S`.
#'
#' For geoframes that do not nest this relation is *overlap*, not containment —
#' test a given pair with [`geoscale_nests()`].
#'
#' Geoframe columns are retained because region codes are not unique across
#' geoframes: in the example, `"N1"` exists at both `state` and `zone`, so a bare
#' `(parent, child)` pair would read as a self-loop.
#'
#' @param x A [`Geoscale`].
#'
#' @return A `data.frame` with columns `parent_geoframe`, `parent`,
#'   `child_geoframe`, `child`.
#'
#' @examples
#' head(geoscale_ancestry(geoscale_example()))
#' @export
geoscale_ancestry <- function(x) {
  .check_geoscale(x)
  out <- .geoframe_cols(nestedscales::scale_ancestry(x))
  out <- out[order(out$parent_geoframe, out$parent,
                   out$child_geoframe, out$child), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Navigate a region hierarchy
#'
#' `geoscale_children()` and `geoscale_parents()` step one geoframe; `geoscale_descendants()`
#' and `geoscale_ancestors()` follow the transitive closure.
#'
#' `geoframe` is required in every case — region codes are not unique across
#' geoframes, so a bare code is ambiguous.
#'
#' @param x A [`Geoscale`].
#' @param geoframe Geoframe that `region` belongs to.
#' @param region Character vector of region codes at `geoframe`.
#' @param to Target geoframe. For `geoscale_children()`/`geoscale_parents()` this defaults
#'   to the adjacent geoframe; for the transitive versions, `NULL` means all
#'   geoframes below/above.
#'
#' @return `geoscale_children()` and `geoscale_parents()` return a character vector of
#'   codes at a single geoframe. `geoscale_descendants()` and `geoscale_ancestors()` span
#'   several geoframes and so return a `data.frame` with columns `geoframe` and
#'   `region` — a bare character vector would be ambiguous, since the same
#'   code can occur at more than one geoframe.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_children(gs, "country", "N")
#' geoscale_parents(gs, "state", "N1", to = "country")
#' geoscale_descendants(gs, "country", "N")
#' geoscale_ancestors(gs, "atom", "A5")
#' @name geoscale_navigate
NULL

#' @rdname geoscale_navigate
#' @export
geoscale_children <- function(x, geoframe, region, to = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  if (!is.null(to)) .check_geoframe(x, to, "to")
  nestedscales::scale_children(x, geoframe, region, to)
}

#' @rdname geoscale_navigate
#' @export
geoscale_parents <- function(x, geoframe, region, to = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  if (!is.null(to)) .check_geoframe(x, to, "to")
  nestedscales::scale_parents(x, geoframe, region, to)
}

#' @rdname geoscale_navigate
#' @export
geoscale_descendants <- function(x, geoframe, region, to = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  if (!is.null(to)) .check_geoframe(x, to, "to")
  .geoframe_region_cols(nestedscales::scale_descendants(x, geoframe, region, to))
}

#' @rdname geoscale_navigate
#' @export
geoscale_ancestors <- function(x, geoframe, region, to = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  if (!is.null(to)) .check_geoframe(x, to, "to")
  .geoframe_region_cols(nestedscales::scale_ancestors(x, geoframe, region, to))
}

# nestedscales tags related codes as `frame`/`unit`.
#' @noRd
.geoframe_region_cols <- function(d) {
  names(d) <- c("geoframe", "region")
  d
}

#' Subset a Geoscale by region
#'
#' Keeps only the atoms belonging to `region` at `geoframe`, and rebuilds the
#' member vocabularies accordingly. Geometry, when attached, is subset in step.
#'
#' A genuine subset is a SAMPLE and is book-kept as one (the spatial
#' mirror of `timescales::filter_calendar()`'s `year_fraction`):
#' `meta$coverage` records, per weight column, the kept fraction of the
#' ROOT parent's total (so filters compose against the original
#' object), `meta$parent_totals` stores those root totals (making the
#' coverage claim verifiable by the validator), `meta$parent_name`
#' records the parent, and `meta$name` is mangled to
#' `"parent[geoframe:n]"` so a sample never impersonates its parent in
#' the crosswalk registry or in [`join_geoscale()`] column names. A
#' filter that keeps every atom is a true no-op. Read the fraction back
#' with [`geoscale_coverage()`].
#'
#' @param x A [`Geoscale`].
#' @param geoframe Geoframe that `region` belongs to.
#' @param region Character vector of region codes to keep.
#' @param drop_empty_geoframes Drop geoframes left with no codes at all.
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' gs <- geoscale_example()
#' n <- filter_geoscale(gs, "country", "N")
#' n
#' geoscale_coverage(n)
#' @export
filter_geoscale <- function(x, geoframe, region, drop_empty_geoframes = FALSE) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  nestedscales::filter_scale(x, geoframe, region,
                            drop_empty_frames = drop_empty_geoframes)
}

#' Sample bookkeeping: coverage / parent_totals / parent_name / name
#'
#' Coverage is always a fraction of the ROOT parent (an existing
#' `parent_totals` is reused, so filter-of-filter composes), and the
#' mangled name is built from the root parent's name plus `tag`.
#' @noRd
.sample_meta <- function(x, meta, kept, tag) {
  wts <- geoscale_weights(x)
  leaves <- S7::prop(x, "leaftable")
  totals <- meta$parent_totals
  if (is.null(totals)) {
    totals <- vapply(wts, function(w) sum(leaves[[w]], na.rm = TRUE),
                     numeric(1))
    names(totals) <- wts
  }
  cov <- vapply(wts, function(w) sum(kept[[w]], na.rm = TRUE) / totals[[w]],
                numeric(1))
  names(cov) <- wts
  base <- meta$parent_name %||% meta$name
  meta$parent_totals <- totals
  meta$coverage      <- cov
  meta$parent_name   <- base
  meta$name          <- paste0(base, tag)
  meta
}

#' Collapse a Geoscale to a coarser geoframe
#'
#' Returns a new [`Geoscale`] whose atom layer is `geoframe`, dropping every
#' finer geoframe. Weights are summed over the collapsed atoms.
#'
#' The result is renamed `"name@geoframe"` (the
#' `timescales::prune_calendar()` convention) with the parent recorded
#' in `meta$parent_name`; every other meta field (`crs`, `source`,
#' `labels`, inherited `coverage`) is preserved. Atoms with no code at
#' `geoframe` are dropped, and that loss is reflected in
#' `meta$coverage` (see [`geoscale_coverage()`]). With geometry
#' attached, the pruned atoms carry the dissolved (unioned) geometry of
#' their fine atoms unless `keep_geometry = FALSE`.
#'
#' @param x A [`Geoscale`].
#' @param geoframe The geoframe to become the new atom layer.
#' @param keep_geometry Dissolve and keep the attached geometry.
#'   Default: yes, when geometry is attached (needs the sf package;
#'   drops with a message otherwise).
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' prune_geoscale(geoscale_example(), "state")
#' @export
prune_geoscale <- function(x, geoframe,
                           keep_geometry = !is.null(S7::prop(x, "geometry"))) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  lv <- S7::prop(x, "geoframes")
  keep_lv <- lv[seq_len(match(geoframe, lv))]

  leaves0 <- S7::prop(x, "leaftable")
  covered <- !is.na(leaves0[[geoframe]])
  leaves  <- leaves0[covered, , drop = FALSE]
  if (nrow(leaves) == 0L) .stop("no atoms have a code at geoframe `%s`", geoframe)

  wts <- geoscale_weights(x)
  grp <- leaves[, keep_lv, drop = FALSE]
  key <- do.call(paste, c(unname(as.list(grp)), sep = "\r"))
  idx <- !duplicated(key)

  out <- grp[idx, , drop = FALSE]
  for (w in wts) {
    totals <- tapply(leaves[[w]], key, sum, na.rm = TRUE)
    out[[w]] <- as.numeric(totals[key[idx]])
  }
  out$region <- as.character(out[[geoframe]])
  rownames(out) <- NULL

  # meta: preserve EVERYTHING, then adjust identity and coverage
  meta <- S7::prop(x, "meta")
  new_meta <- meta
  if (!all(covered)) {                       # NA atoms dropped = coverage loss
    new_meta <- .sample_meta(x, new_meta, kept = leaves, tag = "")
  }
  new_meta$parent_name <- meta$name
  new_meta$name <- paste0(meta$name, "@", geoframe)

  gs <- geoscale_from_leaftable(
    out, geoframes = keep_lv, key = "region",
    weights = wts, default_weight = meta$default_weight,
    name = new_meta$name, desc = meta$desc
  )
  full_meta <- utils::modifyList(new_meta, S7::prop(gs, "meta")[
    c("weights", "default_weight")])
  S7::prop(gs, "meta") <- full_meta

  if (isTRUE(keep_geometry)) {
    geom <- S7::prop(x, "geometry")
    if (is.null(geom)) {
      # nothing to keep -- the default only requests it when attached
    } else if (!requireNamespace("sf", quietly = TRUE)) {
      message("prune_geoscale(): sf is not installed; geometry dropped")
    } else {
      gk <- geom[covered]
      merged <- lapply(key[idx], function(k) {
        u <- sf::st_union(gk[key == k])
        if (length(u) != 1L) u <- sf::st_combine(u)  # one code, one geometry
        u
      })
      gs <- attach_geometry_geoscale(gs, do.call(c, merged))
    }
  }
  gs
}

#' Sampled coverage of a Geoscale
#'
#' The spatial mirror of a partial calendar's `year_fraction`: the
#' fraction of the ROOT parent's weight totals that this object still
#' carries. [`filter_geoscale()`] (and [`prune_geoscale()`] when it
#' drops uncovered atoms) record it in `meta$coverage`; an object that
#' was never sampled reports `1` for every weight.
#'
#' @param x A [`Geoscale`].
#' @param weight A single weight name for a scalar answer; `NULL`
#'   (default) returns the named vector over all declared weights.
#'
#' @return A named numeric over the declared weights, or a single
#'   unnamed numeric when `weight` is given.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_coverage(gs)                            # all 1 -- not a sample
#' geoscale_coverage(filter_geoscale(gs, "country", "N"))
#' @export
geoscale_coverage <- function(x, weight = NULL) {
  .check_geoscale(x)
  nestedscales::scale_coverage(x, weight)
}

#' Subset a Geoscale with `[`
#'
#' `gs[geoframe, region]` is shorthand for [`filter_geoscale()`].
#'
#' @param x A [`Geoscale`].
#' @param i Geoframe name.
#' @param j Character vector of region codes.
#' @param ... Unused.
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' gs <- geoscale_example()
#' gs["country", "N"]
#'
#' @details
#' S7 ships a `[.S7_object` that errors, so a method must be registered for
#' the class itself. Under S7 0.2 `class()` reports the package-qualified
#' `geoscales::Geoscale` both when sourced and when installed, so that is the
#' registration that actually dispatches; the bare `Geoscale` one is kept as a
#' cheap guard in case an S7 version reports the short name. This mirrors the
#' two-function pattern `print()` uses in geoscale-class.R. Declaring both as
#' real methods with `@export`, rather than via `@rawNamespace`, is what stops
#' roxygen2 reporting them as unexported.
#'
#' @export
#' @method [ Geoscale
`[.Geoscale` <- function(x, i, j, ...) {
  if (missing(i) || missing(j)) {
    .stop("subset a Geoscale as `gs[geoframe, region]`")
  }
  filter_geoscale(x, i, j)
}

# Alias on the fully-qualified S7 class name: that is what `class()` returns
# for an INSTALLED package, so without this `gs[geoframe, region]` falls through
# to `[.S7_object`, which errors.
#' @rdname sub-.Geoscale
#' @export
`[.geoscales::Geoscale` <- `[.Geoscale`

#' Weight shares within a geoframe
#'
#' Normalised weights, either of the whole object or within each parent group.
#'
#' @param x A [`Geoscale`].
#' @param geoframe Geoframe to report shares for.
#' @param weight Weight column. `NULL` uses the default.
#' @param within Optional coarser geoframe to normalise within. `NULL`
#'   normalises over the whole object.
#'
#' @return A `data.frame` with a code column named `geoframe` (matching the
#'   convention of [`recast_geoscale()`]), the weight, and `share`. When `within`
#'   is given, a column of that name carries the parent code.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_share(gs, "state", weight = "km2")
#' geoscale_share(gs, "state", weight = "km2", within = "country")
#' @export
geoscale_share <- function(x, geoframe, weight = NULL, within = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  if (!is.null(within)) .check_geoframe(x, within, "within")
  nestedscales::scale_share(x, geoframe, weight = weight, within = within)
}
