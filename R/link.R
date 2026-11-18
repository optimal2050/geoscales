# =============================================================================
# The data link -- which GeoScale, and which geoframe, a column is on
# =============================================================================
# The link itself lives in `nestedscales` (0.3.0 on): `bind_scale()` turns a
# code column into a `scale_unit` vector that remembers the scale and the
# frame. This file is the spatial front end, and the bridge that lets the
# verbs here read the link when the installed `nestedscales` has it and behave
# as before when it does not.
# =============================================================================

#' A function of `nestedscales`, or NULL when the installed version lacks it
#' @noRd
.ns_fun <- function(name) {
  get0(name, envir = asNamespace("nestedscales"), inherits = FALSE)
}

#' @noRd
.geo_link_enter <- function(x, gs, key = NULL, source = NULL, infer = TRUE) {
  f <- .ns_fun("scale_link_enter")
  if (is.null(f)) {
    return(list(data = x, key = key, source = source, tags = NULL))
  }
  f(x, gs, key = key, source = source, infer = infer)
}

#' @noRd
.geo_link_exit <- function(out, link, new = list()) {
  f <- .ns_fun("scale_link_exit")
  if (is.null(f) || is.null(link$tags)) return(out)
  f(out, link, new)
}

#' One result column bound to a geoframe of a GeoScale
#' @noRd
.geo_bound <- function(gs, geoframe, column = geoframe) {
  stats::setNames(list(list(scale = gs, frame = geoframe)), column)
}

#' Bind a table to a GeoScale
#'
#' Records, on the region-code columns themselves, which [`GeoScale`] and
#' which geoframe their codes are on. Column names alone cannot say that:
#' two geographies may both have a `zone`, and may even share codes.
#' A bound column still behaves as a character vector and keeps the link
#' through row subsetting, `mutate()`, grouping, joins and row binding.
#' [`recast_geoscale()`], [`recast_to_geoatoms()`],
#' [`recast_from_geoatoms()`] and [`join_geoscale()`] then take the source
#' geoframe from the link, stop when the data is bound to a different
#' GeoScale, and bind their result. Data that was never bound is handled as
#' before.
#'
#' Every code is checked when binding; a code that is not a region of the
#' geoframe is an error. `geoscale_link()` reports what a table is bound to,
#' and `geoscale_id()` gives the identity the link stores: the name of the
#' GeoScale and a hash of its structure (geoframes and memberships, not
#' weights, labels or geometry). `nestedscales::unbind_scale()` returns the
#' columns to plain character.
#'
#' The link needs `nestedscales` 0.3.0 or later.
#'
#' @param data A `data.frame`, tibble or `data.table`.
#' @param gs The [`GeoScale`] the codes belong to.
#' @param cols Which columns to bind. `NULL` (default) binds every column
#'   named after a geoframe of `gs`. Otherwise a character vector of geoframe
#'   names, named by column where the column is called something else:
#'   `c(origin = "zone")`.
#'
#' @return `bind_geoscale()` returns `data`; `geoscale_link()` a
#'   `data.frame` with one row per bound column (`column`, `scale`, `frame`,
#'   `id`); `geoscale_id()` a single string.
#'
#' @examplesIf exists("bind_scale", asNamespace("nestedscales"))
#' gs <- geoscale_example()
#' geoscale_id(gs)
#' d <- data.frame(state = c("N1", "N2", "S1"), cap = c(1, 2, 3))
#' b <- bind_geoscale(d, gs)
#' geoscale_link(b)
#' out <- recast_geoscale(b, gs, target = "country", rule = "sum")
#' geoscale_link(out)
#' @export
bind_geoscale <- function(data, gs, cols = NULL) {
  .check_geoscale(gs, "gs")
  .need_link("bind_geoscale()")(data, gs, cols = cols)
}

#' @rdname bind_geoscale
#' @export
geoscale_link <- function(data) {
  f <- .ns_fun("scale_link")
  if (is.null(f)) {
    return(data.frame(column = character(), scale = character(),
                      frame = character(), id = character(),
                      stringsAsFactors = FALSE))
  }
  f(data)
}

#' @rdname bind_geoscale
#' @export
geoscale_id <- function(gs) {
  .check_geoscale(gs, "gs")
  f <- .ns_fun("scale_id")
  if (is.null(f)) .stop("geoscale_id() needs nestedscales >= 0.3.0")
  f(gs)
}

#' @noRd
.need_link <- function(what) {
  f <- .ns_fun("bind_scale")
  if (is.null(f)) .stop("%s needs nestedscales >= 0.3.0", what)
  f
}
