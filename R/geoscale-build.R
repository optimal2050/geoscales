# =============================================================================
# Construction — Layer 2 (from crosswalks)
# =============================================================================
# Time hierarchies are rectangular, so `timescales::calendar_build()` can use
# `expand.grid()`. Spatial hierarchies are ragged — countries have unequal
# numbers of states — so the layer-2 builder takes explicit parent-child
# crosswalks instead, and assembles them into the wide leaves table that
# `geoscale_from_leaves()` expects.
# =============================================================================

#' Build a Geoscale from parent-child crosswalks
#'
#' Assembles a wide leaves table from a set of two-column crosswalks. Each
#' crosswalk is a `data.frame` whose column names are two level names; the
#' builder joins them together, starting from the finest level, until every
#' level in `levels` is present.
#'
#' Crosswalks need not form a strict chain: a level that cross-cuts the others
#' (a grid zone crossing state lines, say) is expressed simply by giving its
#' crosswalk against the finest level.
#'
#' @param ... One or more two-column `data.frame`s, each named after the pair
#'   of levels it connects.
#' @param levels Ordered character vector of level names, coarsest first. The
#'   last entry is the atom level.
#' @param weights Optional `data.frame` keyed by the atom level, carrying one
#'   or more numeric weight columns.
#' @param name,desc Short name and description.
#' @param ... Additional arguments passed to [`geoscale_from_leaves()`].
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' geoscale_build(
#'   data.frame(country = c("N", "N", "S"),
#'              state   = c("N1", "N2", "S1")),
#'   data.frame(state = c("N1", "N1", "N2", "S1"),
#'              atom  = c("A1", "A2", "A3", "A4")),
#'   levels  = c("country", "state", "atom"),
#'   weights = data.frame(atom = c("A1", "A2", "A3", "A4"),
#'                        km2  = c(10, 20, 30, 40))
#' )
#' @export
geoscale_build <- function(..., levels, weights = NULL,
                           name = "", desc = "") {
  xwalks <- list(...)
  if (length(xwalks) == 0L) {
    .stop("supply at least one crosswalk data.frame")
  }
  if (!all(vapply(xwalks, is.data.frame, logical(1)))) {
    .stop("every `...` argument must be a data.frame")
  }
  if (!is.character(levels) || length(levels) < 1L) {
    .stop("`levels` must be a non-empty character vector")
  }

  xwalks <- lapply(xwalks, function(d) {
    d <- as.data.frame(d, stringsAsFactors = FALSE)
    for (nm in names(d)) d[[nm]] <- .blank_to_na(d[[nm]])
    unique(d)
  })

  unknown <- setdiff(unlist(lapply(xwalks, names)), levels)
  if (length(unknown) > 0L) {
    .stop("crosswalk column(s) not listed in `levels`: %s", .preview(unknown))
  }

  atom <- levels[length(levels)]
  has_atom <- vapply(xwalks, function(d) atom %in% names(d), logical(1))
  if (!any(has_atom)) {
    .stop("no crosswalk mentions the atom level `%s`", atom)
  }

  # Seed with the crosswalks that mention the atom level, then absorb the rest
  # by shared columns until every level is present.
  join_shared <- function(a, b) {
    merge(a, b, by = intersect(names(a), names(b)), all = TRUE, sort = FALSE)
  }
  leaves <- Reduce(join_shared, xwalks[has_atom])
  pending <- xwalks[!has_atom]

  while (length(pending) > 0L) {
    shared <- vapply(pending,
                     function(d) length(intersect(names(d), names(leaves))) > 0,
                     logical(1))
    if (!any(shared)) {
      stuck <- unique(unlist(lapply(pending, names)))
      .stop(paste0("cannot connect crosswalk(s) covering %s to the atom ",
                   "level `%s`; add a crosswalk sharing a level with them"),
            .preview(setdiff(stuck, names(leaves))), atom)
    }
    i <- which(shared)[1L]
    leaves <- merge(leaves, pending[[i]],
                    by = intersect(names(pending[[i]]), names(leaves)),
                    all.x = TRUE, sort = FALSE)
    pending <- pending[-i]
  }

  missing_lv <- setdiff(levels, names(leaves))
  if (length(missing_lv) > 0L) {
    .stop("no crosswalk supplies level(s): %s", .preview(missing_lv))
  }

  if (!is.null(weights)) {
    weights <- as.data.frame(weights, stringsAsFactors = FALSE)
    if (!atom %in% names(weights)) {
      .stop("`weights` must have a `%s` column (the atom level)", atom)
    }
    weights[[atom]] <- .blank_to_na(weights[[atom]])
    leaves <- merge(leaves, weights, by = atom, all.x = TRUE, sort = FALSE)
  }

  dup <- unique(leaves[[atom]][duplicated(leaves[[atom]])])
  if (length(dup) > 0L) {
    .stop(paste0("crosswalks produce %d duplicated atom(s) (%s); a level ",
                 "assigns more than one code to the same atom"),
          length(dup), .preview(dup))
  }

  leaves <- leaves[, c(levels, setdiff(names(leaves), levels)), drop = FALSE]
  geoscale_from_leaves(leaves, levels = levels, name = name, desc = desc)
}
