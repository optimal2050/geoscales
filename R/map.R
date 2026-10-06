# =============================================================================
# geoscale_map() -- the crosswalk through the atom layer
# =============================================================================
# The spatial mirror of timescales::calendar_map(). The atom layer is already
# materialised in `@leaftable` (there is no expand_calendar() step), so the
# crosswalk is a plain aggregation of the leaf table: one row per pair of
# overlapping regions, carrying the atom counts and weights every recast rule
# needs. `recast_geoscale()` is a join against this table plus one grouped
# summarise, which is what lets the converters run unchanged over
# data.frame / data.table / arrow backends.
#
# Two shapes:
#   * within ONE Geoscale  -- `from`/`to` are geoframe names of `gs`;
#   * across TWO Geoscales -- `from`/`to` are Geoscale objects, matched on
#     shared atom `region` keys (reg32 <-> NUTS style conversions).
#
# The derivation and the registry of exact / hand-audited crosswalks live in
# multiscales; these functions keep the geoscales argument names and errors.
# =============================================================================

#' Crosswalk between two spatial resolutions through the atom layer
#'
#' Materialises the `from -> atoms -> to` route as a table: one row per pair
#' of overlapping regions with
#'
#' * `n_from` -- atoms in the `from` region (its full set, before any
#'   target coverage is considered),
#' * `n_overlap` -- atoms the pair shares,
#' * `w` -- the weight of the overlap (summed atom weights, chosen weight
#'   column), the quantity `"weighted_mean"` aggregation uses,
#' * `w_from` -- the full weight of the `from` region; `w / w_from` is the
#'   split share `"sum"` disaggregation uses.
#'
#' The two label columns are named by the geoframes (within one Geoscale) or
#' by the Geoscale names (across two); rows with an `NA` target label are
#' atoms `to` does not cover. A crosswalk registered with
#' [`register_geoscale_map()`] is returned as-is instead of being derived.
#'
#' @param from,to Either two geoframe names of `gs` (within-object map), or
#'   two named [`Geoscale`] objects (cross-object map on shared atom
#'   `region` keys).
#' @param gs The [`Geoscale`] the geoframe names belong to; required for the
#'   within-object shape, ignored otherwise.
#' @param weight Weight column for `w`. `NULL` uses the default weight; when
#'   the object declares no weights at all, every atom gets weight 1
#'   (an equal split).
#'
#' @return A `data.frame` with columns `<from>`, `<to>` (`NA` = uncovered by
#'   `to`), `n_from`, `n_overlap`, `w`, `w_from`.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_map("state", "zone", gs = gs)
#' geoscale_map("country", "state", gs = gs, weight = "km2")
#' @export
geoscale_map <- function(from, to, gs = NULL, weight = NULL) {
  if (S7::S7_inherits(from, Geoscale) || S7::S7_inherits(to, Geoscale)) {
    .check_geoscale(from, "from")
    .check_geoscale(to, "to")
    return(multiscales::scale_map(from, to, weight = weight))
  }
  if (is.null(gs)) {
    .stop(paste0("`gs` is required when `from`/`to` are geoframe names; ",
                 "pass Geoscale objects for a cross-object map"))
  }
  .check_geoscale(gs, "gs")
  .check_geoframe(gs, from, "from")
  .check_geoframe(gs, to, "to")
  multiscales::scale_map(from, to, x = gs, weight = weight)
}

#' Chosen weight column, or NULL for the unweighted (equal) fallback
#' @noRd
.map_weight <- function(gs, weight) {
  if (length(geoscale_weights(gs)) == 0L && is.null(weight)) {
    return(NULL)
  }
  .resolve_weight(gs, weight)
}

#' Register / look up a direct spatial crosswalk
#'
#' A registered map short-circuits the atom-layer derivation in
#' [`geoscale_map()`] (and thereby [`recast_geoscale()`]) for one pair of
#' resolutions -- for cases where the exact correspondence is known
#' (hand-audited crosswalks, official concordance tables).
#'
#' @param from,to The pair the map applies to: geoframe names (with `gs`
#'   naming the object), Geoscale names, or [`Geoscale`] objects (their
#'   names are used).
#' @param map A `data.frame` shaped like a [`geoscale_map()`] result: the
#'   two label columns named after `from` and `to`, plus `n_from`,
#'   `n_overlap`, `w` and `w_from`. `NULL` removes a previously registered
#'   map.
#' @param gs Optional [`Geoscale`] (or its name) scoping a within-object
#'   map, so `"state" -> "zone"` maps of two different objects do not
#'   collide. Cross-object maps need no scope.
#'
#' @return Invisibly, the registry key. `get_geoscale_map()` returns the
#'   registered map (or `NULL`); `list_geoscale_maps()` a `data.frame` of
#'   registry keys.
#'
#' @examples
#' gs <- geoscale_example()
#' fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
#'                    n_overlap = 1L, w = 1, w_from = 1)
#' register_geoscale_map("state", "zone", fake, gs = gs)
#' list_geoscale_maps()
#' get_geoscale_map("state", "zone", gs = gs)
#' register_geoscale_map("state", "zone", NULL, gs = gs)  # remove
#' clear_geoscale_maps()
#' @export
register_geoscale_map <- function(from, to, map, gs = NULL) {
  for (a in c("from", "to", "gs")) {
    z <- get(a)
    if (!is.null(z) && !is.character(z)) .check_geoscale(z, a)
  }
  multiscales::register_scale_map(from, to, map, x = gs)
}

#' @rdname register_geoscale_map
#' @export
get_geoscale_map <- function(from, to, gs = NULL) {
  for (a in c("from", "to", "gs")) {
    z <- get(a)
    if (!is.null(z) && !is.character(z)) .check_geoscale(z, a)
  }
  multiscales::get_scale_map(from, to, x = gs)
}

#' @rdname register_geoscale_map
#' @export
list_geoscale_maps <- function() {
  multiscales::list_scale_maps()
}

#' Clear the registered spatial crosswalks
#'
#' Mainly useful in tests.
#'
#' @examples
#' clear_geoscale_maps()
#' @return Invisibly `NULL`.
#' @export
clear_geoscale_maps <- function() {
  multiscales::clear_scale_maps()
}
