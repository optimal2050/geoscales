# =========================================================================== #
# Geoframes hidden from plots
#
# A geoframe may exist for calculation only: grid cells or clusters that carry
# the weights and the crosswalks but are not something a figure should show.
# The object lists such geoframes in `hidden`. Only the plots read the list;
# recasts, joins and navigation see every geoframe.
# =========================================================================== #

#' The hidden geoframes of an object, tolerating one saved without the property
#' @noRd
.hidden <- function(x) {
  h <- attr(x, "hidden", exact = TRUE)
  if (is.null(h)) return(character())
  h <- as.character(h)
  # in the object's own order, coarsest first
  lv <- S7::prop(x, "geoframes")
  c(lv[lv %in% h], setdiff(h, lv))
}

#' @noRd
.as_hidden <- function(hidden) {
  if (is.null(hidden)) return(character())
  if (!is.character(hidden) || anyNA(hidden)) {
    .stop("`hidden` must be a character vector of geoframe names")
  }
  unique(hidden)
}

#' Validation messages for a hidden set
#' @noRd
.check_hidden <- function(hidden, geoframes) {
  errs <- character()
  if (!is.character(hidden) || anyNA(hidden)) {
    return("`hidden` must be a character vector of geoframe names")
  }
  bad <- setdiff(hidden, geoframes)
  if (length(bad) > 0L) {
    errs <- c(errs, sprintf("`hidden` names geoframe(s) not in the object: %s",
                            paste(bad, collapse = ", ")))
  }
  if (anyDuplicated(hidden)) {
    errs <- c(errs, "`hidden` repeats a geoframe")
  }
  if (length(geoframes) > 0L && all(geoframes %in% hidden)) {
    errs <- c(errs, "`hidden` may not cover every geoframe")
  }
  errs
}

#' The hidden set of an object reduced to `geoframes`. When that would hide
#' all of them, nothing is hidden.
#' @noRd
.trim_hidden <- function(hidden, geoframes) {
  h <- intersect(hidden, geoframes)
  if (length(geoframes) > 0L && all(geoframes %in% h)) character() else h
}

#' The geoframes a plot draws
#'
#' `NULL` is the visible ones, `TRUE` all, a character vector exactly those
#' (hidden ones included), in the object's order.
#' @noRd
.drawn_geoframes <- function(x, geoframes = NULL) {
  lv <- S7::prop(x, "geoframes")
  if (is.null(geoframes)) return(setdiff(lv, .hidden(x)))
  if (isTRUE(geoframes)) return(lv)
  if (!is.character(geoframes) || length(geoframes) == 0L) {
    .stop("`geoframes` must be NULL, TRUE or a character vector of geoframes")
  }
  bad <- setdiff(geoframes, lv)
  if (length(bad) > 0L) {
    .stop("`geoframes` must name geoframes of the geoscale (unknown: %s)",
          paste(bad, collapse = ", "))
  }
  lv[lv %in% geoframes]
}

#' Whether an object is in the form of an earlier class definition
#'
#' Such an object lacks a property of the current class (`hidden`, `leaf`),
#' stores the name of the leaf column in the attribute `key`, or holds a
#' label table whose code column is `unit`.
#' @noRd
.old_form <- function(x) {
  !all(c("hidden", "leaf") %in% S7::prop_names(x)) ||
    is.null(attr(x, "leaf", exact = TRUE)) ||
    "unit" %in% names(attr(x, "labels", exact = TRUE))
}

#' Bring an object saved under an earlier class definition up to date
#'
#' An S7 object carries the class definition it was built with, so one saved
#' before a property existed cannot take it. Such an object is rebuilt under
#' the current definition, with everything it holds: the leaf column name
#' moves from `key` to `leaf`, and the label, attribute and alias tables get
#' their code column as `member`. An up-to-date object is returned as is.
#' @noRd
.upgrade_geoscale <- function(x) {
  if (!.old_form(x)) return(x)
  out <- GeoScale(
    leaftable = S7::prop(x, "leaftable"),
    geoframes = S7::prop(x, "geoframes"),
    members   = S7::prop(x, "members"),
    geometry  = S7::prop(x, "geometry"),
    meta      = S7::prop(x, "meta"),
    leaf      = .leaf_col(x),
    labels    = .label_table(x),
    hidden    = .hidden(x)
  )
  for (p in c("attributes", "aliases")) {
    v <- .legacy_member_col(attr(x, p, exact = TRUE))
    if (!is.null(v)) S7::prop(out, p) <- v
  }
  out
}

#' Write the hidden set, on the object brought up to date
#' @noRd
.set_hidden <- function(x, hidden) {
  S7::set_props(.upgrade_geoscale(x), hidden = hidden)
}

#' Hide geoframes from plots
#'
#' A geoframe can be needed for calculation without being something to show:
#' grid cells that carry the weights, or clusters used to build a crosswalk.
#' `hide_geoframes_geoscale()` marks such geoframes, and
#' [`gg_geoscale()`], `autoplot()` and `plot()` then leave them out unless
#' asked. Nothing else changes: recasts, joins and navigation use every
#' geoframe as before, and the identity of the object
#' ([`geoscale_id()`]) is the same.
#'
#' `show_geoframes_geoscale()` reverses it, for the named geoframes or for
#' all of them. At least one geoframe always stays visible.
#'
#' @param x A [`GeoScale`].
#' @param geoframes Character vector of geoframe names. In
#'   `show_geoframes_geoscale()`, `NULL` (default) shows all.
#'
#' @return The `GeoScale`, with its hidden set changed. The current sets are
#'   read with `geoscale_geoframes(x, visible = TRUE)` and
#'   `geoscale_geoframes(x, visible = FALSE)`.
#'
#' @seealso [`geoscale_geoframes()`], [`gg_geoscale()`]
#' @examples
#' gs <- hide_geoframes_geoscale(geoscale_example(), "cell")
#' gs
#' geoscale_geoframes(gs, visible = TRUE)
#' geoscale_geoframes(gs, visible = FALSE)
#' # calculations still reach the hidden geoframe
#' geoscale_regions(gs, "cell")
#' geoscale_geoframes(show_geoframes_geoscale(gs), visible = FALSE)
#' @export
hide_geoframes_geoscale <- function(x, geoframes) {
  .check_geoscale(x)
  if (!is.character(geoframes) || anyNA(geoframes)) {
    .stop("`geoframes` must be a character vector of geoframe names")
  }
  for (g in geoframes) .check_geoframe(x, g, "geoframes")
  .set_hidden(x, union(.hidden(x), geoframes))
}

#' @rdname hide_geoframes_geoscale
#' @export
show_geoframes_geoscale <- function(x, geoframes = NULL) {
  .check_geoscale(x)
  if (is.null(geoframes)) return(.set_hidden(x, character()))
  if (!is.character(geoframes) || anyNA(geoframes)) {
    .stop("`geoframes` must be NULL or a character vector of geoframe names")
  }
  for (g in geoframes) .check_geoframe(x, g, "geoframes")
  .set_hidden(x, setdiff(.hidden(x), geoframes))
}
