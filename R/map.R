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
# No memoisation cache: the leaf tables are in memory and the aggregation is
# cheap. A registry (register_geo_map) holds exact / hand-audited crosswalks.
# =============================================================================

#' @noRd
.GEO_MAP_REGISTRY <- new.env(parent = emptyenv())

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
#' [`register_geo_map()`] is returned as-is instead of being derived.
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
  cross <- S7::S7_inherits(from, Geoscale) || S7::S7_inherits(to, Geoscale)
  if (cross) {
    .check_geoscale(from, "from")
    .check_geoscale(to, "to")
    return(.geoscale_map_cross(from, to, weight))
  }
  if (is.null(gs)) {
    .stop(paste0("`gs` is required when `from`/`to` are geoframe names; ",
                 "pass Geoscale objects for a cross-object map"))
  }
  .check_geoscale(gs, "gs")
  .check_geoframe(gs, from, "from")
  .check_geoframe(gs, to, "to")
  if (identical(from, to)) {
    .stop(paste0("`from` and `to` are the same geoframe (\"%s\"); the ",
                 "map's label columns are named by the geoframes"), from)
  }

  reg <- .get_geo_map(from, to, .geoscale_name(gs, require = FALSE))
  if (!is.null(reg)) {
    return(reg)
  }

  leaves <- S7::prop(gs, "leaftable")
  wcol <- .map_weight(gs, weight)
  d <- data.frame(
    from = as.character(leaves[[from]]),
    to   = as.character(leaves[[to]]),
    w    = if (is.null(wcol)) 1 else as.numeric(leaves[[wcol]]),
    stringsAsFactors = FALSE
  )
  .finish_geo_map(d, from, to)
}

#' Cross-object map: atoms matched on shared `region` keys
#' @noRd
.geoscale_map_cross <- function(from, to, weight) {
  from_nm <- .geoscale_name(from, arg = "from")
  to_nm   <- .geoscale_name(to, arg = "to")
  if (identical(from_nm, to_nm)) {
    .stop(paste0("`from` and `to` have the same name (\"%s\"); the map's ",
                 "label columns are named by the Geoscales -- rename one"),
          from_nm)
  }
  reg <- .get_geo_map(from_nm, to_nm)
  if (!is.null(reg)) {
    return(reg)
  }

  lf <- S7::prop(from, "leaftable")
  lt <- S7::prop(to, "leaftable")
  shared <- intersect(lf$region, lt$region)
  if (length(shared) == 0L) {
    .stop(paste0("the atom layers of \"%s\" and \"%s\" share no `region` ",
                 "keys; register an explicit crosswalk with ",
                 "register_geo_map()"), from_nm, to_nm)
  }
  n_miss <- sum(!lf$region %in% shared)
  if (n_miss > 0L) {
    .warn(paste0("%d atom(s) of \"%s\" have no counterpart in \"%s\"; ",
                 "their share is uncovered (NA target)"),
          n_miss, from_nm, to_nm)
  }
  wcol <- .map_weight(from, weight)
  d <- data.frame(
    from = lf$region,
    to   = ifelse(lf$region %in% shared, lf$region, NA_character_),
    w    = if (is.null(wcol)) 1 else as.numeric(lf[[wcol]]),
    stringsAsFactors = FALSE
  )
  .finish_geo_map(d, from_nm, to_nm)
}

#' Chosen weight column, or NULL for the unweighted (equal) fallback
#' @noRd
.map_weight <- function(gs, weight) {
  if (length(geoscale_weights(gs)) == 0L && is.null(weight)) {
    return(NULL)
  }
  .resolve_weight(gs, weight)
}

#' Aggregate a (from, to, w) atom frame into the map schema
#' @noRd
.finish_geo_map <- function(d, from_lab, to_lab) {
  d <- d[!is.na(d$from), , drop = FALSE]
  if (nrow(d) == 0L) {
    .stop("no atoms carry a code at `from`; the map would be empty")
  }
  d$w[is.na(d$w)] <- 0
  map <- d |>
    dplyr::group_by(.data$from, .data$to) |>
    dplyr::summarise(n_overlap = dplyr::n(), w = sum(.data$w),
                     .groups = "drop_last") |>
    dplyr::mutate(n_from = sum(.data$n_overlap),
                  w_from = sum(.data$w)) |>
    dplyr::ungroup() |>
    as.data.frame()
  map <- map[order(map$from, map$to, na.last = TRUE),
             c("from", "to", "n_from", "n_overlap", "w", "w_from"),
             drop = FALSE]
  rownames(map) <- NULL
  names(map)[names(map) == "from"] <- from_lab
  names(map)[names(map) == "to"]   <- to_lab
  map
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
#' @return Invisibly, the registry key. `get_geo_map()` returns the
#'   registered map (or `NULL`); `list_geo_maps()` a `data.frame` of
#'   registry keys.
#'
#' @examples
#' gs <- geoscale_example()
#' fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
#'                    n_overlap = 1L, w = 1, w_from = 1)
#' register_geo_map("state", "zone", fake, gs = gs)
#' list_geo_maps()
#' get_geo_map("state", "zone", gs = gs)
#' register_geo_map("state", "zone", NULL, gs = gs)  # remove
#' clear_geo_maps()
#' @export
register_geo_map <- function(from, to, map, gs = NULL) {
  nm_of <- function(z, arg) {
    if (is.character(z) && length(z) == 1L && nzchar(z)) return(z)
    .check_geoscale(z, arg)
    .geoscale_name(z, arg = arg)
  }
  from_nm <- nm_of(from, "from")
  to_nm   <- nm_of(to, "to")
  scope   <- if (is.null(gs)) "" else nm_of(gs, "gs")
  key <- paste0(scope, if (nzchar(scope)) ":", from_nm, "->", to_nm)
  if (is.null(map)) {
    if (exists(key, envir = .GEO_MAP_REGISTRY, inherits = FALSE)) {
      rm(list = key, envir = .GEO_MAP_REGISTRY)
    }
    return(invisible(key))
  }
  if (!is.data.frame(map)) {
    .stop("`map` must be a data.frame (see `geoscale_map()`) or NULL")
  }
  need <- c(from_nm, to_nm, "n_from", "n_overlap", "w", "w_from")
  miss <- setdiff(need, names(map))
  if (length(miss) > 0L) {
    .stop("`map` is missing column(s): %s", .preview(miss))
  }
  assign(key, as.data.frame(map), envir = .GEO_MAP_REGISTRY)
  invisible(key)
}

#' @noRd
.get_geo_map <- function(from_nm, to_nm, scope = "") {
  for (key in unique(c(
    paste0(scope, if (nzchar(scope)) ":", from_nm, "->", to_nm),
    paste0(from_nm, "->", to_nm)
  ))) {
    if (exists(key, envir = .GEO_MAP_REGISTRY, inherits = FALSE)) {
      return(get(key, envir = .GEO_MAP_REGISTRY, inherits = FALSE))
    }
  }
  NULL
}

#' @rdname register_geo_map
#' @export
get_geo_map <- function(from, to, gs = NULL) {
  nm_of <- function(z, arg) {
    if (is.character(z) && length(z) == 1L && nzchar(z)) return(z)
    .check_geoscale(z, arg)
    .geoscale_name(z, arg = arg)
  }
  .get_geo_map(nm_of(from, "from"), nm_of(to, "to"),
               scope = if (is.null(gs)) "" else nm_of(gs, "gs"))
}

#' @rdname register_geo_map
#' @export
list_geo_maps <- function() {
  keys <- sort(ls(envir = .GEO_MAP_REGISTRY, all.names = TRUE))
  data.frame(key = keys, stringsAsFactors = FALSE)
}

#' Clear the registered spatial crosswalks
#'
#' Mainly useful in tests.
#'
#' @examples
#' clear_geo_maps()
#' @return Invisibly `NULL`.
#' @export
clear_geo_maps <- function() {
  rm(list = ls(envir = .GEO_MAP_REGISTRY, all.names = TRUE),
     envir = .GEO_MAP_REGISTRY)
  invisible(NULL)
}
