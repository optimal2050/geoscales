# =============================================================================
# Plotting
# =============================================================================
# Ports the "by geoframe" idea from timescales: one row per geoframe, laid
# out on a shared cumulative-weight axis, so the nesting structure reads at
# a glance.
#
#   geoscale_layout(gs)        -> plain data.frame of rectangles (no ggplot2)
#   gg_geoscale(gs, type = )   -> the assembled figures: icicle (no geometry
#                                 needed), stack and map (geometry + sf)
#   autoplot(gs) / plot(gs)    -> methods over gg_geoscale(); autoplot()
#                                 returns the ggplot, plot() draws it
#
# ggplot2 is in Suggests, so its `autoplot` generic cannot be imported at
# build time; the S3 method is registered in `.onLoad()` (see zzz.R) only if
# ggplot2 is actually installed.
# =============================================================================

# Human-readable names for the regions of one geoframe.
#
# Read from the label table (see R/labels.R), in the default variant. Labels
# are declared per geoframe, so a geoframe with none is shown by its codes.
#
# Returns a named character vector (code -> label) covering the labelled
# codes, or NULL when the geoframe has no labels.
#' @noRd
.region_labels <- function(x, geoframe) {
  lb <- .label_table(x)
  lb <- lb[lb$frame == geoframe & !is.na(lb$unit) &
             lb$variant == .label_variant(x), , drop = FALSE]
  if (nrow(lb) == 0L) return(NULL)
  stats::setNames(lb$label, lb$unit)
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

#' Icicle layout for a GeoScale
#'
#' Rectangle coordinates for a geoframe-by-geoframe structure plot: one row per
#' geoframe, each region a rectangle whose width is its share of the weight.
#' Exposed so the layout can be drawn with something other than ggplot2.
#'
#' @param x A [`GeoScale`].
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

# -----------------------------------------------------------------------------
# gg_geoscale(): one entry point, `type` selects the figure
# -----------------------------------------------------------------------------

# Arguments each figure type accepts, besides `object`, `type` and `...`.
# Anything listed for another type only is refused, never ignored.
.GG_GEOSCALE_ARGS <- list(
  icicle = c("data", "z", "palette", "labels", "rule", "weight", "fill"),
  stack  = c("data", "z", "palette", "labels", "rule", "weight", "precision",
             "view", "angle", "ratio", "shear", "depth", "gap", "rotate",
             "direction", "colour", "linewidth", "frame", "frame_fill",
             "connectors", "outline", "outline_colour", "outline_linewidth"),
  map    = c("data", "z", "palette", "labels", "geoframe", "precision")
)

#' Refuse arguments that belong to another figure type
#'
#' `call` is the `match.call()` of the entry point: names passed through
#' the methods' `...` are expanded there, so the check sees them too.
#' Names outside the table are the entry point's own `...` (fixed
#' aesthetics for the drawing layer) and pass. Duplicated verbatim in
#' timescales/R/plot.R -- keep in sync.
#' @noRd
.gg_check_args <- function(call, type, table, fn) {
  given <- setdiff(names(call)[-1], c("", "object", "type"))
  known <- unique(unlist(table))
  bad <- setdiff(intersect(given, known), table[[type]])
  if (length(bad)) {
    .stop("`%s` does not apply to %s(type = \"%s\")",
          paste(bad, collapse = "`, `"), fn, type)
  }
}

#' The palette sentinels: `NULL` is the type's default scale, `NA` is none
#' @noRd
.gg_palette <- function(palette, type, default) {
  if (!is.null(palette)) return(palette)
  if (type %in% c("icicle", "stack")) default else NULL
}

#' @noRd
.has_palette <- function(palette) {
  !is.null(palette) && !(length(palette) == 1L && is.na(palette))
}

#' Add a layer with fixed aesthetics; the user's `...` override the defaults
#' @noRd
.gg_layer <- function(geom, mapping, defaults, dots, data = NULL) {
  names(dots)[names(dots) == "color"] <- "colour"
  args <- utils::modifyList(defaults, dots)
  if (!is.null(data)) args$data <- data
  do.call(geom, c(list(mapping = mapping), args))
}

#' Plot a GeoScale
#'
#' One function for every geoscale figure, selected by `type`: the structure
#' icicle (default; needs no geometry), the axonometric stack of map planes,
#' and a choropleth map of one geoframe. `autoplot()` on a [`GeoScale`]
#' returns the same ggplot; `plot()` draws it and returns it invisibly.
#'
#' @param object A [`GeoScale`]. The stack and the map need geometry
#'   attached with [`attach_geometry_geoscale()`] and the sf package.
#' @param type The figure: `"icicle"` (default), `"stack"` or `"map"`; see
#'   the sections below. An argument that belongs to another type is an
#'   error, not ignored.
#' @param data,z Colour the figure by a value instead of by structure.
#'   `data` is a data.frame with the value column named by `z`; `z` is
#'   required whenever `data` is given. The icicle and the stack take
#'   `data` keyed by the atom geoframe and recast the value up to every
#'   coarser geoframe (see `rule`), so the whole figure shares one
#'   continuous fill scale; the map takes `data` keyed by `geoframe`.
#'   Legend title via `labs(fill = )`.
#' @param rule Icicle and stack, with `data`: the rule that recasts `z`
#'   from the atoms to each coarser geoframe (`"weighted_mean"` default;
#'   see [`recast_geoscale()`]). `"share"` colours every band or plane by
#'   each region's share within the one above it on a fixed linear 0..1
#'   scale; `"logshare"` is the same on a fixed log10 percent scale.
#' @param weight Icicle and stack: the weight column. On the icicle it sets
#'   the rectangle widths; with `rule = "weighted_mean"` it is also the
#'   recast weight. `NULL` uses the geoscale's default weight.
#' @param palette Fill scale. `NULL` (default) is the type's own: viridis
#'   `"H"` on the icicle and the stack, ggplot2's default gradient on the
#'   map. A viridis option letter (`"A"`..`"H"`) opts into that palette on
#'   any type. `NA` adds no fill scale at all, so a custom one can be
#'   supplied, e.g. `energypal::scale_fill_energy_b()`.
#' @param labels What is labelled. `NULL` (default) is the type's own.
#'   Icicle: `TRUE` (default) draws the region names on the rectangles,
#'   `FALSE` none. Stack: a character vector of geoframes whose regions get
#'   their names on the plane (`TRUE` = all; default none). Map: `TRUE`
#'   draws the region names (default none). Names are the display names of
#'   the region's label where it has one (see [`geoscale_labels()`]), else
#'   the code.
#' @param fill Icicle: what to colour by without `data`, `"geoframe"`
#'   (default) or `"region"`.
#' @param geoframe Map: the geoframe to draw. Defaults to the atom geoframe.
#' @param precision Stack and map: GEOS precision for the dissolve,
#'   forwarded to [`geoscale_geometry()`]. Default `0` = off.
#' @param view Stack: a predefined point of view -- `"oblique"` (the
#'   shear/depth default), `"top-down"`, `"cavalier"`, `"cabinet"`,
#'   `"military"`, `"isometric"`, `"dimetric"`, `"trimetric"`,
#'   `"perspective"` (receding planes shrink) or `"pyramid"` (receding
#'   planes grow: the coarsest geoframe is the small top, the finest the
#'   wide base).
#' @param angle,ratio Stack: oblique view by angle (degrees of the receding
#'   axis) and foreshortening ratio -- `e2 = ratio * (cos(angle),
#'   sin(angle))`. Overridden by `view`.
#' @param shear,depth,gap Stack: raw receding-axis components
#'   (`e2 = (shear, depth)`; used when neither `view` nor `angle`/`ratio`
#'   is given) and the vertical spacing between planes: one value for every
#'   pair, or one per pair from the top down. `gap = NULL` (default) spaces
#'   planes almost touching, with a slight overlap. Under `"perspective"`
#'   and `"pyramid"` each spacing is scaled with the planes it separates,
#'   so it stays uniform relative to their size.
#' @param rotate Stack: in-plane rotation of each plane (degrees,
#'   counter-clockwise).
#' @param direction Stack: `"up"` (default) stacks the coarsest geoframe on
#'   top; `"down"` puts it at the bottom.
#' @param colour,linewidth Stack: region border colour and width, recycled
#'   across the planes (so `colour = c("white", "grey40", "white")` styles
#'   one plane per entry). Defaults `"grey35"` and `0.2`, ggplot2's own sf
#'   polygon border.
#' @param frame Stack: draw each plane's outline (the footprint box run
#'   through the same projection) as a guide; curved shapes are much easier
#'   to read in oblique views with the plane edges visible. `TRUE` uses
#'   `"grey80"`, a colour string uses that colour, `NULL` (default) draws
#'   no frames.
#' @param frame_fill Stack: fill for the plane sheets. Best mostly
#'   transparent, e.g. `frame_fill = ggplot2::alpha("grey60", 0.12)`; the
#'   panes then read as glass sheets. Setting a fill draws the frames even
#'   without `frame`; `NA` (default) = no fill.
#' @param connectors Stack: dashed lines joining the corresponding frame
#'   corners of adjacent planes, the vertical guides of the stack. `TRUE`
#'   uses the frame colour, a colour string picks its own; default `FALSE`.
#' @param outline Stack: coarser geoframe(s) whose borders are drawn over
#'   every finer plane, so the groups they form are visible at the finer
#'   resolution (`outline = "zone"` marks the zones on the region plane).
#'   `NULL` (default) = none.
#' @param outline_colour,outline_linewidth Stack: colour and width of the
#'   `outline` borders, recycled over `outline`. Defaults `"grey20"` and
#'   `0.6`.
#' @param ... Fixed aesthetics for the figure's main layer: the icicle's
#'   `geom_rect()`, the stack's and the map's `geom_sf()` (e.g.
#'   `alpha = 0.8`).
#' @param x A [`GeoScale`] (for `plot()`).
#'
#' @section Icicle (`type = "icicle"`):
#' One row per geoframe, coarsest at the top, each region a rectangle whose
#' width is its share of `weight`. Shows the GeoScale itself and needs no
#' geometry. With `data`, each band's rectangles carry the value recast to
#' that geoframe.
#'
#' @section Stack (`type = "stack"`):
#' One sheared map plane per geoframe, coarsest on top: the same atoms
#' dissolved at each resolution, under a chosen point of view. Without
#' `data`, regions are coloured by their ancestor at the coarsest geoframe
#' with two or more regions, so each child carries its parent's colour down
#' the stack; a single-region geoframe above it is drawn in neutral grey.
#'
#' @section Map (`type = "map"`):
#' A choropleth of one geoframe. Without `data`, the region outlines are
#' drawn. Callers that know what their numbers mean (which variable,
#' extensive or intensive, what units) prepare a `data.frame` keyed by
#' `geoframe` and hand it here rather than draw their own `geom_sf()`.
#'
#' @section Methods:
#' `autoplot(object, ...)` is `gg_geoscale(object, ...)`. `plot(x, ...)`
#' prints that figure and returns it invisibly, like base `plot()`.
#'
#' @return A ggplot object.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   gs <- geoscale_example()
#'   gg_geoscale(gs)
#'   ggplot2::autoplot(gs)                           # the same figure
#' }
#' if (requireNamespace("ggplot2", quietly = TRUE) &&
#'     requireNamespace("sf", quietly = TRUE)) {
#'   # the stack and the map need geometry: one unit square per atom
#'   gs <- geoscale_example()
#'   n <- length(geoscale_regions(gs, "atom"))
#'   square <- function(i) {
#'     sf::st_polygon(list(cbind(c(i, i + 1, i + 1, i, i), c(0, 0, 1, 1, 0))))
#'   }
#'   geom <- do.call(sf::st_sfc, lapply(seq_len(n) - 1, square))
#'   gs <- attach_geometry_geoscale(gs, geom)
#'   gg_geoscale(gs, type = "map", geoframe = "state")
#'   gg_geoscale(gs, type = "stack", view = "cabinet")
#' }
#' @export
gg_geoscale <- function(object,
                        type = c("icicle", "stack", "map"),
                        data = NULL, z = NULL,
                        rule = "weighted_mean", weight = NULL,
                        palette = NULL, labels = NULL,
                        fill = c("geoframe", "region"),
                        geoframe = NULL,
                        precision = 0,
                        view = NULL, angle = NULL, ratio = NULL,
                        shear = 0.45, depth = 0.55, gap = NULL,
                        rotate = 0, direction = c("up", "down"),
                        colour = "grey35", linewidth = 0.2,
                        frame = NULL, frame_fill = NA, connectors = FALSE,
                        outline = NULL, outline_colour = "grey20",
                        outline_linewidth = 0.6,
                        ...) {
  .check_geoscale(object)
  .need_ggplot("gg_geoscale()")
  type <- match.arg(type)
  .gg_check_args(match.call(), type, .GG_GEOSCALE_ARGS, "gg_geoscale")
  if (!is.null(data) && is.null(z)) {
    .stop("`z` must name the value column of `data`")
  }
  palette <- .gg_palette(palette, type, default = "H")
  switch(type,
    icicle = .gg_geoscale_icicle(
      object, data = data, z = z, rule = rule, weight = weight,
      palette = palette, labels = labels, fill = fill, ...),
    stack = .gg_geoscale_stack(
      object, view = view, angle = angle, ratio = ratio, shear = shear,
      depth = depth, gap = gap, rotate = rotate, direction = direction,
      precision = precision, data = data, z = z, rule = rule,
      weight = weight, labels = labels, palette = palette,
      colour = colour, linewidth = linewidth, frame = frame,
      frame_fill = frame_fill, connectors = connectors, outline = outline,
      outline_colour = outline_colour,
      outline_linewidth = outline_linewidth, ...),
    map = .gg_geoscale_map(
      object, data = data, z = z, geoframe = geoframe, palette = palette,
      labels = labels, precision = precision, ...)
  )
}

#' The structure icicle (type = "icicle")
#' @noRd
.gg_geoscale_icicle <- function(object, data = NULL, z = NULL,
                                rule = "weighted_mean", weight = NULL,
                                palette = "H", labels = NULL,
                                fill = c("geoframe", "region"), ...) {
  fill <- match.arg(fill)
  draw_labels <- is.null(labels) || isTRUE(labels)
  dots <- list(...)
  d <- geoscale_layout(object, weight = weight)
  lv <- S7::prop(object, "geoframes")
  nm <- S7::prop(object, "meta")$name
  vals <- NULL
  if (!is.null(data)) {
    # data fill: each band's rectangles carry the value recast to that
    # geoframe (widths still encode weight shares); overrides `fill`
    vals <- .geoscale_frame_values(object, lv, data, z, rule, weight)
    d$.fill <- NA_real_
    for (gf in lv) {
      i <- d$geoframe == gf
      d$.fill[i] <- vals[[gf]][[z]][match(d$region[i], vals[[gf]][[gf]])]
    }
  } else {
    d$.fill <- d[[fill]]
  }

  # Display names are resolved per geoframe (each geoframe has its own lookup)
  # but written back in place, so row order stays aligned with the rectangles.
  d$.label <- d$region
  for (l in unique(d$geoframe)) {
    i <- d$geoframe == l
    d$.label[i] <- .apply_labels(d$region[i], .region_labels(object, l))
  }

  p <- ggplot2::ggplot(d) +
    .gg_layer(ggplot2::geom_rect,
              ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin,
                           ymax = ymax, fill = .fill),
              list(colour = "white", linewidth = 0.3), dots) +
    ggplot2::scale_y_continuous(breaks = rev(seq_along(lv)) - 0.55,
                                labels = lv) +
    ggplot2::labs(x = "share of weight", y = NULL, fill = fill,
                  title = if (!is.null(nm) && nzchar(nm)) nm else NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

  if (!is.null(vals)) {
    # continuous value fill: viridis + a retitle-able legend, and label
    # colours that keep contrast on dark cells
    is_share <- any(rule %in% c("share", "logshare"))
    if (.has_palette(palette)) {               # NA = caller adds a scale
      p <- p + if (is_share) {
        .share_fill_scale(palette, log = any(rule %in% "logshare"))
      } else {
        ggplot2::scale_fill_viridis_c(option = palette)
      }
    }
    p <- p + ggplot2::labs(fill = if (is_share) "Share" else z)
  }
  if (draw_labels) {
    # check_overlap keeps the first label drawn, so order widest-first --
    # narrow rectangles lose their label rather than smear the band
    td <- d[order(d$xmax - d$xmin, decreasing = TRUE), ]
    lab_col <- "grey10"
    if (!is.null(vals)) {
      rng <- range(td$.fill, finite = TRUE)
      f01 <- if (diff(rng) > 0) (td$.fill - rng[1]) / diff(rng) else 0.5
      f01[!is.finite(f01)] <- 0
      lab_col <- ifelse(f01 < 0.5, "white", "grey15")
    }
    p <- p + ggplot2::geom_text(
      data = td,
      ggplot2::aes(x = (xmin + xmax) / 2, y = (ymin + ymax) / 2,
                   label = .label),
      size = 2.8, colour = lab_col, check_overlap = TRUE
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
  if (any(rule %in% c("share", "logshare"))) {
    return(.geoscale_frame_shares(x, gfs, data, z))
  }
  vals <- lapply(gfs, function(gf) {
    if (gf == atom_gf) return(data[, c(atom_gf, z)])
    recast_geoscale(data[, c(atom_gf, z)], x,
                    source = atom_gf, target = gf,
                    values = z, rule = rule, weight = weight)
  })
  stats::setNames(vals, gfs)
}

#' Fill scale for a share fill. A share's magnitude scales with how many
#' siblings divide the parent, which varies by orders of magnitude across
#' the planes, so a linear 0..1 scale flattens the crowded ones to black;
#' log10 spreads the decades. A zero share falls outside the transform
#' and takes the na colour -- visually "nothing here", which it is.
#' Callers override with `palette = NULL` plus their own scale.
#' @noRd
.share_fill_scale <- function(palette, log = FALSE) {
  # FIXED limits either way: any two share figures map colour
  # identically, so they compare across variables and renders. "share"
  # is the plain 0..1 scale; "logshare" spreads the decades (below-limit
  # values squish to the darkest colour rather than vanishing; only true
  # zeros, outside the log transform entirely, take the na colour).
  if (!log) {
    return(ggplot2::scale_fill_viridis_c(
      option = palette, limits = c(0, 1),
      breaks = c(0, 0.25, 0.5, 0.75, 1),
      na.value = "grey85"))
  }
  ggplot2::scale_fill_viridis_c(
    option = palette, transform = "log10",
    limits = c(1e-4, 1),
    oob = scales::oob_squish,
    breaks = c(1e-4, 1e-3, 1e-2, 1e-1, 1),
    labels = c("0.01%", "0.1%", "1%", "10%", "100%"),
    na.value = "grey85")
}

#' Does every region of `source` fall inside exactly one region of `target`?
#' Cross-cutting geoframes (IDEEA's reg35/reg32) fail this.
#' @noRd
.geo_nests <- function(gs, from, to) {
  map <- geoscale_map(gs, from, to)
  mem <- unique(map[, c(from, to)])
  n_par <- table(mem[[from]][!is.na(mem[[to]])])
  all(n_par <= 1L)
}

#' The share fill: every plane shows each region's share within the
#' nearest coarser plane it NESTS in -- normally the plane directly above
#' it; a cross-cutting plane climbs further, and the coarsest plane (or
#' one nesting in nothing above it) is normalised by the grand total. So
#' the whole figure reads on one 0..1 scale. Values sum-aggregate from
#' the atoms to each plane first; `weight` plays no part, as in the rule.
#' @noRd
.geoscale_frame_shares <- function(x, gfs, data, z) {
  atom_gf <- gfs[length(gfs)]
  vals <- lapply(seq_along(gfs), function(i) {
    gf <- gfs[[i]]
    s <- if (gf == atom_gf) {
      data[, c(atom_gf, z)]
    } else {
      recast_geoscale(data[, c(atom_gf, z)], x, source = atom_gf, target = gf,
                      values = z, rule = "sum")
    }
    for (j in rev(seq_len(i - 1L))) {
      if (.geo_nests(x, gf, gfs[[j]])) {
        return(recast_geoscale(s, x, source = gf, target = gfs[[j]],
                               values = z, rule = "share"))
      }
    }
    tot <- sum(s[[z]], na.rm = TRUE)
    s[[z]] <- if (tot != 0) s[[z]] / tot else NA_real_
    s
  })
  stats::setNames(vals, gfs)
}

# -----------------------------------------------------------------------------
# Methods: autoplot() returns the figure, plot() draws it
# -----------------------------------------------------------------------------

#' @rdname gg_geoscale
#' @exportS3Method ggplot2::autoplot
autoplot.GeoScale <- function(object, ...) {
  gg_geoscale(object, ...)
}

#' @rdname geoscale_leaftable
#' @exportS3Method ggplot2::fortify
fortify.GeoScale <- function(model, data, ...) {
  geoscale_leaftable(model)
}

#' @rdname gg_geoscale
#' @export
#' @method plot GeoScale
plot.GeoScale <- function(x, ...) {
  print(gg_geoscale(x, ...))
}

# Alias on the fully-qualified S7 class name: `class()` reports
# `geoscales::GeoScale` first (see the `[.GeoScale` note in R/filter.R),
# and that is the registration that actually dispatches when installed.
#' @export
`plot.geoscales::GeoScale` <- plot.GeoScale

#' The choropleth (type = "map" of gg_geoscale())
#'
#' Draws `data[[z]]` over the geometry of `geoframe`, dissolved from the
#' atoms; without `data`, the region outlines. Needs sf and attached
#' geometry.
#' @noRd
# Qualitative fills for a DISCRETE map (region membership, categories), in
# fixed order. A choropleth is read all-pairs -- any two polygons can be
# compared anywhere on the map -- so the set is held to the all-pairs floors,
# not the adjacent-pair ones a bar chart uses. Measured on the light surface:
#   3-5 slots  worst CVD dE 11.0, normal-vision 15.6  -- clean
#   6 slots    worst CVD dE  7.6                      -- inside the 6-8 band,
#              which needs secondary encoding; the white polygon borders and
#              `labels = TRUE` supply it
#   7+         no qualitative set clears the floors, so magnitude ordering via
#              a discrete viridis is the honest fallback
# Hues are Okabe-Ito, minus its yellow (outside the lightness band) and black.
.GEO_CAT_FILLS <- c("#E69F00", "#56B4E9", "#009E73",
                    "#0072B2", "#D55E00", "#CC79A7")

#' @noRd
.geo_cat_fills <- function(n) {
  if (n > length(.GEO_CAT_FILLS)) return(NULL)
  .GEO_CAT_FILLS[seq_len(n)]
}

.gg_geoscale_map <- function(object, data = NULL, z = NULL, geoframe = NULL,
                             palette = NULL, labels = NULL, precision = 0,
                             ...) {
  .need_sf("gg_geoscale(type = \"map\")")
  dots <- list(...)
  lv <- S7::prop(object, "geoframes")
  geoframe <- geoframe %||% lv[length(lv)]

  shp <- geoscale_geometry(object, geoframe = geoframe, precision = precision)
  if (!is.null(data)) {
    if (!geoframe %in% names(data)) .stop("`data` has no column `%s`", geoframe)
    if (!z %in% names(data)) .stop("`z` must name a column of `data`")
    shp <- merge(shp, data[, c(geoframe, z)], by = geoframe, all.x = TRUE)
    shp$.fill <- shp[[z]]
  }

  p <- ggplot2::ggplot(shp)
  p <- if (is.null(data)) {
    p + .gg_layer(ggplot2::geom_sf, NULL,
                  list(fill = "grey92", colour = "white"), dots)
  } else {
    p + .gg_layer(ggplot2::geom_sf, ggplot2::aes(fill = .fill),
                  list(colour = "white"), dots) +
      ggplot2::labs(fill = z)
  }

  if (!is.null(data)) {
    # A categorical fill cannot use `scale_fill_viridis_c()`; without a
    # discrete scale it silently fell through to ggplot's hue_pal(), which
    # put neighbouring hues on unrelated regions.
    if (is.numeric(shp$.fill)) {
      if (.has_palette(palette)) {
        p <- p + ggplot2::scale_fill_viridis_c(option = palette)
      }
    } else {
      nlev <- length(unique(stats::na.omit(as.character(shp$.fill))))
      cat_fills <- if (.has_palette(palette)) NULL else .geo_cat_fills(nlev)
      p <- p + if (!is.null(cat_fills)) {
        ggplot2::scale_fill_manual(values = cat_fills, na.value = "grey85")
      } else {
        ggplot2::scale_fill_viridis_d(
          option = if (.has_palette(palette)) palette else "D",
          end = 0.9, na.value = "grey85")
      }
    }
  }
  if (isTRUE(labels)) {
    shp$.label <- .apply_labels(shp[[geoframe]],
                                .region_labels(object, geoframe))
    p <- p + ggplot2::geom_sf_text(
      data = shp, ggplot2::aes(label = .label), size = 2.8, colour = "grey20"
    )
  }
  p + ggplot2::theme_minimal()
}

# Columns referenced inside `aes()` by bare name.
utils::globalVariables(c("xmin", "xmax", "ymin", "ymax", ".fill", "region",
                         ".grp",
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
                              "dimetric", "trimetric", "perspective",
                              "pyramid"))
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
                           scale = 0.82),
      # the inverse of perspective: each plane below the top is larger
      "pyramid"     = list(e1 = c(1, 0),
                           e2 = 0.5 * c(cos(45 * deg), sin(45 * deg)),
                           scale = 1 / 0.82)
    ))
  }
  if (!is.null(angle) || !is.null(ratio)) {
    a <- (angle %||% 45) * deg
    return(list(e1 = c(1, 0), e2 = (ratio %||% 0.5) * c(cos(a), sin(a)),
                scale = 1))
  }
  list(e1 = c(1, 0), e2 = c(shear, depth), scale = 1)
}

#' The axonometric stack (type = "stack" of gg_geoscale())
#'
#' One plane per geoframe, coarsest on top: the same atoms, dissolved at
#' each resolution. Footprints are normalized to a unit box, mapped
#' through the view axes (rows of the affine matrix are the screen
#' images of the in-plane axes), optionally shrunk per layer
#' (perspective), and lifted; painter order is bottom (finest) first, so
#' planes may overlap when `gap` is small.
#' @noRd
.gg_geoscale_stack <- function(x, view = NULL, angle = NULL,
                               ratio = NULL, shear = 0.45,
                               depth = 0.55, gap = NULL,
                               rotate = 0,
                               direction = c("up", "down"),
                               precision = 0,
                               data = NULL, z = NULL,
                               rule = "weighted_mean",
                               weight = NULL,
                               labels = NULL, palette = "H",
                               colour = "grey35", linewidth = 0.2,
                               frame = NULL, frame_fill = NA,
                               connectors = FALSE,
                               outline = NULL, outline_colour = "grey20",
                               outline_linewidth = 0.6, ...) {
  .need_sf("gg_geoscale(type = \"stack\")")
  dots <- list(...)
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
  # `labels`: TRUE = every plane, FALSE/NULL = none, else geoframes
  if (isTRUE(labels)) labels <- gfs
  if (isFALSE(labels)) labels <- NULL
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

  # normalise `g` to the unit box of `ref` (default: its own box), so an
  # overlay drawn on a plane shares that plane's frame of reference
  norm_by <- function(g, ref = g) {
    bb <- sf::st_bbox(ref)
    (g - c(bb[["xmin"]], bb[["ymin"]])) /
      max(bb[["xmax"]] - bb[["xmin"]], bb[["ymax"]] - bb[["ymin"]])
  }
  norm01 <- function(g) norm_by(g)

  shapes <- lapply(gfs, function(gf) {
    geoscale_geometry(x, gf, precision = precision)
  })
  planes <- lapply(shapes, function(shp) norm01(sf::st_geometry(shp)) * M)

  # default spacing: planes almost touching, slight overlap -- derived
  # from the ACTUAL screen height of the transformed footprint
  bb1 <- sf::st_bbox(planes[[length(planes)]])
  gap <- gap %||% (0.85 * (bb1[["ymax"]] - bb1[["ymin"]]))

  nk <- length(gfs)
  top_rank <- if (direction == "up") seq_len(nk) - 1 else nk - seq_len(nk)
  # per-plane size factor. A factor below 1 shrinks the planes below the
  # top (perspective); a factor above 1 is applied from the bottom up, so
  # the largest plane is always full size and pyramid mirrors perspective.
  fac <- if (v$scale < 1) v$scale^top_rank
         else (1 / v$scale)^(nk - 1 - top_rank)
  # vertical placement: `gap` is the spacing between consecutive planes,
  # top to bottom, one value for all or one per pair. Each step scales with
  # the larger of the two planes it separates, so spacing stays uniform
  # relative to plane size and pyramid mirrors perspective exactly.
  if (!length(gap) %in% c(1L, nk - 1L)) {
    .stop("`gap` must be a single value or one per pair of planes (%d)",
          nk - 1L)
  }
  pos <- if (direction == "up") seq_len(nk) else rev(seq_len(nk))  # 1 = top
  fac_tb <- fac[order(pos)]  # top to bottom
  steps <- rep_len(gap, nk - 1L) * pmax(fac_tb[-nk], fac_tb[-1L])
  zlev <- vapply(pos, function(p) sum(steps[seq_len(nk - 1L) >= p]),
                 numeric(1))
  # Fill by the ancestor at the KEY frame, not by `code`: one fill scale is
  # shared by every plane, so mapping `code` spreads all frames' codes over
  # one ramp and alphabetical neighbours land on neighbouring colours
  # (NORTH and NORTHEAST came out the same yellow). Keying on one frame also
  # makes the roll-up visible: a child carries its parent's colour down the
  # stack. The key frame is the coarsest with two or more regions; a
  # single-region frame above it (a nation over its zones) separates
  # nothing and is left neutral.
  n_reg <- vapply(seq_along(gfs), function(k) {
    length(unique(stats::na.omit(as.character(shapes[[k]][[gfs[k]]]))))
  }, integer(1))
  kk <- which(n_reg >= 2L)[1L]
  if (is.na(kk)) kk <- 1L
  layers <- lapply(seq_along(gfs), function(k) {
    sk <- fac[k]
    g <- (planes[[k]] - ctr) * sk + ctr + c(0, zlev[k])
    d <- sf::st_sf(code = shapes[[k]][[gfs[k]]], gf = gfs[k], geometry = g)
    d$.grp <- if (k < kk) NA_character_ else if (k == kk) {
      as.character(d$code)
    } else {
      m <- geoscale_map(x, gfs[kk], gfs[k])
      as.character(m[[gfs[kk]]][match(as.character(d$code),
                                       as.character(m[[gfs[k]]]))])
    }
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
      q <- sweep(sweep(cn, 2, ctr) * fac[k], 2, ctr, `+`)
      data.frame(x = q[, 1], y = q[, 2] + zlev[k])
    })
  }

  # coarser-geoframe borders over the finer planes: the atoms dissolved
  # at each `outline` geoframe, run through the plane's own transform.
  # A plane shows only the outlines of geoframes coarser than its own.
  outlines <- vector("list", nk)
  if (!is.null(outline)) {
    bad <- setdiff(outline, gfs)
    if (length(bad)) {
      .stop("`outline` must name geoframes of the geoscale (unknown: %s)",
            paste(bad, collapse = ", "))
    }
    o_shapes <- lapply(outline, function(o) {
      sf::st_geometry(geoscale_geometry(x, o, precision = precision))
    })
    o_col <- rep_len(outline_colour, length(outline))
    o_lwd <- rep_len(outline_linewidth, length(outline))
    for (k in seq_len(nk)) {
      coarser <- which(match(outline, gfs) < k)
      outlines[[k]] <- lapply(coarser, function(i) {
        g <- norm_by(o_shapes[[i]], sf::st_geometry(shapes[[k]])) * M
        list(geometry = (g - ctr) * fac[k] + ctr + c(0, zlev[k]),
             colour = o_col[i], linewidth = o_lwd[i])
      })
    }
  }

  xr <- range(vapply(layers, function(l) {
    sf::st_bbox(l)[c("xmin", "xmax")]
  }, numeric(2)))
  yr <- range(vapply(layers, function(l) {
    sf::st_bbox(l)[c("ymin", "ymax")]
  }, numeric(2)))
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
      p + .gg_layer(ggplot2::geom_sf, ggplot2::aes(fill = .grp),
                    list(colour = col_k[k], linewidth = lwd_k[k],
                         show.legend = FALSE),
                    dots, data = layers[[k]])
    } else {
      p + .gg_layer(ggplot2::geom_sf, ggplot2::aes(fill = .z),
                    list(colour = col_k[k], linewidth = lwd_k[k]),
                    dots, data = layers[[k]])
    }
    for (o in outlines[[k]]) {                 # group borders on top
      p <- p + ggplot2::geom_sf(data = sf::st_sf(geometry = o$geometry),
                                fill = NA, colour = o$colour,
                                linewidth = o$linewidth,
                                inherit.aes = FALSE)
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
  if (!is.null(vals)) {
    p <- p + ggplot2::labs(
      fill = if (any(rule %in% c("share", "logshare"))) "Share" else z)
  }
  if (.has_palette(palette)) {               # NA = caller adds a scale
    p <- p + if (is.null(vals)) {
      # grouping codes, not magnitudes: use the validated categorical order
      # while it covers them, and only fall back to the ramp beyond it.
      ngrp <- length(unique(stats::na.omit(
        unlist(lapply(layers, function(d) as.character(d$.grp))))))
      gfill <- .geo_cat_fills(ngrp)
      if (!is.null(gfill)) {
        ggplot2::scale_fill_manual(values = gfill, na.value = "grey85")
      } else {
        ggplot2::scale_fill_viridis_d(option = palette, na.value = "grey85")
      }
    } else if (any(rule %in% c("share", "logshare"))) {
      .share_fill_scale(palette, log = any(rule %in% "logshare"))
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
