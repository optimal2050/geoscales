# =============================================================================
# Adjacency — which features of a geoframe border which
# =============================================================================
# Contiguity is geometry, not domain knowledge: a clustering that must keep
# its groups in one piece needs a neighbour matrix, and so does any
# neighbourhood statistic. `nestedscales::cluster_contiguous(adjacency =)`
# consumes exactly this matrix, so the supplier belongs here rather than in
# each caller.
#
# Rook or queen, never "touching". `sf::st_touches()` reports contact of ANY
# dimension, so two squares meeting at one corner come back as neighbours.
# Whether that is wanted is a modelling choice and differs between callers --
# a lattice whose diagonal cells are not connected by a road is not the same
# graph as one where they are -- so the choice is named with the terms spatial
# analysis already uses rather than left to whichever predicate was handy.
# =============================================================================

#' Adjacency between the features of a geoframe
#'
#' Builds the neighbour matrix of a geoframe from attached geometry: which of
#' its codes share a border with which. The result is what
#' `nestedscales::cluster_contiguous(adjacency =)` consumes.
#'
#' @param x A [`GeoScale`] with geometry attached (see
#'   [`attach_geometry_geoscale()`]).
#' @param geoframe Geoframe whose features are compared. Defaults to the atom
#'   geoframe. Geometry is dissolved to it first, so any geoframe works.
#' @param within Optional coarser geoframe whose boundaries cut edges: two
#'   features in different `within` codes are never neighbours. `NULL`
#'   (default) keeps every border. Use it to confine a clustering to a parent,
#'   which also sets the floor on the number of groups obtainable — a
#'   clustering cannot merge below the number of connected components.
#' @param contiguity `"queen"` (default) counts contact of any dimension, so
#'   features meeting at a single corner are neighbours; `"rook"` requires a
#'   shared border of non-zero length. On a gridded or hexagonal lattice the
#'   two differ, and on real coastlines they occasionally do too, where three
#'   borders meet at a point.
#' @param isolated What to do with a feature that borders nothing — an island,
#'   an exclave, or a feature cut off by `within`. `"none"` (default) leaves
#'   it isolated. `"nearest"` joins it to the closest other feature, which is
#'   what a clustering needs to avoid a group of one. A distance tolerance is
#'   deliberately not offered: one wide enough to bridge a strait also links
#'   every pair of cells one apart on a lattice.
#' @param precision Optional GEOS precision passed to [`geoscale_geometry()`],
#'   for a constructed lattice whose shared vertices do not coincide exactly.
#'
#' @return A logical matrix, symmetric, with a `FALSE` diagonal and both
#'   dimnames the codes at `geoframe` in member order.
#'
#' @details
#' `isolated` is resolved **after** `within` has cut its edges, and the nearest
#' feature is sought among those `within` allows. Fixing isolation first would
#' hand a feature a neighbour that the mask then takes away again, leaving it
#' isolated after all.
#'
#' A feature whose `within` code is `NA` is its own group: unassigned codes do
#' not silently pool.
#'
#' On geographic (longitude/latitude) coordinates the two `contiguity` settings
#' do not use the same engine: `"queen"` goes through [`sf::st_touches()`],
#' which is spherical under s2, while `"rook"` goes through
#' [`sf::st_relate()`], which has no spherical implementation and warns that it
#' assumes the coordinates are planar. For contiguity the difference is
#' immaterial -- whether two polygons share a border does not depend on the
#' metric -- but project to an equal-area or local CRS first if the warning
#' matters or the geometry crosses the antimeridian.
#'
#' @seealso [`geoscale_geometry()`], [`geoscale_leaftable()`]
#'
#' @examples
#' \dontrun{
#' a <- geoscale_adjacency(gs, geoframe = "region")
#' sum(a) / 2                                    # number of borders
#' geoscale_adjacency(gs, "region", within = "zone")        # confined
#' geoscale_adjacency(gs, "region", contiguity = "rook")    # edges only
#' }
#' @export
geoscale_adjacency <- function(x, geoframe = NULL, within = NULL,
                               contiguity = c("queen", "rook"),
                               isolated = c("none", "nearest"),
                               precision = 0) {
  .check_geoscale(x)
  .need_sf("geoscale_adjacency()")
  contiguity <- match.arg(contiguity)
  isolated   <- match.arg(isolated)

  lv <- S7::prop(x, "geoframes")
  geoframe <- geoframe %||% lv[length(lv)]
  .check_geoframe(x, geoframe)
  if (!is.null(within)) {
    .check_geoframe(x, within, arg = "within")
    if (match(within, lv) >= match(geoframe, lv)) {
      .stop(paste0("`within` = \"%s\" must be COARSER than `geoframe` = ",
                   "\"%s\"; it names the parent whose boundaries cut edges."),
            within, geoframe)
    }
  }

  m <- geoscale_geometry(x, geoframe, precision = precision)
  codes <- as.character(m[[geoframe]])
  g <- sf::st_geometry(m)
  n <- length(codes)
  a <- matrix(FALSE, n, n, dimnames = list(codes, codes))
  if (n < 2L) return(a)

  # queen: contact of any dimension. rook: a shared border of length > 0 --
  # DE-9IM `F***1****` is "boundaries meet in a curve, interiors disjoint",
  # which a corner touch (`F***0****`) fails.
  nb <- if (identical(contiguity, "queen")) {
    sf::st_touches(g)
  } else {
    sf::st_relate(g, g, pattern = "F***1****")
  }
  for (i in seq_len(n)) if (length(nb[[i]])) a[i, nb[[i]]] <- TRUE
  a <- a | t(a)
  diag(a) <- FALSE

  allow <- NULL
  if (!is.null(within)) {
    par <- .parent_codes(x, geoframe, within, codes)
    allow <- outer(par, par, "==")
    a <- a & allow
  }

  if (identical(isolated, "nearest")) {
    alone <- which(rowSums(a) == 0L)
    if (length(alone)) {
      # a units matrix; `as.numeric()` strips the units without depending on
      # the `units` package, which is sf's business and not declared here
      d <- matrix(as.numeric(sf::st_distance(g)), n, n)
      for (i in alone) {
        v <- d[i, ]
        v[i] <- Inf
        # only a neighbour `within` would permit; an exclave alone in its
        # parent stays alone, which is the honest answer
        if (!is.null(allow)) v[!allow[i, ]] <- Inf
        if (all(!is.finite(v))) next
        j <- which.min(v)
        a[i, j] <- a[j, i] <- TRUE
      }
    }
  }
  a
}

#' A geoframe's codes mapped to their `within` parent, NA kept distinct
#'
#' An unassigned parent is given a code of its own, so `==` does not pool
#' every `NA` into one group (nor yield `NA` and poison the mask).
#' @noRd
.parent_codes <- function(x, geoframe, within, codes) {
  lt <- as.data.frame(S7::prop(x, "leaftable"))
  key <- as.character(lt[[geoframe]])
  par <- as.character(lt[[within]])
  keep <- !is.na(key) & !duplicated(key)
  p <- stats::setNames(par[keep], key[keep])[codes]
  unassigned <- is.na(p)
  p[unassigned] <- paste0("<NA:", codes[unassigned], ">")
  unname(p)
}
