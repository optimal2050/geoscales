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
#' @param x A [`Geoscale`].
#' @param geoframe A single geoframe name.
#'
#' @return A character vector of region codes, in the object's canonical order.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_regions(gs, "state")
#' @export
geoscale_regions <- function(x, geoframe) {
  .check_geoscale(x)
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
  lv <- S7::prop(x, "geoframes")

  if (is.null(parent) && is.null(child)) {
    if (length(lv) < 2L) return(.empty_family())
    parts <- lapply(seq_len(length(lv) - 1L), function(i) {
      geoscale_family(x, lv[i], lv[i + 1L])
    })
    out <- do.call(rbind, parts)
    rownames(out) <- NULL
    return(out)
  }
  .check_geoframe(x, parent, "parent")
  .check_geoframe(x, child, "child")

  leaves <- S7::prop(x, "leaftable")
  d <- data.frame(
    parent = as.character(leaves[[parent]]),
    child  = as.character(leaves[[child]]),
    stringsAsFactors = FALSE
  )
  d <- unique(d[!is.na(d$parent) & !is.na(d$child), , drop = FALSE])
  out <- data.frame(
    parent_geoframe = parent,
    parent       = d$parent,
    child_geoframe  = child,
    child        = d$child,
    stringsAsFactors = FALSE
  )
  out <- out[order(out$parent, out$child), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' @noRd
.empty_family <- function() {
  data.frame(parent_geoframe = character(), parent = character(),
             child_geoframe = character(), child = character(),
             stringsAsFactors = FALSE)
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
  fam <- geoscale_family(x, parent, child)
  multi <- unique(fam$child[duplicated(fam$child)])
  ok <- length(multi) == 0L
  if (!ok) attr(ok, "offenders") <- multi
  ok
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
  lv <- S7::prop(x, "geoframes")
  if (length(lv) < 2L) return(.empty_family())

  parts <- list()
  for (i in seq_len(length(lv) - 1L)) {
    for (j in seq(i + 1L, length(lv))) {
      parts[[length(parts) + 1L]] <- geoscale_family(x, lv[i], lv[j])
    }
  }
  out <- do.call(rbind, parts)
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
  lv <- S7::prop(x, "geoframes")
  i <- match(geoframe, lv)
  if (is.null(to)) {
    if (i == length(lv)) {
      .stop("`%s` is the finest geoframe; it has no children", geoframe)
    }
    to <- lv[i + 1L]
  }
  .check_geoframe(x, to, "to")
  .related(x, geoframe, region, to)
}

#' @rdname geoscale_navigate
#' @export
geoscale_parents <- function(x, geoframe, region, to = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  lv <- S7::prop(x, "geoframes")
  i <- match(geoframe, lv)
  if (is.null(to)) {
    if (i == 1L) {
      .stop("`%s` is the coarsest geoframe; it has no parents", geoframe)
    }
    to <- lv[i - 1L]
  }
  .check_geoframe(x, to, "to")
  .related(x, geoframe, region, to)
}

#' @rdname geoscale_navigate
#' @export
geoscale_descendants <- function(x, geoframe, region, to = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  lv <- S7::prop(x, "geoframes")
  i <- match(geoframe, lv)
  targets <- if (is.null(to)) {
    utils::tail(lv, length(lv) - i)
  } else {
    .check_geoframe(x, to, "to")
    to
  }
  .related_df(x, geoframe, region, targets)
}

#' @rdname geoscale_navigate
#' @export
geoscale_ancestors <- function(x, geoframe, region, to = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  lv <- S7::prop(x, "geoframes")
  i <- match(geoframe, lv)
  targets <- if (is.null(to)) {
    utils::head(lv, i - 1L)
  } else {
    .check_geoframe(x, to, "to")
    to
  }
  .related_df(x, geoframe, region, targets)
}

#' Related codes across several geoframes, as a geoframe-tagged table
#' @noRd
.related_df <- function(x, geoframe, region, targets) {
  if (length(targets) == 0L) {
    return(data.frame(geoframe = character(), region = character(),
                      stringsAsFactors = FALSE))
  }
  parts <- lapply(targets, function(t) {
    codes <- .related(x, geoframe, region, t)
    data.frame(geoframe = rep(t, length(codes)), region = codes,
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

#' Codes at `to` that share at least one atom with `region` at `geoframe`
#' @noRd
.related <- function(x, geoframe, region, to) {
  leaves <- S7::prop(x, "leaftable")
  unknown <- setdiff(region, S7::prop(x, "members")[[geoframe]])
  if (length(unknown) > 0L) {
    .stop("code(s) not found at geoframe `%s`: %s", geoframe, .preview(unknown))
  }
  hit <- leaves[[geoframe]] %in% region
  out <- unique(stats::na.omit(as.character(leaves[[to]][hit])))
  ord <- S7::prop(x, "members")[[to]]
  out[order(match(out, ord))]
}

#' Subset a Geoscale by region
#'
#' Keeps only the atoms belonging to `region` at `geoframe`, and rebuilds the
#' member vocabularies accordingly. Geometry, when attached, is subset in step.
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
#' filter_geoscale(gs, "country", "N")
#' @export
filter_geoscale <- function(x, geoframe, region, drop_empty_geoframes = FALSE) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  leaves <- S7::prop(x, "leaftable")
  lv     <- S7::prop(x, "geoframes")

  unknown <- setdiff(region, S7::prop(x, "members")[[geoframe]])
  if (length(unknown) > 0L) {
    .stop("code(s) not found at geoframe `%s`: %s", geoframe, .preview(unknown))
  }

  keep <- which(leaves[[geoframe]] %in% region)
  if (length(keep) == 0L) {
    .stop("no atoms remain after filtering")
  }

  .rebuild(x, keep, lv, drop_empty_geoframes)
}

#' Collapse a Geoscale to a coarser geoframe
#'
#' Returns a new [`Geoscale`] whose atom layer is `geoframe`, dropping every
#' finer geoframe. Weights are summed over the collapsed atoms.
#'
#' @param x A [`Geoscale`].
#' @param geoframe The geoframe to become the new atom layer.
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' prune_geoscale(geoscale_example(), "state")
#' @export
prune_geoscale <- function(x, geoframe) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  lv <- S7::prop(x, "geoframes")
  keep_lv <- lv[seq_len(match(geoframe, lv))]

  leaves <- S7::prop(x, "leaftable")
  leaves <- leaves[!is.na(leaves[[geoframe]]), , drop = FALSE]
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

  meta <- S7::prop(x, "meta")
  geoscale_from_leaftable(
    out, geoframes = keep_lv, key = "region",
    weights = wts, default_weight = meta$default_weight,
    name = meta$name, desc = meta$desc
  )
}

#' Rebuild a Geoscale from a row subset
#' @noRd
.rebuild <- function(x, keep, lv, drop_empty_geoframes = FALSE) {
  leaves <- S7::prop(x, "leaftable")[keep, , drop = FALSE]
  rownames(leaves) <- NULL

  members <- lapply(lv, function(l) {
    old <- S7::prop(x, "members")[[l]]
    seen <- unique(stats::na.omit(as.character(leaves[[l]])))
    old[old %in% seen]
  })
  names(members) <- lv

  if (drop_empty_geoframes) {
    nonempty <- lv[vapply(members[lv], length, integer(1)) > 0L]
    if (length(nonempty) == 0L) .stop("every geoframe is empty after filtering")
    lv <- nonempty
    members <- members[lv]
    leaves <- leaves[, c(lv, setdiff(names(leaves), lv)), drop = FALSE]
  } else {
    empty <- lv[vapply(members[lv], length, integer(1)) == 0L]
    if (length(empty) > 0L) {
      .stop(paste0("geoframe(s) %s have no codes left; pass ",
                   "drop_empty_geoframes = TRUE"), .preview(empty))
    }
  }

  geom <- S7::prop(x, "geometry")
  if (!is.null(geom)) geom <- geom[keep]

  Geoscale(leaftable = leaves, geoframes = lv, members = members,
           geometry = geom, meta = S7::prop(x, "meta"))
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
  weight <- .resolve_weight(x, weight)
  leaves <- S7::prop(x, "leaftable")

  d <- data.frame(region = as.character(leaves[[geoframe]]),
                  w = as.numeric(leaves[[weight]]),
                  stringsAsFactors = FALSE)
  if (is.null(within)) {
    d$grp <- ""
  } else {
    .check_geoframe(x, within, "within")
    d$grp <- as.character(leaves[[within]])
  }
  d <- d[!is.na(d$region), , drop = FALSE]
  d$w[is.na(d$w)] <- 0

  agg <- stats::aggregate(w ~ region + grp, data = d, FUN = sum)
  agg$share <- agg$w / stats::ave(agg$w, agg$grp, FUN = sum)

  ord <- S7::prop(x, "members")[[geoframe]]
  agg <- agg[order(match(agg$region, ord)), , drop = FALSE]

  out <- data.frame(code = agg$region, stringsAsFactors = FALSE)
  names(out) <- geoframe
  if (!is.null(within)) out[[within]] <- agg$grp
  out[[weight]] <- agg$w
  out$share <- agg$share
  rownames(out) <- NULL
  out
}
