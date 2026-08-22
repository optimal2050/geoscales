# =============================================================================
# Geometry — optional, sf-backed
# =============================================================================
# The core is geometry-free: `recast_geoscale()` and everything in filter.R operate
# on tables only. Geometry is needed for three jobs — building atoms from
# shapefiles, computing area weights, and plotting — all of which are R-side
# and optional. `sf` is therefore in Suggests, and every entry point here
# degrades or errors gracefully when it is absent.
# =============================================================================

#' @noRd
.need_sf <- function(what = "this operation") {
  if (!requireNamespace("sf", quietly = TRUE)) {
    .stop(paste0("%s requires the 'sf' package. Install it with ",
                 "install.packages(\"sf\")."), what)
  }
  invisible(TRUE)
}

#' Attach geometry to a Geoscale
#'
#' Stores an `sfc` on the object, aligned to `@leaftable` row order.
#'
#' @param x A [`Geoscale`].
#' @param geom An `sf` object or `sfc`. When `sf` with a code column, it is
#'   matched on `by`; when `sfc`, it must already be in `@leaftable` row order.
#' @param by Name of the code column in `geom` to match on. Defaults to the
#'   atom geoframe, then `"region"`.
#' @param geoframe Geoframe that `geom`'s codes refer to. Defaults to the atom
#'   geoframe. When coarser, each atom inherits its parent's geometry.
#'
#' @return A [`Geoscale`] with `@geometry` populated.
#'
#' @examples
#' \dontrun{
#' gs <- attach_geometry_geoscale(gs, sf_polygons, by = "adm0_a3")
#' }
#' @export
attach_geometry_geoscale <- function(x, geom, by = NULL, geoframe = NULL) {
  .check_geoscale(x)
  .need_sf("attach_geometry_geoscale()")
  leaves <- S7::prop(x, "leaftable")
  lv     <- S7::prop(x, "geoframes")
  geoframe  <- geoframe %||% lv[length(lv)]
  .check_geoframe(x, geoframe)

  if (inherits(geom, "sf")) {
    by <- by %||% if (geoframe %in% names(geom)) geoframe else "region"
    if (!by %in% names(geom)) {
      .stop("`geom` has no column `%s`; pass `by=`", by)
    }
    codes <- as.character(geom[[by]])
    g <- sf::st_geometry(geom)
    idx <- match(as.character(leaves[[geoframe]]), codes)
    if (all(is.na(idx))) {
      .stop("no codes in `geom$%s` match geoframe `%s`", by, geoframe)
    }
    n_miss <- sum(is.na(idx))
    if (n_miss > 0L) {
      .warn("%d atom(s) have no matching geometry and are empty", n_miss)
    }
    out <- g[idx]
  } else if (inherits(geom, "sfc")) {
    if (length(geom) != nrow(leaves)) {
      .stop(paste0("`geom` has %d geometries but `leaves` has %d rows; ",
                   "supply an `sf` object to match on codes instead"),
            length(geom), nrow(leaves))
    }
    out <- geom
  } else {
    .stop("`geom` must be an `sf` or `sfc` object")
  }

  meta <- S7::prop(x, "meta")
  meta$crs <- sf::st_crs(out)$input
  Geoscale(leaftable = leaves, geoframes = lv, members = S7::prop(x, "members"),
           geometry = out, meta = meta)
}

#' Geometry dissolved to a geoframe
#'
#' Unions the atom geometries within each code at `geoframe`.
#'
#' @param x A [`Geoscale`] with geometry attached.
#' @param geoframe Geoframe to dissolve to. Defaults to the atom geoframe.
#'
#' @return An `sf` object with a code column named `geoframe` plus `geometry`.
#'
#' @examples
#' \dontrun{
#' geoscale_geometry(gs, geoframe = "reg32")
#' }
#' @export
geoscale_geometry <- function(x, geoframe = NULL) {
  .check_geoscale(x)
  .need_sf("geoscale_geometry()")
  geom <- S7::prop(x, "geometry")
  if (is.null(geom)) {
    .stop("no geometry attached; see `attach_geometry_geoscale()`")
  }
  lv    <- S7::prop(x, "geoframes")
  geoframe <- geoframe %||% lv[length(lv)]
  .check_geoframe(x, geoframe)

  codes <- as.character(S7::prop(x, "leaftable")[[geoframe]])
  keep  <- !is.na(codes)
  codes <- codes[keep]
  geom  <- geom[keep]

  ord <- S7::prop(x, "members")[[geoframe]]
  ord <- ord[ord %in% unique(codes)]
  merged <- lapply(ord, function(cd) sf::st_union(geom[codes == cd]))
  out <- sf::st_sf(
    stats::setNames(list(ord), geoframe),
    geometry = do.call(c, merged),
    stringsAsFactors = FALSE
  )
  out
}

#' Compute area weights from attached geometry
#'
#' Adds an area column to `@leaftable`, measured on an equal-area projection.
#'
#' @param x A [`Geoscale`] with geometry attached.
#' @param name Name of the weight column to add.
#' @param crs Equal-area CRS used for the measurement. The default, World
#'   Cylindrical Equal Area, is global; a local equal-area projection is more
#'   accurate for a single region.
#'
#' @return A [`Geoscale`] with the area column added to `@leaftable` and
#'   registered in `meta$weights`.
#'
#' @details
#' Areas are only as good as the geometry. Cartographic sources are
#' *generalised for display*: measured on Natural Earth at 1:110m, Chile comes
#' out 10.6% too large and Indonesia 3.2% too small against the same data at
#' 1:10m. Use the finest geometry available, and treat the result as
#' indicative rather than authoritative.
#'
#' Geometry carrying no CRS is measured in its own planar units, with a
#' warning: reprojection is impossible, but a synthetic or teaching map is
#' still worth weighting by.
#'
#' @examples
#' \dontrun{
#' gs <- add_area_geoscale(gs, name = "km2")
#' }
#' @export
add_area_geoscale <- function(x, name = "km2", crs = "ESRI:54034") {
  .check_geoscale(x)
  .need_sf("add_area_geoscale()")
  geom <- S7::prop(x, "geometry")
  if (is.null(geom)) {
    .stop("no geometry attached; see `attach_geometry_geoscale()`")
  }
  # Geometry with no CRS is in arbitrary planar units (synthetic or teaching
  # maps often are), and `st_transform()` errors on it. Measure it as-is and
  # say so, rather than refusing to work.
  has_crs <- !is.na(sf::st_crs(geom))
  if (has_crs) {
    a <- sf::st_area(sf::st_make_valid(sf::st_transform(geom, crs)))
    km2 <- as.numeric(a) / 1e6
  } else {
    .warn(paste0("geometry has no CRS; `%s` is planar area in the ",
                 "coordinates' own units, not km2."), name)
    km2 <- as.numeric(sf::st_area(sf::st_make_valid(geom)))
  }

  leaves <- S7::prop(x, "leaftable")
  leaves[[name]] <- km2
  meta <- S7::prop(x, "meta")
  meta$weights <- union(meta$weights %||% character(), name)
  meta$default_weight <- meta$default_weight %||% name

  Geoscale(leaftable = leaves, geoframes = S7::prop(x, "geoframes"),
           members = S7::prop(x, "members"), geometry = geom, meta = meta)
}
