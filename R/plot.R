# =============================================================================
# Plotting
# =============================================================================
# Ports the "by geoframe" idea from `timeslices::autoplot.Calendar()`: one row per
# geoframe, laid out on a shared cumulative-weight axis, so the nesting structure
# reads at a glance.
#
# With geometry attached, `geoscale_plot()` draws a choropleth. Without `sf` — or
# without geometry — `geoscale_autoplot()` gives an icicle instead, mirroring how
# `energyRt::plot_trade_map()` degrades to points and arrows when `sf` is
# missing.
#
# ggplot2 is in Suggests, so its `autoplot` generic cannot be imported at
# build time; the S3 method is registered in `.onLoad()` (see zzz.R) only if
# ggplot2 is actually installed.
# =============================================================================

# Human-readable names for the regions of one geoframe.
#
# `@meta$labels` names a column of `leaves` holding a display name (energyRt's
# UTOPIA geoscale sets `labels = "name"`, giving "Oswestia" for "R1").
#
# The column is per-atom, so a label is only used where it is UNAMBIGUOUS for
# the region: every atom in the group must carry the same value. At the atom
# geoframe that is always true; at a coarser geoframe a zone made of Oswestia and
# Antidia has no name of its own, and labelling it "Oswestia" would be a
# fabrication -- so the code is kept instead.
#
# Returns a named character vector (code -> label) covering only the
# unambiguous codes, or NULL when the geoscale declares no labels.
#' @noRd
.region_labels <- function(x, geoframe) {
  meta <- S7::prop(x, "meta")
  col  <- meta$labels
  if (is.null(col) || length(col) != 1L || is.na(col) || !nzchar(col)) {
    return(NULL)
  }
  leaves <- S7::prop(x, "leaftable")
  if (!col %in% names(leaves) || !geoframe %in% names(leaves)) return(NULL)

  code <- as.character(leaves[[geoframe]])
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
#' Rectangle coordinates for a geoframe-by-geoframe structure plot: one row per
#' geoframe, each region a rectangle whose width is its share of the weight.
#' Exposed so the layout can be drawn with something other than ggplot2.
#'
#' @param x A [`Geoscale`].
#' @param weight Weight column. `NULL` uses the default.
#'
#' @return A `data.frame` with columns `geoframe`, `region`, `rank`, `xmin`,
#'   `xmax`, `ymin`, `ymax`, `weight`, `share`.
#'
#' @examples
#' head(geoscale_layout(geoscale_example()))
#' @export
geoscale_layout <- function(x, weight = NULL) {
  .check_geoscale(x)
  weight <- .resolve_weight(x, weight)
  lv     <- S7::prop(x, "geoframes")
  leaves <- S7::prop(x, "leaftable")
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
    # Contiguous runs of the same code at this geoframe
    r <- rle(ifelse(is.na(codes), "\r_NA_", codes))
    end_i   <- cumsum(r$lengths)
    start_i <- end_i - r$lengths + 1L
    keep    <- r$values != "\r_NA_"
    data.frame(
      geoframe  = lv[i],
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
#' Draws the hierarchy as an icicle: one row per geoframe, coarsest at the top,
#' each region's width proportional to its share of the weight.
#'
#' This is the *structure* plot — it shows the Geoscale itself and needs no
#' geometry. For a map of values over regions, see [`geoscale_plot()`].
#'
#' Also registered as an `autoplot()` method, so `ggplot2::autoplot(gs)` works
#' when ggplot2 is installed.
#'
#' @param x A [`Geoscale`].
#' @param type `"icicle"` (default) or `"stack"` — the axonometric
#'   stacked-maps view: one sheared map plane per geoframe, coarsest on
#'   top, the same atoms dissolved at each resolution. Requires attached
#'   geometry (and the sf package); `weight`/`fill`/`label` apply to the
#'   icicle only.
#' @param weight Weight column determining widths. `NULL` uses the default.
#' @param fill What to colour by: `"geoframe"` or `"region"`.
#' @param label Draw region codes on the rectangles.
#' @param view `type = "stack"` only: a predefined point of view --
#'   `"oblique"` (the shear/depth default), `"top-down"`, `"cavalier"`,
#'   `"cabinet"`, `"military"`, `"isometric"`, `"dimetric"`,
#'   `"trimetric"`, or `"perspective"` (receding planes shrink).
#' @param angle,ratio `type = "stack"` only: oblique view by angle
#'   (degrees of the receding axis) and foreshortening ratio --
#'   `e2 = ratio * (cos(angle), sin(angle))`. Overridden by `view`.
#' @param shear,depth,gap `type = "stack"` only: raw receding-axis
#'   components (`e2 = (shear, depth)`; used when neither `view` nor
#'   `angle`/`ratio` is given) and the vertical spacing between planes.
#'   `gap = NULL` (default) spaces planes almost touching, with a slight
#'   overlap.
#' @param rotate `type = "stack"` only: in-plane rotation of each plane
#'   (degrees, counter-clockwise) -- point North where you want it.
#' @param direction `type = "stack"` only: `"up"` (default) stacks the
#'   coarsest geoframe on top; `"down"` puts it at the bottom.
#' @param precision `type = "stack"` only: GEOS precision for the
#'   dissolve, forwarded to [`geoscale_geometry()`]. Default `0` = off.
#' @param data,z Colour the figure by a value instead of by structure:
#'   works for BOTH types -- the icicle fills each band's rectangles
#'   (overriding `fill`), the stack fills each plane. `data` must carry
#'   the atom geoframe as a key column plus the value column named by
#'   `z`; every coarser geoframe gets the value recast up with
#'   [`recast_geoscale()`] (see `rule`), so the whole figure shares one
#'   continuous fill scale (legend title via `labs(fill = )`).
#' @param rule With `data`: aggregation rule used to recast `z` from
#'   the atoms to each coarser geoframe (`"weighted_mean"` default; see
#'   [`recast_geoscale()`]). The icicle `weight` argument doubles as
#'   the weight column for `"weighted_mean"` (`NULL` = the geoscale's
#'   default weight).
#' @param labels `type = "stack"` only: character vector of geoframes
#'   whose regions get their display names (the `@meta$labels` column,
#'   falling back to codes) drawn on the plane. `NULL` (default) = none.
#' @param colour,linewidth `type = "stack"` only: region border colour
#'   and width, recycled across the planes (so
#'   `colour = c("white", "grey40", "white")` styles one plane per
#'   entry). Defaults `"grey35"` and `0.2` -- ggplot2's own sf polygon
#'   border.
#' @param frame `type = "stack"` only: draw each plane's outline (the
#'   footprint box run through the same projection) as a guide --
#'   curved shapes are much easier to read in oblique views with the
#'   plane edges visible. `TRUE` uses `"grey80"`, a colour string uses
#'   that colour, `NULL` (default) draws no frames.
#' @param frame_fill `type = "stack"` only: fill for the plane sheets.
#'   Best mostly transparent, e.g.
#'   `frame_fill = ggplot2::alpha("grey60", 0.12)` -- the panes then
#'   read as glass sheets and slightly dim what lies beneath them.
#'   Setting a fill draws the frames even without `frame`; `NA`
#'   (default) = no fill.
#' @param connectors `type = "stack"` only: draw dashed lines joining
#'   the corresponding frame corners of adjacent planes -- the vertical
#'   guides of the stack. `TRUE` uses the frame colour, a colour string
#'   picks its own; default `FALSE`.
#' @param palette `type = "stack"` only: viridis palette option
#'   (`"A"`..`"H"`) for the plane fill. Default `"G"`. `NULL` adds no
#'   fill scale at all, so you can supply your own -- e.g.
#'   `energypal::scale_fill_energy_b()` for the Global Wind Atlas
#'   colours on their absolute breaks.
#' @param ... Unused.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   geoscale_autoplot(geoscale_example())
#' }
#' @export
geoscale_autoplot <- function(x, type = c("icicle", "stack"),
                              weight = NULL,
                              fill = c("geoframe", "region"),
                              label = TRUE,
                              view = NULL, angle = NULL, ratio = NULL,
                              shear = 0.45, depth = 0.55, gap = NULL,
                              rotate = 0, direction = c("up", "down"),
                              precision = 0,
                              data = NULL, z = NULL,
                              rule = "weighted_mean",
                              labels = NULL, palette = "G",
                              colour = "grey35", linewidth = 0.2,
                              frame = NULL, frame_fill = NA,
                              connectors = FALSE,
                              ...) {
  .need_ggplot("geoscale_autoplot()")
  type <- match.arg(type)
  if (type == "stack") {
    return(.geoscale_stack_plot(x, view = view, angle = angle,
                                ratio = ratio, shear = shear,
                                depth = depth, gap = gap,
                                rotate = rotate, direction = direction,
                                precision = precision,
                                data = data, z = z, rule = rule,
                                weight = weight, labels = labels,
                                palette = palette,
                                colour = colour, linewidth = linewidth,
                                frame = frame, frame_fill = frame_fill,
                                connectors = connectors))
  }
  fill <- match.arg(fill)
  d <- geoscale_layout(x, weight = weight)
  lv <- S7::prop(x, "geoframes")
  nm <- S7::prop(x, "meta")$name
  vals <- NULL
  if (!is.null(data)) {
    # data fill: each band's rectangles carry the value recast to that
    # geoframe (widths still encode weight shares); overrides `fill`
    vals <- .geoscale_frame_values(x, lv, data, z, rule, weight)
    d$.fill <- NA_real_
    for (gf in lv) {
      i <- d$geoframe == gf
      d$.fill[i] <- vals[[gf]][[z]][match(d$region[i], vals[[gf]][[gf]])]
    }
  } else {
    d$.fill <- d[[fill]]
  }

  # Display names are resolved per geoframe (each geoframe has its own lookup) but
  # written back in place, so row order stays aligned with the rectangles.
  d$.label <- d$region
  for (l in unique(d$geoframe)) {
    i <- d$geoframe == l
    d$.label[i] <- .apply_labels(d$region[i], .region_labels(x, l))
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

  if (!is.null(vals)) {
    # continuous value fill: viridis + a retitle-able legend, and label
    # colours that keep contrast on dark cells
    p <- p + ggplot2::scale_fill_viridis_c(option = "G") +
      ggplot2::labs(fill = z)
  }
  if (isTRUE(label)) {
    lab_col <- "grey10"
    if (!is.null(vals)) {
      rng <- range(d$.fill, finite = TRUE)
      f01 <- if (diff(rng) > 0) (d$.fill - rng[1]) / diff(rng) else 0.5
      f01[!is.finite(f01)] <- 0
      lab_col <- ifelse(f01 < 0.5, "white", "grey15")
    }
    p <- p + ggplot2::geom_text(
      ggplot2::aes(x = (xmin + xmax) / 2, y = (ymin + ymax) / 2,
                   label = .label),
      size = 2.8, colour = lab_col
    )
  }
  if (is.null(vals) && fill == "geoframe") {
    p <- p + ggplot2::guides(fill = "none")
  }
  p
}

#' Per-geoframe recast of an atom-keyed value table
#'
#' The shared engine behind the data fills of both geoscale figures
#' (icicle bands and stack planes): recast `data[[z]]` from the atom
#' geoframe to every geoframe in `gfs` with [`recast_geoscale()`].
#' Returns NULL when `data` is NULL; a named list of data.frames
#' (one per geoframe, keyed by that geoframe's codes) otherwise.
#' @noRd
.geoscale_frame_values <- function(x, gfs, data, z, rule, weight) {
  if (is.null(data)) return(NULL)
  atom_gf <- gfs[length(gfs)]
  if (is.null(z) || !z %in% names(data)) {
    .stop("`z` must name a value column of `data`")
  }
  if (!atom_gf %in% names(data)) {
    .stop(paste0("`data` must be keyed by the atom geoframe ",
                 "(column `%s`); recast coarser data down first"),
          atom_gf)
  }
  vals <- lapply(gfs, function(gf) {
    if (gf == atom_gf) return(data[, c(atom_gf, z)])
    recast_geoscale(data[, c(atom_gf, z)], x,
                    from = atom_gf, to = gf,
                    values = z, rule = rule, weight = weight)
  })
  stats::setNames(vals, gfs)
}

#' @rdname geoscale_autoplot
#' @param x A [`Geoscale`].
#' @exportS3Method ggplot2::autoplot
autoplot.Geoscale <- function(x, ...) geoscale_autoplot(x, ...)

#' @rdname geoscale_leaftable
#' @exportS3Method ggplot2::fortify
fortify.Geoscale <- function(model, data, ...) {
  geoscale_leaftable(model)
}

#' Map data onto a Geoscale
#'
#' Draws a choropleth of `data` at `geoframe`. Requires `sf`, `ggplot2`, and
#' geometry attached with [`attach_geometry_geoscale()`].
#'
#' This is the package's single choropleth renderer: callers that know what
#' their numbers *mean* (which variable, extensive or intensive, what units)
#' should prepare a `data.frame` and hand it here rather than draw their own
#' `geom_sf()`. `energyRt::geo_map()` works exactly that way.
#'
#' @param x A [`Geoscale`] with geometry attached.
#' @param data Optional `data.frame` with a code column named `geoframe` and the
#'   column named by `fill`. When `NULL`, region outlines are drawn.
#' @param geoframe Geoframe to draw. Defaults to the atom geoframe.
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
#' geoscale_plot(gs, capacity_by_state, geoframe = "state", fill = "capacity")
#'
#' # titled, viridis, with region names drawn on
#' geoscale_plot(gs, gen, geoframe = "zone", fill = "value",
#'          palette = "D", title = "Generation", label = TRUE)
#' }
#' @export
geoscale_plot <- function(x, data = NULL, geoframe = NULL, fill = NULL,
                     palette = NULL, title = NULL, subtitle = NULL,
                     fill_label = fill, label = FALSE, ...) {
  .check_geoscale(x)
  .need_sf("geoscale_plot()")
  .need_ggplot("geoscale_plot()")
  lv    <- S7::prop(x, "geoframes")
  geoframe <- geoframe %||% lv[length(lv)]

  shp <- geoscale_geometry(x, geoframe = geoframe)
  if (!is.null(data)) {
    if (!geoframe %in% names(data)) .stop("`data` has no column `%s`", geoframe)
    if (is.null(fill) || !fill %in% names(data)) {
      .stop("`fill` must name a column of `data`")
    }
    shp <- merge(shp, data[, c(geoframe, fill)], by = geoframe, all.x = TRUE)
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
    shp$.label <- .apply_labels(shp[[geoframe]], .region_labels(x, geoframe))
    p <- p + ggplot2::geom_sf_text(
      data = shp, ggplot2::aes(label = .label), size = 2.8, colour = "grey20"
    )
  }
  p + ggplot2::theme_minimal()
}

# Columns referenced inside `aes()` by bare name.
utils::globalVariables(c("xmin", "xmax", "ymin", "ymax", ".fill", "region",
                         "code", "gf", "y",
                         ".label", ".z", "xend", "yend"))

# -----------------------------------------------------------------------------
# The axonometric stack view (type = "stack")
# -----------------------------------------------------------------------------

#' Resolve a stack point of view to screen axes
#' (duplicated verbatim from timescales/R/plot.R -- keep in sync)
#' @noRd
.stack_view <- function(view = NULL, angle = NULL, ratio = NULL,
                        shear = 0.5, depth = 0.3) {
  deg <- pi / 180
  if (!is.null(view)) {
    view <- match.arg(view, c("oblique", "top-down", "cavalier",
                              "cabinet", "military", "isometric",
                              "dimetric", "trimetric", "perspective"))
    return(switch(view,
      "oblique"     = list(e1 = c(1, 0), e2 = c(shear, depth), scale = 1),
      "top-down"    = list(e1 = c(1, 0), e2 = c(0, 1), scale = 1),
      "cavalier"    = list(e1 = c(1, 0),
                           e2 = c(cos(45 * deg), sin(45 * deg)),
                           scale = 1),
      "cabinet"     = list(e1 = c(1, 0),
                           e2 = 0.5 * c(cos(45 * deg), sin(45 * deg)),
                           scale = 1),
      "military"    = list(e1 = c(cos(45 * deg), sin(45 * deg)),
                           e2 = c(-sin(45 * deg), cos(45 * deg)),
                           scale = 1),
      "isometric"   = list(e1 = c(cos(30 * deg), sin(30 * deg)),
                           e2 = c(-cos(30 * deg), sin(30 * deg)),
                           scale = 1),
      "dimetric"    = list(e1 = c(cos(26.565 * deg), sin(26.565 * deg)),
                           e2 = c(-cos(26.565 * deg), sin(26.565 * deg)),
                           scale = 1),
      "trimetric"   = list(e1 = c(cos(10 * deg), sin(10 * deg)),
                           e2 = 0.9 * c(-cos(40 * deg), sin(40 * deg)),
                           scale = 1),
      "perspective" = list(e1 = c(1, 0),
                           e2 = 0.5 * c(cos(45 * deg), sin(45 * deg)),
                           scale = 0.82)
    ))
  }
  if (!is.null(angle) || !is.null(ratio)) {
    a <- (angle %||% 45) * deg
    return(list(e1 = c(1, 0), e2 = (ratio %||% 0.5) * c(cos(a), sin(a)),
                scale = 1))
  }
  list(e1 = c(1, 0), e2 = c(shear, depth), scale = 1)
}

#' Draw the geoscale as stacked map planes under a chosen point of view
#'
#' One plane per geoframe, coarsest on top: the same atoms, dissolved at
#' each resolution. Footprints are normalized to a unit box, mapped
#' through the view axes (rows of the affine matrix are the screen
#' images of the in-plane axes), optionally shrunk per layer
#' (perspective), and lifted; painter order is bottom (finest) first, so
#' planes may overlap when `gap` is small.
#' @noRd
.geoscale_stack_plot <- function(x, view = NULL, angle = NULL,
                                 ratio = NULL, shear = 0.45,
                                 depth = 0.55, gap = NULL,
                                 rotate = 0,
                                 direction = c("up", "down"),
                                 precision = 0,
                                 data = NULL, z = NULL,
                                 rule = "weighted_mean",
                                 weight = NULL,
                                 labels = NULL, palette = "G",
                                 colour = "grey35", linewidth = 0.2,
                                 frame = NULL, frame_fill = NA,
                                 connectors = FALSE) {
  .need_sf("geoscale_autoplot(type = \"stack\")")
  if (is.null(S7::prop(x, "geometry"))) {
    .stop(paste0("the stack view needs attached geometry; use ",
                 "attach_geometry_geoscale(), or the icicle view ",
                 "(type = \"icicle\") which needs none"))
  }
  v <- .stack_view(view, angle, ratio, shear, depth)
  direction <- match.arg(direction)
  gfs <- S7::prop(x, "geoframes")

  # value fill: `data` is keyed at the atoms; every coarser plane gets
  # the value recast up so one continuous scale spans the whole stack
  vals <- .geoscale_frame_values(x, gfs, data, z, rule, weight)
  if (!is.null(labels)) {
    bad <- setdiff(labels, gfs)
    if (length(bad)) {
      .stop("`labels` must name geoframes of the geoscale (unknown: %s)",
            paste(bad, collapse = ", "))
    }
  }
  rad <- rotate * pi / 180
  R <- matrix(c(cos(rad), -sin(rad), sin(rad), cos(rad)), 2, 2)
  M <- R %*% rbind(v$e1, v$e2)    # in-plane rotation, then projection
  ctr <- c(c(0.5, 0.5) %*% M)

  norm01 <- function(g) {
    bb <- sf::st_bbox(g)
    (g - c(bb[["xmin"]], bb[["ymin"]])) /
      max(bb[["xmax"]] - bb[["xmin"]], bb[["ymax"]] - bb[["ymin"]])
  }

  shapes <- lapply(gfs, function(gf)
    geoscale_geometry(x, gf, precision = precision))
  planes <- lapply(shapes, function(shp) norm01(sf::st_geometry(shp)) * M)

  # default spacing: planes almost touching, slight overlap -- derived
  # from the ACTUAL screen height of the transformed footprint
  bb1 <- sf::st_bbox(planes[[length(planes)]])
  gap <- gap %||% (0.85 * (bb1[["ymax"]] - bb1[["ymin"]]))

  nk <- length(gfs)
  zlev <- if (direction == "up") (nk - seq_len(nk)) * gap
          else (seq_len(nk) - 1) * gap
  top_rank <- if (direction == "up") seq_len(nk) - 1 else nk - seq_len(nk)
  layers <- lapply(seq_along(gfs), function(k) {
    sk <- v$scale^top_rank[k]                 # top plane is largest
    g <- (planes[[k]] - ctr) * sk + ctr + c(0, zlev[k])
    d <- sf::st_sf(code = shapes[[k]][[gfs[k]]], gf = gfs[k], geometry = g)
    if (!is.null(vals)) {
      d$.z <- vals[[k]][[z]][match(d$code, vals[[k]][[gfs[k]]])]
    }
    d
  })

  # plane frames ("sheets"): the footprint bbox, slightly padded, run
  # through the same transform as its plane -- guide lines that keep
  # curved shapes readable under oblique views. Connectors join the
  # corresponding corners of adjacent planes.
  frame_col <- if (isTRUE(frame)) "grey80"
               else if (is.character(frame)) frame else NULL
  conn_col  <- if (isTRUE(connectors)) frame_col %||% "grey80"
               else if (is.character(connectors)) connectors else NULL
  draw_frame <- !is.null(frame_col) || !is.na(frame_fill)
  frames <- NULL
  if (draw_frame || !is.null(conn_col)) {
    nb <- sf::st_bbox(norm01(sf::st_geometry(shapes[[1]])))
    fp <- 0.03 * max(nb[["xmax"]] - nb[["xmin"]],
                     nb[["ymax"]] - nb[["ymin"]])
    cn <- rbind(c(nb[["xmin"]] - fp, nb[["ymin"]] - fp),
                c(nb[["xmax"]] + fp, nb[["ymin"]] - fp),
                c(nb[["xmax"]] + fp, nb[["ymax"]] + fp),
                c(nb[["xmin"]] - fp, nb[["ymax"]] + fp)) %*% M
    frames <- lapply(seq_len(nk), function(k) {
      q <- sweep(sweep(cn, 2, ctr) * v$scale^top_rank[k], 2, ctr, `+`)
      data.frame(x = q[, 1], y = q[, 2] + zlev[k])
    })
  }

  xr <- range(vapply(layers, function(l)
    sf::st_bbox(l)[c("xmin", "xmax")], numeric(2)))
  yr <- range(vapply(layers, function(l)
    sf::st_bbox(l)[c("ymin", "ymax")], numeric(2)))
  if (!is.null(frames)) {
    xr <- range(xr, unlist(lapply(frames, `[[`, "x")))
    yr <- range(yr, unlist(lapply(frames, `[[`, "y")))
  }
  span <- xr[2] - xr[1]

  lab <- do.call(rbind, lapply(seq_along(gfs), function(k) {
    bb <- if (draw_frame) {              # anchor to the plane's frame
      c(xmin = min(frames[[k]]$x),
        ymin = min(frames[[k]]$y), ymax = max(frames[[k]]$y))
    } else {
      b <- sf::st_bbox(layers[[k]])
      c(xmin = b[["xmin"]], ymin = b[["ymin"]], ymax = b[["ymax"]])
    }
    data.frame(gf = gfs[k], x = bb[["xmin"]] - 0.02 * span,
               y = (bb[["ymin"]] + bb[["ymax"]]) / 2,
               stringsAsFactors = FALSE)
  }))

  col_k <- rep_len(colour, nk)
  lwd_k <- rep_len(linewidth, nk)
  p <- ggplot2::ggplot()
  if (!is.null(conn_col)) {                    # under everything
    ord <- order(zlev)
    seg <- do.call(rbind, lapply(seq_len(nk - 1), function(i) {
      data.frame(x = frames[[ord[i]]]$x, y = frames[[ord[i]]]$y,
                 xend = frames[[ord[i + 1]]]$x,
                 yend = frames[[ord[i + 1]]]$y)
    }))
    p <- p + ggplot2::geom_segment(
      data = seg,
      ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
      colour = conn_col, linewidth = 0.25, linetype = "22"
    )
  }
  for (k in order(zlev)) {                     # lower planes first
    if (draw_frame) {                          # the plane's sheet
      p <- p + ggplot2::geom_polygon(data = frames[[k]],
                                     ggplot2::aes(x = x, y = y),
                                     fill = frame_fill,
                                     colour = frame_col %||% NA,
                                     linewidth = 0.3)
    }
    p <- if (is.null(vals)) {
      p + ggplot2::geom_sf(data = layers[[k]],
                           ggplot2::aes(fill = code),
                           colour = col_k[k], linewidth = lwd_k[k],
                           show.legend = FALSE)
    } else {
      p + ggplot2::geom_sf(data = layers[[k]],
                           ggplot2::aes(fill = .z),
                           colour = col_k[k], linewidth = lwd_k[k])
    }
  }
  p <- p +
    ggplot2::geom_text(data = lab,
                       ggplot2::aes(x = x, y = y, label = gf),
                       hjust = 1, size = 3.2, colour = "grey25")
  if (!is.null(labels)) {                      # region names, over all planes
    labdf <- do.call(rbind, lapply(match(labels, gfs), function(k) {
      pts <- suppressWarnings(
        sf::st_point_on_surface(sf::st_geometry(layers[[k]])))
      xy <- sf::st_coordinates(pts)
      data.frame(x = xy[, 1], y = xy[, 2],
                 .label = .apply_labels(layers[[k]]$code,
                                        .region_labels(x, gfs[k])),
                 stringsAsFactors = FALSE)
    }))
    p <- p + ggplot2::geom_text(data = labdf,
                                ggplot2::aes(x = x, y = y, label = .label),
                                size = 2.4, colour = "grey10")
  }
  # legend title via labs() so callers can retitle with `+ labs(fill = )`
  if (!is.null(vals)) p <- p + ggplot2::labs(fill = z)
  if (!is.null(palette)) {                   # NULL = caller adds a scale
    p <- p + if (is.null(vals)) {
      ggplot2::scale_fill_viridis_d(option = palette)
    } else {
      ggplot2::scale_fill_viridis_c(option = palette)
    }
  }
  # fit the canvas to the content: left room sized by the longest
  # geoframe name (clip = "off" is the safety net for what still
  # overflows), hairline pads elsewhere, legend pulled in close
  pad_l <- (0.02 + 0.016 * max(nchar(gfs))) * span
  pad_y <- 0.02 * (yr[2] - yr[1])
  p +
    ggplot2::coord_sf(xlim = c(xr[1] - pad_l, xr[2] + 0.01 * span),
                      ylim = c(yr[1] - pad_y, yr[2] + pad_y),
                      expand = FALSE, clip = "off", datum = NA) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin = ggplot2::margin(4, 8, 4, 4),
      legend.box.spacing = ggplot2::unit(6, "pt")
    )
}
