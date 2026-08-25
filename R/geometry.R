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
#' @param precision Optional GEOS precision for snapping near-coincident
#'   boundaries before the union (passed to [`sf::st_set_precision()`];
#'   e.g. `1e6` snaps coordinates to a `1e-6` grid, followed by
#'   [`sf::st_make_valid()`]). Default `0` = off — geometry is never
#'   silently altered. Use when a constructed lattice shows phantom
#'   internal borders after dissolve: that means adjacent atoms' shared
#'   vertices do not coincide exactly, and the honest fix is at the
#'   source; `precision=` is the workaround.
#'
#' @return An `sf` object with a code column named `geoframe` plus `geometry`.
#'
#' @examples
#' \dontrun{
#' geoscale_geometry(gs, geoframe = "reg32")
#' }
#' @export
geoscale_geometry <- function(x, geoframe = NULL, precision = 0) {
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
  if (precision > 0) {
    geom <- sf::st_make_valid(sf::st_set_precision(geom, precision))
  }

  ord <- S7::prop(x, "members")[[geoframe]]
  ord <- ord[ord %in% unique(codes)]
  merged <- lapply(ord, function(cd) {
    u <- sf::st_union(geom[codes == cd])
    # One code = one dissolved geometry, by contract. s2 can break this:
    # union of an s2-invalid polygon (e.g. a self-crossing ring that is
    # planar-valid) may return several parts even for a single input
    # feature. Collapse them -- they are still the one code's territory.
    # (Healing the source is better: sf::st_make_valid before attaching.)
    if (length(u) != 1L) u <- sf::st_combine(u)
    u
  })
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

#' Map coordinates to the regions that contain them
#'
#' The spatial twin of `timescales::datetime_to_timeslice()`: raw
#' observations enter the structure here. Each point is matched to the
#' region at `geoframe` (the atoms by default) whose geometry contains
#' it; points outside every region return `NA`. A point exactly on a
#' shared border is assigned to the first matching region in the
#' object's canonical order.
#'
#' @param x An `sf`/`sfc` object of points, or a data.frame with
#'   coordinate columns.
#' @param gs A [`Geoscale`] with geometry attached (see
#'   [`attach_geometry_geoscale()`]).
#' @param geoframe Geoframe to resolve to; `NULL` (default) uses the
#'   finest geoframe.
#' @param coords Names of the coordinate columns when `x` is a plain
#'   data.frame (x/longitude first, y/latitude second).
#' @param crs Coordinate reference system of those columns (default
#'   WGS84); points are transformed to the geometry's CRS before
#'   matching.
#'
#' @return A character vector of region codes, one per row/point of `x`.
#' @examples
#' \dontrun{
#' obs <- data.frame(lon = c(-21.9, -18.1), lat = c(64.1, 65.7), v = 1:2)
#' obs$region <- coords_to_region(obs, gs)
#' }
#' @export
coords_to_region <- function(x, gs, geoframe = NULL,
                             coords = c("lon", "lat"), crs = 4326) {
  .check_geoscale(gs)
  .need_sf("coords_to_region()")
  shp <- geoscale_geometry(gs, geoframe)     # errors when no geometry
  geoframe <- geoframe %||% geoscale_geoframes(gs, finest = TRUE)

  pts <- if (inherits(x, "sf")) {
    sf::st_geometry(x)
  } else if (inherits(x, "sfc")) {
    x
  } else if (is.data.frame(x)) {
    miss <- setdiff(coords, names(x))
    if (length(miss) > 0L) {
      .stop("`x` has no coordinate column(s): %s; pass `coords=`",
            paste(miss, collapse = ", "))
    }
    sf::st_geometry(sf::st_as_sf(as.data.frame(x)[, coords, drop = FALSE],
                                 coords = coords, crs = crs))
  } else {
    .stop("`x` must be an sf/sfc object or a data.frame with coordinates")
  }
  if (!is.na(sf::st_crs(pts)) && !is.na(sf::st_crs(shp)) &&
      sf::st_crs(pts) != sf::st_crs(shp)) {
    pts <- sf::st_transform(pts, sf::st_crs(shp))
  }
  hits <- sf::st_intersects(pts, shp)
  idx <- vapply(hits, function(h) if (length(h)) h[1L] else NA_integer_,
                integer(1))
  as.character(shp[[geoframe]])[idx]
}
