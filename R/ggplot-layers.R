# =============================================================================
# ggplot2 extension layers
# =============================================================================
# The composable layer over the same helpers that back geoscale_plot():
#
#   geom_geoscale()   region-keyed data -> dissolved geoframe -> choropleth
#   theme_geoscale()  the quiet map theme
#
# Why a layer factory and not a ggproto Geom (the same design contract as
# timescales::geom_calendar()): the geoscale inputs are column-NAME
# arguments, not aes() mappings, and each call returns ONE standard
# ggplot2::geom_sf() layer whose `data` is a function of the plot data
# (ggplot2 applies it lazily) -- so scales, facets, themes and additional
# layers all compose through the normal ggplot2 path, and geom_sf's
# layer_sf class brings coord_sf along automatically.
#
# ggplot2 and sf stay in Suggests; nothing here builds ggproto objects.
# =============================================================================

#' Geoscale layers for ggplot2
#'
#' Composable choropleth layers that put region-keyed data on a map inside
#' a normal `ggplot()` pipeline (the assembled-figure counterparts are
#' [`geoscale_plot()`] and [`geoscale_autoplot()`]):
#'
#' * `geom_geoscale()` — dissolves the object's geometry at `geoframe`
#'   (via [`geoscale_geometry()`]), aggregates the value column `z` per
#'   region with `fun`, and returns a standard [`ggplot2::geom_sf()`]
#'   layer (with its `coord_sf`, exactly as `geom_sf()` does) filled by
#'   the aggregated `value`. With `z = NULL` it draws plain boundaries.
#' * `theme_geoscale()` — the quiet map theme: no axes or graticule
#'   text, solid white plot background (transparent figures are
#'   illegible on dark-mode pages).
#'
#' The geoscale inputs are column **names**, not `aes()` mappings — each
#' call returns one plain sf layer whose data is derived from the plot
#' (or layer) data, so discrete/continuous scales, facets, and themes
#' work through the normal ggplot2 path, and further layers (labels,
#' points) stack on top.
#'
#' @param gs A [`Geoscale`] with attached geometry (see
#'   [`attach_geometry_geoscale()`]).
#' @param z Name of the numeric column of the data to aggregate and fill
#'   by; `NULL` draws plain boundaries.
#' @param geoframe Geoframe to draw. `NULL` is inferred: the single
#'   geoframe name among the data's columns (as in
#'   [`recast_geoscale()`]), or the atom geoframe when `z = NULL`.
#' @param region Name of the region-code column of the data. Defaults to
#'   the `geoframe`-named column when present, else `"region"`.
#' @param fun Aggregator collapsing multiple observations per region
#'   into one value. Default `mean`.
#' @param data A `data.frame`; `NULL` (default) uses the plot data.
#' @param precision Optional GEOS precision for the dissolve, forwarded
#'   to [`geoscale_geometry()`]. Default `0` = off.
#' @param ... Passed to [`ggplot2::geom_sf()`] (e.g. `colour`,
#'   `linewidth`), or for `theme_geoscale()` to [`ggplot2::theme()`].
#'
#' @return A [`ggplot2::geom_sf()`] layer (`theme_geoscale()` returns a
#'   theme).
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE) &&
#'     requireNamespace("sf", quietly = TRUE)) {
#'   library(ggplot2)
#'   sq <- function(x0) sf::st_polygon(list(cbind(
#'     c(x0, x0 + 1, x0 + 1, x0, x0), c(0, 0, 1, 1, 0))))
#'   gs <- geoscale_from_leaftable(
#'     data.frame(state = c("N", "N", "S"), atom = c("a", "b", "c"),
#'                km2 = c(1, 2, 3)),
#'     geoframes = c("state", "atom"), name = "toy"
#'   ) |>
#'     attach_geometry_geoscale(sf::st_sfc(sq(0), sq(1), sq(2)))
#'
#'   # data keyed at the drawn geoframe (recast finer data up first)
#'   ggplot(data.frame(state = c("N", "S"), capacity = c(1, 3))) +
#'     geom_geoscale(gs = gs, z = "capacity", geoframe = "state") +
#'     scale_fill_viridis_c() +
#'     theme_geoscale()
#' }
#' @export
geom_geoscale <- function(gs, z = NULL,
                          geoframe = NULL,
                          region = NULL,
                          fun = mean,
                          data = NULL,
                          precision = 0,
                          ...) {
  .need_gg_sf("geom_geoscale()")
  .check_geoscale(gs, "gs")
  if (is.null(S7::prop(gs, "geometry"))) {
    .stop(paste0("`gs` has no geometry; attach one with ",
                 "attach_geometry_geoscale()"))
  }

  if (is.null(z)) {
    gf <- geoframe %||% geoscale_geoframes(gs, finest = TRUE)
    .check_geoframe(gs, gf, "geoframe")
    return(ggplot2::geom_sf(data = geoscale_geometry(gs, gf,
                                                     precision = precision),
                            ggplot2::aes(geometry = geometry),
                            inherit.aes = FALSE, ...))
  }

  build <- function(d) {
    d <- as.data.frame(d)
    gf <- geoframe %||% .geo_infer_from(gs, d, region)
    .check_geoframe(gs, gf, "geoframe")
    key <- region %||% (if (gf %in% names(d)) gf else "region")
    .check_layer_cols(d, c(key, z))
    shp <- geoscale_geometry(gs, gf, precision = precision)
    agg <- vapply(split(d[[z]], as.character(d[[key]])), fun, numeric(1))
    shp$value <- unname(agg[shp[[gf]]])
    shp
  }
  ggplot2::geom_sf(
    data = if (is.null(data)) build else build(data),
    mapping = ggplot2::aes(fill = value, geometry = geometry),
    inherit.aes = FALSE,
    ...
  )
}

#' @rdname geom_geoscale
#' @export
theme_geoscale <- function(...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    .stop("theme_geoscale() requires ggplot2; install.packages(\"ggplot2\")")
  }
  ggplot2::theme_minimal() +
    ggplot2::theme(axis.text = ggplot2::element_blank(),
                   axis.ticks = ggplot2::element_blank(),
                   axis.title = ggplot2::element_blank(),
                   panel.grid = ggplot2::element_blank(),
                   panel.spacing = grid::unit(1, "lines"),
                   strip.text = ggplot2::element_text(size = 9,
                                                      margin = ggplot2::margin(
                                                        2, 2, 4, 2)),
                   # solid background by convention: transparent figures
                   # are illegible on dark-mode pages
                   plot.background = ggplot2::element_rect(fill = "white",
                                                           colour = NA),
                   ...)
}

#' @noRd
.need_gg_sf <- function(what) {
  for (pkg in c("ggplot2", "sf")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      .stop("%s requires %s; install.packages(\"%s\")", what, pkg, pkg)
    }
  }
  invisible(TRUE)
}

#' @noRd
.check_layer_cols <- function(d, cols) {
  missing <- setdiff(cols, names(d))
  if (length(missing) > 0L) {
    .stop("column(s) not found in the layer data: %s", .preview(missing))
  }
  invisible(d)
}

utils::globalVariables(c("value", "geometry"))
