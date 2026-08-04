# =============================================================================
# Plotting
# =============================================================================
# Ports the "by level" idea from `timeslices::autoplot.Calendar()`: one row per
# level, laid out on a shared cumulative-weight axis, so the nesting structure
# reads at a glance.
#
# With geometry attached, `geo_plot()` draws a choropleth. Without `sf` — or
# without geometry — `geo_autoplot()` gives an icicle instead, mirroring how
# `energyRt::plot_trade_map()` degrades to points and arrows when `sf` is
# missing.
#
# ggplot2 is in Suggests, so its `autoplot` generic cannot be imported at
# build time; the S3 method is registered in `.onLoad()` (see zzz.R) only if
# ggplot2 is actually installed.
# =============================================================================

# Human-readable names for the regions of one level.
#
# `@meta$labels` names a column of `leaves` holding a display name (energyRt's
# UTOPIA geoscale sets `labels = "name"`, giving "Oswestia" for "R1").
#
# The column is per-atom, so a label is only used where it is UNAMBIGUOUS for
# the region: every atom in the group must carry the same value. At the atom
# level that is always true; at a coarser level a zone made of Oswestia and
# Antidia has no name of its own, and labelling it "Oswestia" would be a
# fabrication -- so the code is kept instead.
#
# Returns a named character vector (code -> label) covering only the
# unambiguous codes, or NULL when the geoscale declares no labels.
#' @noRd
.region_labels <- function(x, level) {
  meta <- S7::prop(x, "meta")
  col  <- meta$labels
  if (is.null(col) || length(col) != 1L || is.na(col) || !nzchar(col)) {
    return(NULL)
  }
  leaves <- S7::prop(x, "leaves")
  if (!col %in% names(leaves) || !level %in% names(leaves)) return(NULL)

  code <- as.character(leaves[[level]])
  lab  <- as.character(leaves[[col]])
  keep <- !is.na(code) & !is.na(lab)
  if (!any(keep)) return(NULL)
  code <- code[keep]; lab <- lab[keep]

  by_code <- split(lab, code)
  uniq <- vapply(by_code, function(v) length(unique(v)) == 1L, logical(1))
  if (!any(uniq)) return(NULL)
  stats::setNames(vapply(by_code[uniq], function(v) v[1], character(1)),
                  names(by_code)[uniq])
}

# Apply the label lookup to a vector of codes, leaving unmatched codes alone.
#' @noRd
.apply_labels <- function(codes, lookup) {
  if (is.null(lookup)) return(as.character(codes))
  out <- unname(lookup[as.character(codes)])
  ifelse(is.na(out), as.character(codes), out)
}

#' @noRd
.need_ggplot <- function(what = "this operation") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    .stop(paste0("%s requires the 'ggplot2' package. Install it with ",
                 "install.packages(\"ggplot2\")."), what)
  }
  invisible(TRUE)
}

#' Icicle layout for a Geoscale
#'
#' Rectangle coordinates for a level-by-level structure plot: one row per
#' level, each region a rectangle whose width is its share of the weight.
#' Exposed so the layout can be drawn with something other than ggplot2.
#'
#' @param x A [`Geoscale`].
#' @param weight Weight column. `NULL` uses the default.
#'
#' @return A `data.frame` with columns `level`, `region`, `rank`, `xmin`,
#'   `xmax`, `ymin`, `ymax`, `weight`, `share`.
#'
#' @examples
#' head(geo_layout(geoscale_example()))
#' @export
geo_layout <- function(x, weight = NULL) {
  .check_geoscale(x)
  weight <- .resolve_weight(x, weight)
  lv     <- S7::prop(x, "levels")
  leaves <- S7::prop(x, "leaves")
  members <- S7::prop(x, "members")

  # Order atoms so that every parent group is contiguous.
  ord <- do.call(order, lapply(lv, function(l) {
    match(as.character(leaves[[l]]), members[[l]])
  }))
  leaves <- leaves[ord, , drop = FALSE]
  w <- as.numeric(leaves[[weight]])
  w[is.na(w)] <- 0
  total <- sum(w)
  if (total <= 0) .stop("weight `%s` sums to zero", weight)

  ends   <- cumsum(w)
  starts <- ends - w
  n_lv   <- length(lv)

  parts <- lapply(seq_along(lv), function(i) {
    codes <- as.character(leaves[[lv[i]]])
    # Contiguous runs of the same code at this level
    r <- rle(ifelse(is.na(codes), "\r_NA_", codes))
    end_i   <- cumsum(r$lengths)
    start_i <- end_i - r$lengths + 1L
    keep    <- r$values != "\r_NA_"
    data.frame(
      level  = lv[i],
      region = r$values[keep],
      rank   = i,
      xmin   = starts[start_i][keep] / total,
      xmax   = ends[end_i][keep] / total,
      ymin   = n_lv - i,
      ymax   = n_lv - i + 0.9,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, parts)
  out$weight <- (out$xmax - out$xmin) * total
  out$share  <- out$xmax - out$xmin
  rownames(out) <- NULL
  out
}

#' Plot a Geoscale
#'
#' Draws the hierarchy as an icicle: one row per level, coarsest at the top,
#' each region's width proportional to its share of the weight.
#'
#' This is the *structure* plot — it shows the Geoscale itself and needs no
#' geometry. For a map of values over regions, see [`geo_plot()`].
#'
#' Also registered as an `autoplot()` method, so `ggplot2::autoplot(gs)` works
#' when ggplot2 is installed.
#'
#' @param object A [`Geoscale`].
#' @param weight Weight column determining widths. `NULL` uses the default.
#' @param fill What to colour by: `"level"` or `"region"`.
#' @param label Draw region codes on the rectangles.
#' @param ... Unused.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   geo_autoplot(geoscale_example())
#' }
#' @export
geo_autoplot <- function(object, weight = NULL,
                         fill = c("level", "region"),
                         label = TRUE, ...) {
  .need_ggplot("geo_autoplot()")
  fill <- match.arg(fill)
  d <- geo_layout(object, weight = weight)
  d$.fill <- d[[fill]]
  lv <- S7::prop(object, "levels")
  nm <- S7::prop(object, "meta")$name

  # Display names are resolved per level (each level has its own lookup) but
  # written back in place, so row order stays aligned with the rectangles.
  d$.label <- d$region
  for (l in unique(d$level)) {
    i <- d$level == l
    d$.label[i] <- .apply_labels(d$region[i], .region_labels(object, l))
  }

  p <- ggplot2::ggplot(d) +
    ggplot2::geom_rect(
      ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
                   fill = .fill),
      colour = "white", linewidth = 0.3
    ) +
    ggplot2::scale_y_continuous(breaks = rev(seq_along(lv)) - 0.55,
                                labels = lv) +
    ggplot2::labs(x = "share of weight", y = NULL, fill = fill,
                  title = if (!is.null(nm) && nzchar(nm)) nm else NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

  if (isTRUE(label)) {
    p <- p + ggplot2::geom_text(
      ggplot2::aes(x = (xmin + xmax) / 2, y = (ymin + ymax) / 2,
                   label = .label),
      size = 2.8, colour = "grey10"
    )
  }
  if (fill == "level") p <- p + ggplot2::guides(fill = "none")
  p
}

#' @rdname geo_autoplot
#' @param x A [`Geoscale`].
#' @export
autoplot.Geoscale <- function(x, ...) geo_autoplot(x, ...)

#' Map data onto a Geoscale
#'
#' Draws a choropleth of `data` at `level`. Requires `sf`, `ggplot2`, and
#' geometry attached with [`geo_attach_geometry()`].
#'
#' This is the package's single choropleth renderer: callers that know what
#' their numbers *mean* (which variable, extensive or intensive, what units)
#' should prepare a `data.frame` and hand it here rather than draw their own
#' `geom_sf()`. `energyRt::geo_map()` works exactly that way.
#'
#' @param x A [`Geoscale`] with geometry attached.
#' @param data Optional `data.frame` with a code column named `level` and the
#'   column named by `fill`. When `NULL`, region outlines are drawn.
#' @param level Level to draw. Defaults to the atom level.
#' @param fill Name of the value column in `data` to colour by.
#' @param palette Viridis palette option (`"A"`..`"H"`) for the fill scale.
#'   `NULL` (default) leaves ggplot2's own scale in place.
#' @param title,subtitle Plot titles. `NULL` for none.
#' @param fill_label Legend title. Defaults to `fill`; pass `NULL` to drop it.
#' @param label Draw region labels. `TRUE` uses the display names declared by
#'   the geoscale's `@meta$labels` column when there is one, otherwise the
#'   region codes.
#' @param ... Passed to `ggplot2::geom_sf()`.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' geo_plot(gs, capacity_by_state, level = "state", fill = "capacity")
#'
#' # titled, viridis, with region names drawn on
#' geo_plot(gs, gen, level = "zone", fill = "value",
#'          palette = "D", title = "Generation", label = TRUE)
#' }
#' @export
geo_plot <- function(x, data = NULL, level = NULL, fill = NULL,
                     palette = NULL, title = NULL, subtitle = NULL,
                     fill_label = fill, label = FALSE, ...) {
  .check_geoscale(x)
  .need_sf("geo_plot()")
  .need_ggplot("geo_plot()")
  lv    <- S7::prop(x, "levels")
  level <- level %||% lv[length(lv)]

  shp <- geo_geometry(x, level = level)
  if (!is.null(data)) {
    if (!level %in% names(data)) .stop("`data` has no column `%s`", level)
    if (is.null(fill) || !fill %in% names(data)) {
      .stop("`fill` must name a column of `data`")
    }
    shp <- merge(shp, data[, c(level, fill)], by = level, all.x = TRUE)
  }

  shp$.fill <- if (is.null(fill)) NULL else shp[[fill]]
  p <- ggplot2::ggplot(shp)
  p <- if (is.null(fill)) {
    p + ggplot2::geom_sf(fill = "grey92", colour = "white", ...)
  } else {
    p + ggplot2::geom_sf(ggplot2::aes(fill = .fill), colour = "white", ...) +
      ggplot2::labs(fill = fill_label)
  }

  if (!is.null(palette) && !is.null(fill)) {
    p <- p + ggplot2::scale_fill_viridis_c(option = palette)
  }
  if (!is.null(title) || !is.null(subtitle)) {
    p <- p + ggplot2::labs(title = title, subtitle = subtitle)
  }
  if (isTRUE(label)) {
    shp$.label <- .apply_labels(shp[[level]], .region_labels(x, level))
    p <- p + ggplot2::geom_sf_text(
      data = shp, ggplot2::aes(label = .label), size = 2.8, colour = "grey20"
    )
  }
  p + ggplot2::theme_minimal()
}

# Columns referenced inside `aes()` by bare name.
utils::globalVariables(c("xmin", "xmax", "ymin", "ymax", ".fill", "region",
                         ".label"))
