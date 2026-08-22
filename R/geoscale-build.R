# =============================================================================
# Construction — Layer 2 (from crosswalks)
# =============================================================================
# Time hierarchies are rectangular, so `timescales::calendar_build()` can use
# `expand.grid()`. Spatial hierarchies are ragged — countries have unequal
# numbers of states — so the layer-2 builder takes explicit parent-child
# crosswalks instead, and assembles them into the wide leaftable table that
# `geoscale_from_leaftable()` expects.
# =============================================================================

#' Build a Geoscale from parent-child crosswalks
#'
#' Assembles a wide leaftable table from a set of two-column crosswalks. Each
#' crosswalk is a `data.frame` whose column names are two geoframe names; the
#' builder joins them together, starting from the finest geoframe, until every
#' geoframe in `geoframes` is present.
#'
#' Crosswalks need not form a strict chain: a geoframe that cross-cuts the others
#' (a grid zone crossing state lines, say) is expressed simply by giving its
#' crosswalk against the finest geoframe.
#'
#' @param ... One or more two-column `data.frame`s, each named after the pair
#'   of geoframes it connects.
#' @param geoframes Ordered character vector of geoframe names, coarsest first. The
#'   last entry is the atom geoframe.
#' @param weights Optional `data.frame` keyed by the atom geoframe, carrying one
#'   or more numeric weight columns.
#' @param name,desc Short name and description.
#' @param ... Additional arguments passed to [`geoscale_from_leaftable()`].
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' geoscale_build(
#'   data.frame(country = c("N", "N", "S"),
#'              state   = c("N1", "N2", "S1")),
#'   data.frame(state = c("N1", "N1", "N2", "S1"),
#'              atom  = c("A1", "A2", "A3", "A4")),
#'   geoframes  = c("country", "state", "atom"),
#'   weights = data.frame(atom = c("A1", "A2", "A3", "A4"),
#'                        km2  = c(10, 20, 30, 40))
#' )
#' @export
geoscale_build <- function(..., geoframes, weights = NULL,
                           name = "", desc = "") {
  xwalks <- list(...)
  if (length(xwalks) == 0L) {
    .stop("supply at least one crosswalk data.frame")
  }
  if (!all(vapply(xwalks, is.data.frame, logical(1)))) {
    .stop("every `...` argument must be a data.frame")
  }
  if (!is.character(geoframes) || length(geoframes) < 1L) {
    .stop("`geoframes` must be a non-empty character vector")
  }
  # Conversion and attach need a named object (the crosswalk's label
  # columns and join_geoscale()'s attached columns are named after it), so
  # default to a name derived from the hierarchy, as calendar_build() does.
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
      !nzchar(name)) {
    name <- paste(geoframes, collapse = "_")
  }

  xwalks <- lapply(xwalks, function(d) {
    d <- as.data.frame(d, stringsAsFactors = FALSE)
    for (nm in names(d)) d[[nm]] <- .blank_to_na(d[[nm]])
    unique(d)
  })

  unknown <- setdiff(unlist(lapply(xwalks, names)), geoframes)
  if (length(unknown) > 0L) {
    .stop("crosswalk column(s) not listed in `geoframes`: %s", .preview(unknown))
  }

  atom <- geoframes[length(geoframes)]
  has_atom <- vapply(xwalks, function(d) atom %in% names(d), logical(1))
  if (!any(has_atom)) {
    .stop("no crosswalk mentions the atom geoframe `%s`", atom)
  }

  # Seed with the crosswalks that mention the atom geoframe, then absorb the rest
  # by shared columns until every geoframe is present.
  join_shared <- function(a, b) {
    merge(a, b, by = intersect(names(a), names(b)), all = TRUE, sort = FALSE)
  }
  leaftable <- Reduce(join_shared, xwalks[has_atom])
  pending <- xwalks[!has_atom]

  while (length(pending) > 0L) {
    shared <- vapply(pending,
                     function(d) length(intersect(names(d), names(leaftable))) > 0,
                     logical(1))
    if (!any(shared)) {
      stuck <- unique(unlist(lapply(pending, names)))
      .stop(paste0("cannot connect crosswalk(s) covering %s to the atom ",
                   "geoframe `%s`; add a crosswalk sharing a geoframe with them"),
            .preview(setdiff(stuck, names(leaftable))), atom)
    }
    i <- which(shared)[1L]
    leaftable <- merge(leaftable, pending[[i]],
                    by = intersect(names(pending[[i]]), names(leaftable)),
                    all.x = TRUE, sort = FALSE)
    pending <- pending[-i]
  }

  missing_lv <- setdiff(geoframes, names(leaftable))
  if (length(missing_lv) > 0L) {
    .stop("no crosswalk supplies geoframe(s): %s", .preview(missing_lv))
  }

  if (!is.null(weights)) {
    weights <- as.data.frame(weights, stringsAsFactors = FALSE)
    if (!atom %in% names(weights)) {
      .stop("`weights` must have a `%s` column (the atom geoframe)", atom)
    }
    weights[[atom]] <- .blank_to_na(weights[[atom]])
    leaftable <- merge(leaftable, weights, by = atom, all.x = TRUE, sort = FALSE)
  }

  dup <- unique(leaftable[[atom]][duplicated(leaftable[[atom]])])
  if (length(dup) > 0L) {
    .stop(paste0("crosswalks produce %d duplicated atom(s) (%s); a geoframe ",
                 "assigns more than one code to the same atom"),
          length(dup), .preview(dup))
  }

  leaftable <- leaftable[, c(geoframes, setdiff(names(leaftable), geoframes)), drop = FALSE]
  geoscale_from_leaftable(leaftable, geoframes = geoframes, name = name, desc = desc)
}
