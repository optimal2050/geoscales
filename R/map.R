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
#   * geoscale_map(gs, source, target)     -- `source`/`target` are geoframe names of `gs`;
#   * geoscale_map_between(source, target) -- two GeoScale objects, matched on
#     shared atom `region` keys (reg32 <-> NUTS style conversions).
#
# The derivation and the registry of exact / hand-audited crosswalks live in
# nestedscales; these functions keep the geoscales argument names and errors.
# =============================================================================

#' Crosswalk between two geoframes of a GeoScale
#'
#' Materialises the `from -> atoms -> to` route as a table: one row per pair
#' of overlapping regions with
#'
#' * `n_from` -- atoms in the `source` region (its full set, before any
#'   target coverage is considered),
#' * `n_overlap` -- atoms the pair shares,
#' * `w` -- the weight of the overlap (summed atom weights, chosen weight
#'   column), the quantity `"weighted_mean"` aggregation uses,
#' * `w_from` -- the full weight of the `source` region; `w / w_from` is the
#'   split share `"sum"` disaggregation uses.
#'
#' The two label columns are named by the geoframes; rows with an `NA` target
#' label are atoms `target` does not cover. A crosswalk registered with
#' [`register_geoscale_map()`] is returned as-is instead of being derived.
#'
#' @param gs The [`GeoScale`] the geoframes belong to.
#' @param source,target Geoframe names of `gs`.
#' @param from,to Deprecated names of `source` and `target`.
#' @param weight Weight column for `w`. `NULL` uses the default weight; when
#'   the object declares no weights at all, every atom gets weight 1
#'   (an equal split).
#'
#' @return A `data.frame` with columns `<source>`, `<target>` (`NA` = uncovered by
#'   `target`), `n_from`, `n_overlap`, `w`, `w_from`.
#'
#' @seealso [`geoscale_map_between()`] for the map between two GeoScales.
#' @examples
#' gs <- geoscale_example()
#' geoscale_map(gs, "state", "zone")
#' geoscale_map(gs, "country", "state", weight = "km2")
#' @export
geoscale_map <- function(gs, source, target, weight = NULL,
                         from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("geoscale_map", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("geoscale_map", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  if (S7::S7_inherits(from, GeoScale) || S7::S7_inherits(to, GeoScale)) {
    .stop(paste0("`source` and `target` are geoframe names of `gs`; for the map ",
                 "between two GeoScales use `geoscale_map_between()`"))
  }
  .check_geoscale(gs, "gs")
  .check_geoframe(gs, from, "source")
  .check_geoframe(gs, to, "target")
  nestedscales::scale_map(gs, from, to, weight = weight)
}

#' Crosswalk between two GeoScales through their shared atoms
#'
#' The counterpart of [`geoscale_map()`] for two GeoScales: atoms are matched
#' on their `region` keys, so a region of `source` overlaps a region of `target`
#' where they contain the same atoms. Same columns as [`geoscale_map()`], with
#' the two label columns named after the GeoScales. Atoms of `source` absent
#' from `target` get an `NA` target (with a warning). A crosswalk registered with
#' [`register_geoscale_map_between()`] is returned as-is instead of being
#' derived.
#'
#' @param source,target Two named [`GeoScale`] objects whose atom keys overlap.
#' @param from,to Deprecated names of `source` and `target`.
#' @param weight Weight column of `source` for `w`; `NULL` uses its default
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
geoscale_map_between <- function(source, target, weight = NULL,
                                 from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("geoscale_map_between", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("geoscale_map_between", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  .check_geoscale(from, "source")
  .check_geoscale(to, "target")
  nestedscales::scale_map_between(from, to, weight = weight)
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
#' geoframes of one GeoScale; the map is scoped to that object, so
#' `"state" -> "zone"` maps of two different objects do not collide.
#' `register_geoscale_map_between()` and `get_geoscale_map_between()` handle a
#' pair of GeoScales.
#'
#' @param gs The [`GeoScale`] the geoframes belong to, or its name.
#' @param source,target For the within-object functions, geoframe names of `gs`.
#' @param from,to Deprecated names of `source` and `target`.
#'   For the `_between` functions, two [`GeoScale`] objects or their names.
#' @param map A `data.frame` shaped like a [`geoscale_map()`] result: the
#'   two label columns named after the geoframes (or GeoScales), plus
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
register_geoscale_map <- function(gs, source, target, map,
                                  from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("register_geoscale_map", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("register_geoscale_map", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  if (!is.character(gs)) .check_geoscale(gs, "gs")
  nestedscales::register_scale_map(gs, from, to, map)
}

#' @rdname register_geoscale_map
#' @export
register_geoscale_map_between <- function(source, target, map,
                                          from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("register_geoscale_map_between", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("register_geoscale_map_between", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  for (a in c("source", "target")) {
    z <- get(a)
    if (!is.character(z)) .check_geoscale(z, a)
  }
  nestedscales::register_scale_map_between(from, to, map)
}

#' @rdname register_geoscale_map
#' @export
get_geoscale_map <- function(gs, source, target,
                             from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("get_geoscale_map", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("get_geoscale_map", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  if (!is.character(gs)) .check_geoscale(gs, "gs")
  nestedscales::get_scale_map(gs, from, to)
}

#' @rdname register_geoscale_map
#' @export
get_geoscale_map_between <- function(source, target,
                                     from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("get_geoscale_map_between", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("get_geoscale_map_between", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  for (a in c("source", "target")) {
    z <- get(a)
    if (!is.character(z)) .check_geoscale(z, a)
  }
  nestedscales::get_scale_map_between(from, to)
}

#' @rdname register_geoscale_map
#' @export
list_geoscale_maps <- function() {
  nestedscales::list_scale_maps()
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
  nestedscales::clear_scale_maps()
}
