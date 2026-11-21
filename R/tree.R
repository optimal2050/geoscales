# =============================================================================
# geoscale_id(), geoscale_tree() -- the identity of a GeoScale and its parts
# =============================================================================

#' A function of `nestedscales`, or NULL when the installed version lacks it
#' @noRd
.ns_fun <- function(name) {
  get0(name, envir = asNamespace("nestedscales"), inherits = FALSE)
}

#' The identity of a GeoScale
#'
#' Gives the identity of a [`GeoScale`]: its name and a hash of its
#' structure, as `"<name>@<hash>"`. The hash is computed from the geoframes
#' and the memberships of the regions, not from weights, labels or geometry,
#' so two objects with the same structure and different weights have the
#' same hash, and a subset differs from the object it was taken from.
#'
#' @param gs A [`GeoScale`].
#'
#' @return A single string.
#'
#' @seealso [`geoscale_tree()`]
#' @examplesIf !is.null(get0("scale_id", asNamespace("nestedscales")))
#' gs <- geoscale_example()
#' geoscale_id(gs)
#' geoscale_id(filter_geoscale(gs, "country", "N"))
#' @export
geoscale_id <- function(gs) {
  .check_geoscale(gs, "gs")
  f <- .ns_fun("scale_id")
  if (is.null(f)) .stop("geoscale_id() needs nestedscales >= 0.3.0")
  f(gs)
}

#' The parts `GeoScale` adds, and this package's verbs for the shared ones
#' @noRd
.geoscale_parts <- function(x, ...) {
  lt <- S7::prop(x, "leaftable")
  weights <- intersect(S7::prop(x, "meta")[["weights"]] %||% character(),
                       names(lt))
  rows <- data.frame(
    part = c("labels", "geometry", "hidden"),
    parent = "",
    mark = c(NA, "mutable", "mutable"),
    verb = c("attach_labels_geoscale()", "attach_geometry_geoscale()",
             "hide_geoframes_geoscale()"),
    note = c(NA, "one shape per row of the leaftable",
             "geoframes left out of plots"),
    stringsAsFactors = FALSE
  )
  if (length(weights) > 0L) {
    rows <- rbind(rows, data.frame(
      part = weights, parent = "leaftable", mark = "mutable",
      verb = "geoscale_add_weight()", note = NA_character_,
      stringsAsFactors = FALSE
    ))
  }
  rows
}

#' Register the description of the parts where `nestedscales` has the hook
#' @noRd
.register_geoscale_parts <- function() {
  gen <- .ns_fun("scale_payload_parts")
  if (is.null(gen)) return(invisible(FALSE))
  S7::method(gen, GeoScale) <- .geoscale_parts
  invisible(TRUE)
}

#' The parts of a GeoScale and which of them may change
#'
#' Lists the parts of a [`GeoScale`] as a tree: its properties, the columns
#' of the leaftable, the geometry and the hidden geoframes. Each part carries
#' one of three marks, defined by the identity of the object
#' ([`geoscale_id()`]), which is computed from the leaf column, the geoframe
#' names and the region codes:
#'
#' * `fixed`: the part enters the identity. Changing it gives another
#'   geoscale; the route is to build a new one with
#'   [`geoscale_from_leaftable()`].
#' * `derived`: the part is computed from another one and is never set.
#' * `mutable`: the part can change and the geoscale stays the same one. The
#'   function that changes it is named where there is one.
#'
#' The marks describe the object; they are not enforced on assignment.
#' `str()` on a `GeoScale` prints the same tree.
#'
#' @param x A [`GeoScale`].
#'
#' @return A data.frame of class `scale_tree`, one row per part: `part`, the
#'   `parent` property it belongs to (`""` for a property), its `kind`,
#'   `shape`, `mark`, the `verb` that changes it and a `note`. Printing it
#'   draws the tree.
#'
#' @seealso [`geoscale_id()`], [`hide_geoframes_geoscale()`]
#' @examplesIf !is.null(get0("scale_tree", asNamespace("nestedscales")))
#' geoscale_tree(geoscale_example())
#' tr <- geoscale_tree(geoscale_example())
#' tr$part[tr$mark == "fixed"]
#' @export
geoscale_tree <- function(x) {
  .check_geoscale(x)
  f <- .ns_fun("scale_tree")
  if (is.null(f)) .stop("geoscale_tree() needs nestedscales >= 0.3.0")
  f(x)
}
