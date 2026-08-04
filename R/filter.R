# =============================================================================
# Filtering, navigation and derived hierarchy tables
# =============================================================================
# Neither `timeslices` nor `timescales` has any `[` or filter method — the
# only trace is a commented-out generic. For regions this is central, so it is
# designed in from the start.
#
# Region codes repeat across levels (46 of 62 in IDEEA; "AN" appears at seven
# levels), so `level` is ALWAYS a required argument. Nothing is inferred from
# a bare code.
#
# The `geo_` prefix is not merely cosmetic: bare `children`/`parents` collide
# with igraph and the XML packages.
#
# All derived tables are computed on demand. Nothing is cached on the object.
# =============================================================================

#' Regions present at a level
#'
#' @param x A [`Geoscale`].
#' @param level A single level name.
#'
#' @return A character vector of region codes, in the object's canonical order.
#'
#' @examples
#' gs <- geoscale_example()
#' geo_regions(gs, "state")
#' @export
geo_regions <- function(x, level) {
  .check_geoscale(x)
  .check_level(x, level)
  S7::prop(x, "members")[[level]]
}

#' Immediate parent-child table between two levels
#'
#' @param x A [`Geoscale`].
#' @param parent,child Level names. Defaults to every adjacent pair in
#'   `x@levels`.
#'
#' @return A `data.frame` with columns `parent_level`, `parent`,
#'   `child_level`, `child`. Atoms unassigned at either level are omitted.
#'
#' @examples
#' gs <- geoscale_example()
#' geo_family(gs, "state", "zone")
#' @export
geo_family <- function(x, parent = NULL, child = NULL) {
  .check_geoscale(x)
  lv <- S7::prop(x, "levels")

  if (is.null(parent) && is.null(child)) {
    if (length(lv) < 2L) return(.empty_family())
    parts <- lapply(seq_len(length(lv) - 1L), function(i) {
      geo_family(x, lv[i], lv[i + 1L])
    })
    out <- do.call(rbind, parts)
    rownames(out) <- NULL
    return(out)
  }
  .check_level(x, parent, "parent")
  .check_level(x, child, "child")

  leaves <- S7::prop(x, "leaves")
  d <- data.frame(
    parent = as.character(leaves[[parent]]),
    child  = as.character(leaves[[child]]),
    stringsAsFactors = FALSE
  )
  d <- unique(d[!is.na(d$parent) & !is.na(d$child), , drop = FALSE])
  out <- data.frame(
    parent_level = parent,
    parent       = d$parent,
    child_level  = child,
    child        = d$child,
    stringsAsFactors = FALSE
  )
  out <- out[order(out$parent, out$child), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' @noRd
.empty_family <- function() {
  data.frame(parent_level = character(), parent = character(),
             child_level = character(), child = character(),
             stringsAsFactors = FALSE)
}

#' Do two levels nest?
#'
#' Tests whether every code at the finer level falls entirely within a single
#' code at the coarser level. Real hierarchies often fail this: IDEEA's
#' `reg32` code `APY` merges Andhra Pradesh with part of Puducherry, so
#' `reg35` does not nest inside `reg32`.
#'
#' Nesting is *not* required by [`Geoscale`] — [`geo_recast()`] routes through
#' the atom layer and works either way. This function is a diagnostic.
#'
#' @param x A [`Geoscale`].
#' @param parent,child Level names.
#'
#' @return `TRUE` or `FALSE`. When `FALSE`, the offending child codes are
#'   attached as the `"offenders"` attribute.
#'
#' @examples
#' gs <- geoscale_example()
#' geo_nests(gs, "country", "state")  # TRUE
#' geo_nests(gs, "state", "zone")     # FALSE - they cross-cut
#' @export
geo_nests <- function(x, parent, child) {
  fam <- geo_family(x, parent, child)
  multi <- unique(fam$child[duplicated(fam$child)])
  ok <- length(multi) == 0L
  if (!ok) attr(ok, "offenders") <- multi
  ok
}

#' Ancestry between all level pairs
#'
#' Every `(coarser, finer)` code pair that shares at least one atom, for all
#' level pairs.
#'
#' Computed **atom-mediated**, directly from `@leaves` — deliberately not as a
#' transitive closure of [`geo_family()`]. `timeslices` can use a closure
#' because time levels genuinely nest; spatial levels cross-cut, and a closure
#' then manufactures false relationships. In the example Geoscale, zone `ZB`
#' straddles both countries, so closing `country -> state -> zone -> atom`
#' would wrongly report country `N` as an ancestor of atom `A5`, which lies in
#' country `S`.
#'
#' For levels that do not nest this relation is *overlap*, not containment —
#' test a given pair with [`geo_nests()`].
#'
#' Level columns are retained because region codes are not unique across
#' levels: in the example, `"N1"` exists at both `state` and `zone`, so a bare
#' `(parent, child)` pair would read as a self-loop.
#'
#' @param x A [`Geoscale`].
#'
#' @return A `data.frame` with columns `parent_level`, `parent`,
#'   `child_level`, `child`.
#'
#' @examples
#' head(geo_ancestry(geoscale_example()))
#' @export
geo_ancestry <- function(x) {
  .check_geoscale(x)
  lv <- S7::prop(x, "levels")
  if (length(lv) < 2L) return(.empty_family())

  parts <- list()
  for (i in seq_len(length(lv) - 1L)) {
    for (j in seq(i + 1L, length(lv))) {
      parts[[length(parts) + 1L]] <- geo_family(x, lv[i], lv[j])
    }
  }
  out <- do.call(rbind, parts)
  out <- out[order(out$parent_level, out$parent,
                   out$child_level, out$child), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Navigate a region hierarchy
#'
#' `geo_children()` and `geo_parents()` step one level; `geo_descendants()`
#' and `geo_ancestors()` follow the transitive closure.
#'
#' `level` is required in every case — region codes are not unique across
#' levels, so a bare code is ambiguous.
#'
#' @param x A [`Geoscale`].
#' @param level Level that `region` belongs to.
#' @param region Character vector of region codes at `level`.
#' @param to Target level. For `geo_children()`/`geo_parents()` this defaults
#'   to the adjacent level; for the transitive versions, `NULL` means all
#'   levels below/above.
#'
#' @return `geo_children()` and `geo_parents()` return a character vector of
#'   codes at a single level. `geo_descendants()` and `geo_ancestors()` span
#'   several levels and so return a `data.frame` with columns `level` and
#'   `region` — a bare character vector would be ambiguous, since the same
#'   code can occur at more than one level.
#'
#' @examples
#' gs <- geoscale_example()
#' geo_children(gs, "country", "N")
#' geo_parents(gs, "state", "N1", to = "country")
#' geo_descendants(gs, "country", "N")
#' geo_ancestors(gs, "atom", "A5")
#' @name geo_navigate
NULL

#' @rdname geo_navigate
#' @export
geo_children <- function(x, level, region, to = NULL) {
  .check_geoscale(x)
  .check_level(x, level)
  lv <- S7::prop(x, "levels")
  i <- match(level, lv)
  if (is.null(to)) {
    if (i == length(lv)) {
      .stop("`%s` is the finest level; it has no children", level)
    }
    to <- lv[i + 1L]
  }
  .check_level(x, to, "to")
  .related(x, level, region, to)
}

#' @rdname geo_navigate
#' @export
geo_parents <- function(x, level, region, to = NULL) {
  .check_geoscale(x)
  .check_level(x, level)
  lv <- S7::prop(x, "levels")
  i <- match(level, lv)
  if (is.null(to)) {
    if (i == 1L) {
      .stop("`%s` is the coarsest level; it has no parents", level)
    }
    to <- lv[i - 1L]
  }
  .check_level(x, to, "to")
  .related(x, level, region, to)
}

#' @rdname geo_navigate
#' @export
geo_descendants <- function(x, level, region, to = NULL) {
  .check_geoscale(x)
  .check_level(x, level)
  lv <- S7::prop(x, "levels")
  i <- match(level, lv)
  targets <- if (is.null(to)) {
    utils::tail(lv, length(lv) - i)
  } else {
    .check_level(x, to, "to")
    to
  }
  .related_df(x, level, region, targets)
}

#' @rdname geo_navigate
#' @export
geo_ancestors <- function(x, level, region, to = NULL) {
  .check_geoscale(x)
  .check_level(x, level)
  lv <- S7::prop(x, "levels")
  i <- match(level, lv)
  targets <- if (is.null(to)) {
    utils::head(lv, i - 1L)
  } else {
    .check_level(x, to, "to")
    to
  }
  .related_df(x, level, region, targets)
}

#' Related codes across several levels, as a level-tagged table
#' @noRd
.related_df <- function(x, level, region, targets) {
  if (length(targets) == 0L) {
    return(data.frame(level = character(), region = character(),
                      stringsAsFactors = FALSE))
  }
  parts <- lapply(targets, function(t) {
    codes <- .related(x, level, region, t)
    data.frame(level = rep(t, length(codes)), region = codes,
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

#' Codes at `to` that share at least one atom with `region` at `level`
#' @noRd
.related <- function(x, level, region, to) {
  leaves <- S7::prop(x, "leaves")
  unknown <- setdiff(region, S7::prop(x, "members")[[level]])
  if (length(unknown) > 0L) {
    .stop("code(s) not found at level `%s`: %s", level, .preview(unknown))
  }
  hit <- leaves[[level]] %in% region
  out <- unique(stats::na.omit(as.character(leaves[[to]][hit])))
  ord <- S7::prop(x, "members")[[to]]
  out[order(match(out, ord))]
}

#' Subset a Geoscale by region
#'
#' Keeps only the atoms belonging to `region` at `level`, and rebuilds the
#' member vocabularies accordingly. Geometry, when attached, is subset in step.
#'
#' @param x A [`Geoscale`].
#' @param level Level that `region` belongs to.
#' @param region Character vector of region codes to keep.
#' @param drop_empty_levels Drop levels left with no codes at all.
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' gs <- geoscale_example()
#' geo_filter(gs, "country", "N")
#' @export
geo_filter <- function(x, level, region, drop_empty_levels = FALSE) {
  .check_geoscale(x)
  .check_level(x, level)
  leaves <- S7::prop(x, "leaves")
  lv     <- S7::prop(x, "levels")

  unknown <- setdiff(region, S7::prop(x, "members")[[level]])
  if (length(unknown) > 0L) {
    .stop("code(s) not found at level `%s`: %s", level, .preview(unknown))
  }

  keep <- which(leaves[[level]] %in% region)
  if (length(keep) == 0L) {
    .stop("no atoms remain after filtering")
  }

  .rebuild(x, keep, lv, drop_empty_levels)
}

#' Collapse a Geoscale to a coarser level
#'
#' Returns a new [`Geoscale`] whose atom layer is `level`, dropping every
#' finer level. Weights are summed over the collapsed atoms.
#'
#' @param x A [`Geoscale`].
#' @param level The level to become the new atom layer.
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' geo_prune(geoscale_example(), "state")
#' @export
geo_prune <- function(x, level) {
  .check_geoscale(x)
  .check_level(x, level)
  lv <- S7::prop(x, "levels")
  keep_lv <- lv[seq_len(match(level, lv))]

  leaves <- S7::prop(x, "leaves")
  leaves <- leaves[!is.na(leaves[[level]]), , drop = FALSE]
  if (nrow(leaves) == 0L) .stop("no atoms have a code at level `%s`", level)

  wts <- geo_weights(x)
  grp <- leaves[, keep_lv, drop = FALSE]
  key <- do.call(paste, c(unname(as.list(grp)), sep = "\r"))
  idx <- !duplicated(key)

  out <- grp[idx, , drop = FALSE]
  for (w in wts) {
    totals <- tapply(leaves[[w]], key, sum, na.rm = TRUE)
    out[[w]] <- as.numeric(totals[key[idx]])
  }
  out$region <- as.character(out[[level]])
  rownames(out) <- NULL

  meta <- S7::prop(x, "meta")
  geoscale_from_leaves(
    out, levels = keep_lv, key = "region",
    weights = wts, default_weight = meta$default_weight,
    name = meta$name, desc = meta$desc
  )
}

#' Rebuild a Geoscale from a row subset
#' @noRd
.rebuild <- function(x, keep, lv, drop_empty_levels = FALSE) {
  leaves <- S7::prop(x, "leaves")[keep, , drop = FALSE]
  rownames(leaves) <- NULL

  members <- lapply(lv, function(l) {
    old <- S7::prop(x, "members")[[l]]
    seen <- unique(stats::na.omit(as.character(leaves[[l]])))
    old[old %in% seen]
  })
  names(members) <- lv

  if (drop_empty_levels) {
    nonempty <- lv[vapply(members[lv], length, integer(1)) > 0L]
    if (length(nonempty) == 0L) .stop("every level is empty after filtering")
    lv <- nonempty
    members <- members[lv]
    leaves <- leaves[, c(lv, setdiff(names(leaves), lv)), drop = FALSE]
  } else {
    empty <- lv[vapply(members[lv], length, integer(1)) == 0L]
    if (length(empty) > 0L) {
      .stop(paste0("level(s) %s have no codes left; pass ",
                   "drop_empty_levels = TRUE"), .preview(empty))
    }
  }

  geom <- S7::prop(x, "geometry")
  if (!is.null(geom)) geom <- geom[keep]

  Geoscale(leaves = leaves, levels = lv, members = members,
           geometry = geom, meta = S7::prop(x, "meta"))
}

#' Subset a Geoscale with `[`
#'
#' `gs[level, region]` is shorthand for [`geo_filter()`].
#'
#' @param x A [`Geoscale`].
#' @param i Level name.
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
    .stop("subset a Geoscale as `gs[level, region]`")
  }
  geo_filter(x, i, j)
}

# Alias on the fully-qualified S7 class name: that is what `class()` returns
# for an INSTALLED package, so without this `gs[level, region]` falls through
# to `[.S7_object`, which errors.
#' @rdname sub-.Geoscale
#' @export
`[.geoscales::Geoscale` <- `[.Geoscale`

#' @noRd
`[.geoscales::Geoscale` <- `[.Geoscale`

#' Weight shares within a level
#'
#' Normalised weights, either of the whole object or within each parent group.
#'
#' @param x A [`Geoscale`].
#' @param level Level to report shares for.
#' @param weight Weight column. `NULL` uses the default.
#' @param within Optional coarser level to normalise within. `NULL`
#'   normalises over the whole object.
#'
#' @return A `data.frame` with a code column named `level` (matching the
#'   convention of [`geo_recast()`]), the weight, and `share`. When `within`
#'   is given, a column of that name carries the parent code.
#'
#' @examples
#' gs <- geoscale_example()
#' geo_share(gs, "state", weight = "km2")
#' geo_share(gs, "state", weight = "km2", within = "country")
#' @export
geo_share <- function(x, level, weight = NULL, within = NULL) {
  .check_geoscale(x)
  .check_level(x, level)
  weight <- .resolve_weight(x, weight)
  leaves <- S7::prop(x, "leaves")

  d <- data.frame(region = as.character(leaves[[level]]),
                  w = as.numeric(leaves[[weight]]),
                  stringsAsFactors = FALSE)
  if (is.null(within)) {
    d$grp <- ""
  } else {
    .check_level(x, within, "within")
    d$grp <- as.character(leaves[[within]])
  }
  d <- d[!is.na(d$region), , drop = FALSE]
  d$w[is.na(d$w)] <- 0

  agg <- stats::aggregate(w ~ region + grp, data = d, FUN = sum)
  agg$share <- agg$w / stats::ave(agg$w, agg$grp, FUN = sum)

  ord <- S7::prop(x, "members")[[level]]
  agg <- agg[order(match(agg$region, ord)), , drop = FALSE]

  out <- data.frame(code = agg$region, stringsAsFactors = FALSE)
  names(out) <- level
  if (!is.null(within)) out[[within]] <- agg$grp
  out[[weight]] <- agg$w
  out$share <- agg$share
  rownames(out) <- NULL
  out
}
