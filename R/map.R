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
# Two functions, one per shape:
#   * geoscale_map(gs, from, to)      -- `from`/`to` are geoframe names of `gs`;
#   * geoscale_map_between(from, to)  -- two Geoscale objects, matched on
#     shared atom `region` keys (reg32 <-> NUTS style conversions).
#
# The derivation and the registry of exact / hand-audited crosswalks live in
# discretescales; these functions keep the geoscales argument names and errors.
# =============================================================================

#' Crosswalk between two geoframes of a Geoscale
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
#' The two label columns are named by the geoframes; rows with an `NA` target
#' label are atoms `to` does not cover. A crosswalk registered with
#' [`register_geoscale_map()`] is returned as-is instead of being derived.
#'
#' @param gs The [`Geoscale`] the geoframes belong to.
#' @param from,to Geoframe names of `gs`.
#' @param weight Weight column for `w`. `NULL` uses the default weight; when
#'   the object declares no weights at all, every atom gets weight 1
#'   (an equal split).
#'
#' @return A `data.frame` with columns `<from>`, `<to>` (`NA` = uncovered by
#'   `to`), `n_from`, `n_overlap`, `w`, `w_from`.
#'
#' @seealso [`geoscale_map_between()`] for the map between two Geoscales.
#' @examples
#' gs <- geoscale_example()
#' geoscale_map(gs, "state", "zone")
#' geoscale_map(gs, "country", "state", weight = "km2")
#' @export
geoscale_map <- function(gs, from, to, weight = NULL) {
  if (S7::S7_inherits(from, Geoscale) || S7::S7_inherits(to, Geoscale)) {
    .stop(paste0("`from` and `to` are geoframe names of `gs`; for the map ",
                 "between two Geoscales use `geoscale_map_between()`"))
  }
  .check_geoscale(gs, "gs")
  .check_geoframe(gs, from, "from")
  .check_geoframe(gs, to, "to")
  discretescales::scale_map(gs, from, to, weight = weight)
}

#' Crosswalk between two Geoscales through their shared atoms
#'
#' The counterpart of [`geoscale_map()`] for two Geoscales: atoms are matched
#' on their `region` keys, so a region of `from` overlaps a region of `to`
#' where they contain the same atoms. Same columns as [`geoscale_map()`], with
#' the two label columns named after the Geoscales. Atoms of `from` absent
#' from `to` get an `NA` target (with a warning). A crosswalk registered with
#' [`register_geoscale_map_between()`] is returned as-is instead of being
#' derived.
#'
#' @param from,to Two named [`Geoscale`] objects whose atom keys overlap.
#' @param weight Weight column of `from` for `w`; `NULL` uses its default
#'   weight, or weight 1 per atom when it declares none.
#'
#' @return A `data.frame` with columns `<from name>`, `<to name>`, `n_from`,
#'   `n_overlap`, `w`, `w_from`.
#'
#' @examples
#' gs <- geoscale_example()
#' # another hierarchy over the same atoms (ROW has no counterpart: NA target)
#' bands <- geoscale_from_leaftable(
#'   data.frame(
#'     band = rep(c("X", "Y"), 3),
#'     atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
#'     km2 = c(100, 200, 300, 400, 500, 600)
#'   ),
#'   geoframes = c("band", "atom"), name = "bands"
#' )
#' geoscale_map_between(gs, bands)
#' @export
geoscale_map_between <- function(from, to, weight = NULL) {
  .check_geoscale(from, "from")
  .check_geoscale(to, "to")
  discretescales::scale_map_between(from, to, weight = weight)
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
#' [`geoscale_map()`] or [`geoscale_map_between()`] (and thereby
#' [`recast_geoscale()`]) for one pair of resolutions -- for cases where the
#' exact correspondence is known (hand-audited crosswalks, official
#' concordance tables).
#'
#' `register_geoscale_map()` and `get_geoscale_map()` handle a pair of
#' geoframes of one Geoscale; the map is scoped to that object, so
#' `"state" -> "zone"` maps of two different objects do not collide.
#' `register_geoscale_map_between()` and `get_geoscale_map_between()` handle a
#' pair of Geoscales.
#'
#' @param gs The [`Geoscale`] the geoframes belong to, or its name.
#' @param from,to For the within-object functions, geoframe names of `gs`.
#'   For the `_between` functions, two [`Geoscale`] objects or their names.
#' @param map A `data.frame` shaped like a [`geoscale_map()`] result: the
#'   two label columns named after the geoframes (or Geoscales), plus
#'   `n_from`, `n_overlap`, `w` and `w_from`. `NULL` removes a previously
#'   registered map.
#'
#' @return Invisibly, the registry key. The `get_` functions return the
#'   registered map (or `NULL`); `list_geoscale_maps()` a `data.frame` of
#'   registry keys.
#'
#' @examples
#' gs <- geoscale_example()
#' fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
#'                    n_overlap = 1L, w = 1, w_from = 1)
#' register_geoscale_map(gs, "state", "zone", fake)
#' list_geoscale_maps()
#' get_geoscale_map(gs, "state", "zone")
#' register_geoscale_map(gs, "state", "zone", NULL)  # remove
#' clear_geoscale_maps()
#' @export
register_geoscale_map <- function(gs, from, to, map) {
  if (!is.character(gs)) .check_geoscale(gs, "gs")
  discretescales::register_scale_map(gs, from, to, map)
}

#' @rdname register_geoscale_map
#' @export
register_geoscale_map_between <- function(from, to, map) {
  for (a in c("from", "to")) {
    z <- get(a)
    if (!is.character(z)) .check_geoscale(z, a)
  }
  discretescales::register_scale_map_between(from, to, map)
}

#' @rdname register_geoscale_map
#' @export
get_geoscale_map <- function(gs, from, to) {
  if (!is.character(gs)) .check_geoscale(gs, "gs")
  discretescales::get_scale_map(gs, from, to)
}

#' @rdname register_geoscale_map
#' @export
get_geoscale_map_between <- function(from, to) {
  for (a in c("from", "to")) {
    z <- get(a)
    if (!is.character(z)) .check_geoscale(z, a)
  }
  discretescales::get_scale_map_between(from, to)
}

#' @rdname register_geoscale_map
#' @export
list_geoscale_maps <- function() {
  discretescales::list_scale_maps()
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
  discretescales::clear_scale_maps()
}
