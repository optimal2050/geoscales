# =========================================================================== #
# Is the geometry on the rows it belongs to?
#
# The geometry is one shape per leaf, in leaftable row order, and carries no
# codes of its own. Whether shape i is the shape of code i can be PROVED only
# against a source that does carry codes; without one the object can still be
# searched for the marks a misplacement leaves.
# =========================================================================== #

#' One row of a check report
#' @noRd
.geom_finding <- function(check, status, detail, geoframe = NA_character_,
                          region = NA_character_) {
  data.frame(check = check, geoframe = geoframe, region = region,
             status = status, detail = detail, stringsAsFactors = FALSE)
}

#' Planar area of each shape, as plain numbers
#' @noRd
.geom_area <- function(g) {
  suppressWarnings(suppressMessages(as.numeric(sf::st_area(g))))
}

#' Area shared by two shape sets, element by element
#' @noRd
.geom_overlap <- function(a, b) {
  vapply(seq_along(a), function(i) {
    x <- tryCatch(
      suppressWarnings(suppressMessages(sf::st_intersection(a[i], b[i]))),
      error = function(e) NULL)
    if (is.null(x) || length(x) == 0L) return(0)
    sum(.geom_area(x))
  }, numeric(1))
}

#' Empty shapes and shapes held by more than one leaf
#' @noRd
.geom_check_shapes <- function(geom, codes, leaf) {
  out <- list()
  empty <- sf::st_is_empty(geom)
  for (i in which(empty)) {
    out[[length(out) + 1L]] <- .geom_finding(
      "empty", "fail", "the shape is empty", leaf, codes[i])
  }
  eq <- suppressMessages(sf::st_equals(geom))
  dup <- which(lengths(eq) > 1L & !empty)
  for (i in dup) {
    other <- setdiff(eq[[i]], i)
    if (length(other) == 0L || min(other) < i) next
    out[[length(out) + 1L]] <- .geom_finding(
      "duplicate", "warn",
      sprintf("the same shape is held by %s",
              paste(codes[other], collapse = ", ")), leaf, codes[i])
  }
  if (length(out) == 0L) {
    return(.geom_finding("shapes", "ok",
                         sprintf("%d shapes, none empty or repeated",
                                 length(geom))))
  }
  do.call(rbind, out)
}

#' A weight that measures the shapes, but in another order
#'
#' A weight proportional to the shapes' areas is an area weight. One that is
#' proportional only after both are sorted was computed from these shapes
#' when they sat on other rows.
#' @noRd
.geom_check_area <- function(geom, leaves, weights) {
  a <- .geom_area(geom)
  out <- list()
  if (length(a) < 2L || any(!is.finite(a)) || any(a <= 0) ||
        length(unique(signif(a, 6))) < 2L) {
    return(NULL)
  }
  flat <- function(r) {
    r <- r[is.finite(r)]
    length(r) > 0L && (max(r) - min(r)) <= 1e-3 * abs(stats::median(r))
  }
  for (w in weights) {
    v <- suppressWarnings(as.numeric(leaves[[w]]))
    if (any(!is.finite(v)) || any(v <= 0)) next
    if (flat(v / a)) {
      out[[length(out) + 1L]] <- .geom_finding(
        "area", "ok",
        sprintf("weight `%s` follows the areas of the shapes", w))
    } else if (flat(sort(v) / sort(a))) {
      out[[length(out) + 1L]] <- .geom_finding(
        "area", "fail",
        sprintf(paste0("weight `%s` holds the areas of these shapes in ",
                       "another row order"), w))
    }
  }
  if (length(out) == 0L) NULL else do.call(rbind, out)
}

#' Regions whose members do not form one connected piece
#'
#' Reported as a warning, never a failure: an archipelago is in several
#' pieces by nature, while leaves moved to the wrong rows make it so.
#' @noRd
.geom_check_pieces <- function(x, geom, leaves) {
  lv <- S7::prop(x, "geoframes")
  leaf <- .leaf_col(x)
  touch <- suppressMessages(sf::st_intersects(geom))
  pieces <- function(idx) {
    if (length(idx) <= 1L) return(1L)
    seen <- integer(); n <- 0L
    while (length(left <- setdiff(idx, seen)) > 0L) {
      n <- n + 1L
      front <- left[1L]
      while (length(front) > 0L) {
        seen <- c(seen, front)
        nb <- intersect(unique(unlist(touch[front])), idx)
        front <- setdiff(nb, seen)
      }
    }
    n
  }
  out <- list()
  n_checked <- 0L
  for (gf in setdiff(lv, leaf)) {
    codes <- as.character(leaves[[gf]])
    if (!anyDuplicated(codes[!is.na(codes)])) next   # one leaf per region
    for (cd in unique(codes[!is.na(codes)])) {
      n_checked <- n_checked + 1L
      k <- pieces(which(codes == cd))
      if (k > 1L) {
        out[[length(out) + 1L]] <- .geom_finding(
          "pieces", "warn",
          sprintf("its leaves form %d separate pieces", k), gf, cd)
      }
    }
  }
  if (n_checked == 0L) return(NULL)
  if (length(out) == 0L) {
    return(.geom_finding(
      "pieces", "ok",
      sprintf("%d grouped regions, each in one piece", n_checked)))
  }
  do.call(rbind, out)
}

#' Shape by shape against a source that carries codes
#' @noRd
.geom_check_reference <- function(x, reference, by, geoframe, tolerance) {
  if (!inherits(reference, "sf")) {
    .stop("`reference` must be an `sf` object with a code column")
  }
  by <- by %||% (if (geoframe %in% names(reference)) geoframe else NULL)
  if (is.null(by) || !by %in% names(reference)) {
    .stop(paste0("`by` must name the code column of `reference` ",
                 "(it has no column `%s`)"), by %||% geoframe)
  }
  shp <- geoscale_geometry(x, geoframe)
  codes <- as.character(shp[[geoframe]])
  g <- sf::st_geometry(shp)
  ref_codes <- as.character(reference[[by]])
  rg <- sf::st_geometry(reference)
  if (anyDuplicated(ref_codes)) {
    # several features per code: dissolve, as the object's own geometry is
    u <- unique(ref_codes)
    rg <- do.call(c, lapply(u, function(cd) {
      s <- suppressMessages(sf::st_union(rg[ref_codes == cd]))
      if (length(s) != 1L) sf::st_combine(s) else s
    }))
    ref_codes <- u
  }
  if (!is.na(sf::st_crs(g)) && !is.na(sf::st_crs(rg)) &&
        sf::st_crs(g) != sf::st_crs(rg)) {
    rg <- sf::st_transform(rg, sf::st_crs(g))
  } else if (is.na(sf::st_crs(g)) != is.na(sf::st_crs(rg))) {
    sf::st_crs(rg) <- sf::st_crs(g)
  }
  g <- suppressWarnings(sf::st_make_valid(g))
  rg <- suppressWarnings(sf::st_make_valid(rg))

  out <- list()
  m <- match(codes, ref_codes)
  for (i in which(is.na(m))) {
    out[[length(out) + 1L]] <- .geom_finding(
      "reference", "warn", "the reference has no shape for this code",
      geoframe, codes[i])
  }
  have <- which(!is.na(m))
  areal <- all(.geom_area(g[have]) > 0)
  agree <- if (areal) {
    ov <- .geom_overlap(g[have], rg[m[have]])
    ov / pmax(.geom_area(g[have]), .geom_area(rg[m[have]]))
  } else {
    as.numeric(lengths(suppressMessages(
      sf::st_equals(g[have], rg[m[have]]))) > 0L)   # row-wise below
  }
  if (!areal) {
    agree <- vapply(seq_along(have), function(j) {
      as.numeric(isTRUE(suppressMessages(
        sf::st_equals(g[have[j]], rg[m[have[j]]], sparse = FALSE))[1, 1]))
    }, numeric(1))
  }
  bad <- have[agree < tolerance]
  for (i in bad) {
    # which code's shape is this one really?
    cand <- suppressMessages(sf::st_intersects(g[i], rg))[[1L]]
    best <- NA_character_
    if (length(cand) > 0L && areal) {
      ov <- .geom_overlap(rep(g[i], length(cand)), rg[cand])
      sc <- ov / pmax(.geom_area(g[i]), .geom_area(rg[cand]))
      if (max(sc) >= tolerance) best <- ref_codes[cand[which.max(sc)]]
    }
    out[[length(out) + 1L]] <- .geom_finding(
      "reference", "fail",
      if (is.na(best)) {
        sprintf("the shape is not the reference shape of this code (%.1f%% shared)",
                100 * agree[match(i, have)])
      } else {
        sprintf("the shape is the reference shape of `%s`", best)
      }, geoframe, codes[i])
  }
  n_ok <- length(have) - length(bad)
  head <- .geom_finding(
    "reference", if (length(bad) == 0L) "ok" else "fail",
    sprintf("%d of %d shapes at `%s` are the reference shape of their code",
            n_ok, length(codes), geoframe))
  do.call(rbind, c(list(head), out))
}

#' Check that the geometry of a GeoScale is on the right regions
#'
#' The geometry of a [`GeoScale`] is one shape per leaf, in the row order of
#' the leaftable, with no codes of its own. A shape bound to the wrong row
#' gives a map in which the regions carry each other's values, and nothing
#' fails. `check_geometry_geoscale()` looks for that.
#'
#' With a `reference` -- an `sf` object that carries the codes -- the check is
#' a proof: every shape of the object is compared with the reference shape of
#' the same code, and a misplaced shape is reported with the code it really
#' belongs to.
#'
#' Without one the object is searched for the marks a misplacement leaves,
#' which is evidence, not proof:
#'
#' * `shapes`: empty shapes, and one shape held by several leaves;
#' * `area`: a weight that holds the areas of the shapes in another row
#'   order, as happens when the shapes moved after
#'   [`add_area_geoscale()`] measured them;
#' * `pieces`: a grouped region whose leaves do not form one connected
#'   piece. Islands do this legitimately, so it is a warning;
#' * `order`: whether the constructor re-sorted the rows, after which a
#'   geometry attached by position cannot be checked.
#'
#' @param x A [`GeoScale`] with geometry attached.
#' @param reference Optional `sf` object with one or more features per code:
#'   the source the geometry came from, or any trusted map of the same
#'   regions.
#' @param by Name of the code column of `reference`. Defaults to a column
#'   named as `geoframe`.
#' @param geoframe The geoframe `reference` describes. Defaults to the leaf
#'   geoframe; a coarser one compares the dissolved shapes.
#' @param tolerance Share of area two shapes must have in common to count as
#'   the same shape, between 0 and 1. Default `0.999`.
#' @param quiet `FALSE` (default) warns when a check fails.
#'
#' @return A `data.frame` of class `geoscale_geometry_check` with columns
#'   `check`, `geoframe`, `region`, `status` (`"ok"`, `"note"`, `"warn"` or
#'   `"fail"`) and `detail`, one row per finding. `all(out$status != "fail")`
#'   says whether it passed.
#'
#' @seealso [`attach_geometry_geoscale()`], [`geoscale_geometry()`]
#' @examples
#' \dontrun{
#' gs <- attach_geometry_geoscale(gs, shapes, by = "code")
#' check_geometry_geoscale(gs)                         # internal evidence
#' check_geometry_geoscale(gs, reference = shapes, by = "code")   # proof
#' }
#' @export
check_geometry_geoscale <- function(x, reference = NULL, by = NULL,
                                    geoframe = NULL, tolerance = 0.999,
                                    quiet = FALSE) {
  .check_geoscale(x)
  .need_sf("check_geometry_geoscale()")
  geom <- S7::prop(x, "geometry")
  if (is.null(geom)) {
    .stop("no geometry attached; see `attach_geometry_geoscale()`")
  }
  if (!is.numeric(tolerance) || length(tolerance) != 1L ||
        is.na(tolerance) || tolerance <= 0 || tolerance > 1) {
    .stop("`tolerance` must be a single number in (0, 1]")
  }
  leaves <- as.data.frame(S7::prop(x, "leaftable"))
  leaf <- .leaf_col(x)
  lv <- S7::prop(x, "geoframes")
  geoframe <- geoframe %||% lv[length(lv)]
  .check_geoframe(x, geoframe)
  codes <- as.character(leaves[[leaf]])
  valid <- suppressWarnings(sf::st_make_valid(geom))

  permuted <- isTRUE(S7::prop(x, "meta")$row_permuted)
  parts <- list(
    .geom_check_shapes(valid, codes, leaf),
    .geom_check_area(valid, leaves, geoscale_weights(x)),
    .geom_check_pieces(x, valid, leaves),
    .geom_finding(
      "order", if (permuted) "note" else "ok",
      if (permuted) {
        paste0("the rows were re-sorted at construction; a geometry ",
               "attached by position afterwards cannot be checked here")
      } else {
        "the rows are in the order they were given"
      }),
    if (!is.null(reference)) {
      .geom_check_reference(x, reference, by, geoframe, tolerance)
    }
  )
  out <- do.call(rbind, parts[!vapply(parts, is.null, logical(1))])
  rownames(out) <- NULL
  class(out) <- c("geoscale_geometry_check", "data.frame")
  n_fail <- sum(out$status == "fail" & !is.na(out$region)) +
    sum(out$status == "fail" & is.na(out$region) & out$check != "reference")
  if (!isTRUE(quiet) && any(out$status == "fail")) {
    .warn("the geometry failed %d check(s); see the returned table",
          max(1L, n_fail))
  }
  out
}

#' @export
print.geoscale_geometry_check <- function(x, ...) {
  n <- table(factor(x$status, c("ok", "note", "warn", "fail")))
  cat("Geometry check: ",
      if (n[["fail"]] > 0L) "FAILED" else if (n[["warn"]] > 0L) {
        "passed with warnings"
      } else "passed",
      if (!"reference" %in% x$check) " (no reference: evidence, not proof)",
      "\n", sep = "")
  show <- x[x$status != "ok" | is.na(x$region), , drop = FALSE]
  for (i in seq_len(nrow(show))) {
    where <- if (is.na(show$region[i])) "" else {
      sprintf(" %s `%s`:", show$geoframe[i], show$region[i])
    }
    cat(sprintf("  [%-4s] %-9s%s %s\n", show$status[i], show$check[i], where,
                show$detail[i]))
  }
  invisible(x)
}
