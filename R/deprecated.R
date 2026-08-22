# =============================================================================
# Deprecated names
# =============================================================================
# Renamed 2026-08 under the harmonized *scales convention shared with
# timescales: verb_class for data operations and object transforms
# (recast_geoscale, filter_geoscale), class-prefixed nouns for
# properties/queries (geoscale_geoframes, geoscale_children), and
# register_/get_/list_/clear_ registries carrying a `geo` domain word.
# These aliases warn and forward; they will be removed before 1.0.

#' Deprecated geoscales functions
#'
#' These functions were renamed under the harmonized naming convention
#' shared with the timescales package. The old names warn and forward to
#' their replacements; they will be removed before the 1.0 release.
#'
#' Data operations and object transforms (`verb_geoscale`):
#' `geo_recast()` -> [recast_geoscale()] (or the `recast()` generic),
#' `geo_filter()` -> [filter_geoscale()],
#' `geo_prune()` -> [prune_geoscale()],
#' `geo_attach_geometry()` -> [attach_geometry_geoscale()],
#' `geo_area()` -> [add_area_geoscale()].
#'
#' Properties and queries (`geoscale_*`):
#' `geo_levels()` -> [geoscale_geoframes()], `geo_rank()` ->
#' [geoscale_rank()], `geo_weights()` -> [geoscale_weights()],
#' `geo_regions()` -> [geoscale_regions()], `geo_family()` ->
#' [geoscale_family()], `geo_nests()` -> [geoscale_nests()],
#' `geo_ancestry()` -> [geoscale_ancestry()], `geo_children()` ->
#' [geoscale_children()], `geo_parents()` -> [geoscale_parents()],
#' `geo_descendants()` -> [geoscale_descendants()], `geo_ancestors()` ->
#' [geoscale_ancestors()], `geo_share()` -> [geoscale_share()],
#' `geo_geometry()` -> [geoscale_geometry()], `geo_layout()` ->
#' [geoscale_layout()], `geo_autoplot()` -> [geoscale_autoplot()],
#' `geo_plot()` -> [geoscale_plot()].
#'
#' Registries:
#' `geo_register_rule()` -> [register_geo_rule()], `geo_get_rule()` ->
#' [get_geo_rule()], `geo_list_rules()` -> [list_geo_rules()],
#' `geo_clear_rules()` -> [clear_geo_rules()],
#' `geo_register_provider()` -> [register_geo_provider()],
#' `geo_provider()` -> [get_geo_provider()], `geo_list_providers()` ->
#' [list_geo_providers()].
#'
#' @param ... Arguments forwarded to the replacement function.
#' @return See the replacement function.
#' @name geoscales-deprecated
#' @keywords internal
NULL

.dep <- function(old, new) {
  force(old); force(new)
  function(...) {
    .Deprecated(new, old = old)
    do.call(new, list(...), envir = asNamespace("geoscales"))
  }
}

#' @rdname geoscales-deprecated
#' @export
geo_recast <- .dep("geo_recast", "recast_geoscale")

#' @rdname geoscales-deprecated
#' @export
geo_filter <- .dep("geo_filter", "filter_geoscale")

#' @rdname geoscales-deprecated
#' @export
geo_prune <- .dep("geo_prune", "prune_geoscale")

#' @rdname geoscales-deprecated
#' @export
geo_attach_geometry <- function(x, geom, by = NULL, level = NULL, ...) {
  .Deprecated("attach_geometry_geoscale", old = "geo_attach_geometry")
  attach_geometry_geoscale(x, geom, by = by, geoframe = level, ...)
}

#' @rdname geoscales-deprecated
#' @export
geo_area <- .dep("geo_area", "add_area_geoscale")

#' @rdname geoscales-deprecated
#' @export
geo_levels <- .dep("geo_levels", "geoscale_geoframes")

#' @rdname geoscales-deprecated
#' @export
geo_rank <- .dep("geo_rank", "geoscale_rank")

#' @rdname geoscales-deprecated
#' @export
geo_weights <- .dep("geo_weights", "geoscale_weights")

#' @rdname geoscales-deprecated
#' @export
geo_regions <- .dep("geo_regions", "geoscale_regions")

#' @rdname geoscales-deprecated
#' @export
geo_family <- .dep("geo_family", "geoscale_family")

#' @rdname geoscales-deprecated
#' @export
geo_nests <- .dep("geo_nests", "geoscale_nests")

#' @rdname geoscales-deprecated
#' @export
geo_ancestry <- .dep("geo_ancestry", "geoscale_ancestry")

#' @rdname geoscales-deprecated
#' @export
geo_children <- .dep("geo_children", "geoscale_children")

#' @rdname geoscales-deprecated
#' @export
geo_parents <- .dep("geo_parents", "geoscale_parents")

#' @rdname geoscales-deprecated
#' @export
geo_descendants <- .dep("geo_descendants", "geoscale_descendants")

#' @rdname geoscales-deprecated
#' @export
geo_ancestors <- .dep("geo_ancestors", "geoscale_ancestors")

#' @rdname geoscales-deprecated
#' @export
geo_share <- .dep("geo_share", "geoscale_share")

#' @rdname geoscales-deprecated
#' @export
geo_geometry <- .dep("geo_geometry", "geoscale_geometry")

#' @rdname geoscales-deprecated
#' @export
geo_layout <- .dep("geo_layout", "geoscale_layout")

#' @rdname geoscales-deprecated
#' @export
geo_autoplot <- .dep("geo_autoplot", "geoscale_autoplot")

#' @rdname geoscales-deprecated
#' @export
geo_plot <- .dep("geo_plot", "geoscale_plot")

#' @rdname geoscales-deprecated
#' @export
geo_register_rule <- .dep("geo_register_rule", "register_geo_rule")

#' @rdname geoscales-deprecated
#' @export
geo_get_rule <- .dep("geo_get_rule", "get_geo_rule")

#' @rdname geoscales-deprecated
#' @export
geo_list_rules <- .dep("geo_list_rules", "list_geo_rules")

#' @rdname geoscales-deprecated
#' @export
geo_clear_rules <- .dep("geo_clear_rules", "clear_geo_rules")

#' @rdname geoscales-deprecated
#' @export
geo_register_provider <- .dep("geo_register_provider",
                              "register_geo_provider")

#' @rdname geoscales-deprecated
#' @export
geo_provider <- .dep("geo_provider", "get_geo_provider")

#' @rdname geoscales-deprecated
#' @export
geo_list_providers <- .dep("geo_list_providers", "list_geo_providers")

# 2026-08 naming lattice: the word "levels" retires from both siblings.
# Hierarchy names are `geoframes`, the leaf enumeration is `leaftable`.

#' @rdname geoscales-deprecated
#' @export
geoscale_levels <- .dep("geoscale_levels", "geoscale_geoframes")

#' @rdname geoscales-deprecated
#' @export
is_valid_level <- .dep("is_valid_level", "is_valid_geoframe")

#' @rdname geoscales-deprecated
#' @export
geoscale_from_leaves <- function(leaves, levels, ...) {
  .Deprecated("geoscale_from_leaftable")
  geoscale_from_leaftable(leaftable = leaves, geoframes = levels, ...)
}
