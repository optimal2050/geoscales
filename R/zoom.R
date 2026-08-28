# =========================================================================== #
# zoom_geoscale — a telescoping cut through a nested hierarchy
#
# `filter_geoscale()` samples (keep some atoms, coverage < 1) and
# `prune_geoscale()` coarsens uniformly (one geoframe becomes the atom layer).
# Neither expresses the third thing modellers actually want: FULL detail in a
# study area and progressively coarser elsewhere, with the whole territory still
# covered.
#
# That cut is a complete partition of the atoms, so it is a GEOFRAME like any
# other. Nothing downstream needs to know it was built this way -- a quantity
# aggregated to the cut goes through the ordinary machinery.
#
# THE NESTING REQUIREMENT IS REAL AND NARROW. Spatial geoframes generally
# cross-cut (see `geoscale_ancestry()`), so nesting is never assumed here. But
# the cut is carved OUT of a chain of geoframes, and the levels it was carved
# from cannot survive beside it: "rest of NUTS1" spans several NUTS2, so
# {cut, nuts2} does not nest. Keeping both would produce an object that
# validates and aggregates wrongly. So the intermediate levels are dropped, and
# what remains is VERIFIED with `geoscale_nests()` rather than asserted.
#
# ATOMS WITH NO CODE at the coarsest level keep `NA` in the cut, matching
# `prune_geoscale()`: they have no place in the coarse partition, the loss shows
# up in `geoscale_coverage()`, and it is not silently invented.
# =========================================================================== #

#' Telescoping zoom: fine detail in a focus area, coarse elsewhere
#'
#' Builds a new geoframe that keeps `focus` atoms at full resolution and
#' collapses everything else into progressively coarser rings drawn from
#' `levels`. The result is a partition of the atoms, carried as a geoframe.
#'
#' @details
#' With focus atoms and `levels = c("nuts0", "nuts1", "nuts2")` (coarsest
#' first), each remaining atom joins the **finest** ring that also contains a
#' focus atom, so the cut telescopes outward:
#'
#' * the focus atoms themselves, individually;
#' * the rest of each `nuts2` holding a focus atom;
#' * the rest of each `nuts1` holding one of those;
#' * the rest of each `nuts0` holding one of those;
#' * every other atom, grouped at `levels[1]`.
#'
#' The intermediate geoframes are **dropped**. A ring like "rest of nuts1" spans
#' several `nuts2`, so the cut cannot nest with the levels it was carved from;
#' only `levels[1]` and the atom layer are kept beside it. That is checked, not
#' assumed — see [geoscale_nests()].
#'
#' @param x A [`Geoscale`].
#' @param focus Character vector of **atom** codes to keep at full resolution.
#' @param levels Ordered geoframes to build rings from, coarsest first.
#'   Defaults to every geoframe of `x` except the atom layer.
#' @param name Name of the new geoframe. Default `"zoom"`.
#' @param label_rest `sprintf` format for a ring's code, with `%s` the parent
#'   code. Default `"%s_rest"`.
#'
#' @return A [`Geoscale`] with geoframes `levels[1]`, `name` and the atom layer;
#'   weights and geometry carried through unchanged.
#'
#' @seealso [filter_geoscale()] to sample, [prune_geoscale()] to coarsen
#'   uniformly, [geoscale_nests()] for the guarantee this relies on.
#'
#' @examples
#' gs <- geoscale_example()
#' z <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"))
#' geoscale_geoframes(z)
#' geoscale_regions(z, "zoom")
#' @export
zoom_geoscale <- function(x, focus, levels = NULL, name = "zoom",
                          label_rest = "%s_rest") {
  if (!inherits(x, "geoscales::Geoscale")) .stop("`x` must be a Geoscale")

  frames <- geoscale_geoframes(x)
  atom_frame <- frames[length(frames)]
  if (is.null(levels)) levels <- setdiff(frames, atom_frame)
  levels <- as.character(levels)

  if (!length(levels)) .stop("`levels` must name at least one geoframe")
  unknown <- setdiff(levels, frames)
  if (length(unknown)) {
    .stop("unknown geoframe(s) in `levels`: %s; available: %s",
          .preview(unknown), paste(frames, collapse = ", "))
  }
  if (identical(levels, atom_frame) || atom_frame %in% levels) {
    .stop("`levels` must not include the atom geoframe `%s`", atom_frame)
  }
  if (name %in% frames) .stop("`name` = `%s` is already a geoframe of `x`", name)

  lt <- x@leaftable
  atoms <- as.character(lt[["region"]])
  focus <- unique(as.character(focus))
  if (!length(focus)) {
    .stop("`focus` is empty; a zoom with no focus area is `prune_geoscale()`")
  }
  gone <- setdiff(focus, atoms)
  if (length(gone)) {
    .stop(paste0("`focus` names atoms (geoframe `%s`), not coarser regions; ",
                 "not found: %s"), atom_frame, .preview(gone))
  }

  is_focus <- atoms %in% focus

  # Rings, finest first. An atom joins the finest ring whose parent code it
  # shares with a focus atom; taking the FIRST match while walking
  # finest -> coarsest is what makes the cut telescope.
  cut <- rep(NA_character_, length(atoms))
  cut[is_focus] <- atoms[is_focus]

  for (lvl in rev(levels)) {
    codes <- as.character(lt[[lvl]])
    touched <- unique(codes[is_focus & !is.na(codes)])
    hit <- is.na(cut) & !is.na(codes) & codes %in% touched
    cut[hit] <- sprintf(label_rest, codes[hit])
  }

  # Everything the rings never reached groups at the coarsest level. Atoms with
  # no code there keep NA, exactly as `prune_geoscale()` would leave them.
  coarsest <- as.character(lt[[levels[1]]])
  fill <- is.na(cut)
  cut[fill] <- coarsest[fill]

  ordered <- c(levels[1], name, atom_frame)
  carried <- setdiff(names(lt), frames)          # region + weights + extras
  new_lt <- lt[, carried, drop = FALSE]
  new_lt[[levels[1]]] <- lt[[levels[1]]]
  new_lt[[name]] <- cut
  new_lt[[atom_frame]] <- lt[[atom_frame]]

  out <- geoscale_from_leaftable(
    leaftable = new_lt,
    geoframes = ordered,
    key = "region",
    weights = x@meta$weights,
    default_weight = x@meta$default_weight,
    geometry = x@geometry,
    name = if (nzchar(x@meta$name %||% "")) paste0(x@meta$name, "@", name) else name,
    desc = sprintf("telescoping zoom on %d atom(s) of %s",
                   length(focus), x@meta$name %||% "a geoscale"),
    crs = x@meta$crs,
    source = x@meta$source,
    zoom = list(focus = focus, levels = levels, parent_name = x@meta$name)
  )

  # The guarantee, verified rather than asserted: every ring inside exactly one
  # code of the coarsest level, every atom inside exactly one ring. Without it a
  # quantity aggregated to the cut would double-count.
  for (pair in list(c(levels[1], name), c(name, atom_frame))) {
    ok <- geoscale_nests(out, pair[1], pair[2])
    if (!isTRUE(ok)) {
      .stop(paste0("the zoom does not nest: `%s` -> `%s` has %d code(s) with ",
                   "more than one parent (e.g. %s). Please report this."),
            pair[2], pair[1], length(attr(ok, "offenders")),
            .preview(attr(ok, "offenders")))
    }
  }
  out
}
