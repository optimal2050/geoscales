# geom_geoscale() / theme_geoscale() / gg_geoscale() ----------------------------

.toy_gs <- function() {
  skip_if_not_installed("sf")
  lf <- data.frame(top = c("T", "T"), cell = c("a", "b"),
                   km2 = c(1, 3))
  gs <- geoscale_from_leaftable(lf, geoframes = c("top", "cell"),
                                name = "toy")
  geom <- sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1),
                              c(0, 0)))),
    sf::st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 1),
                              c(1, 0)))),
    crs = 4326)
  attach_geometry_geoscale(gs, geom)
}

test_that("geom_geoscale returns one sf layer with aggregated values", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  x <- data.frame(cell = c("a", "a", "b"), v = c(1, 3, 10))
  lyr <- geom_geoscale(gs = gs, z = "v", data = x, fun = mean)
  # geom_sf() returns its layer plus a CoordSf; the layer is first
  expect_s3_class(lyr[[1]], "LayerSf")

  p <- ggplot2::ggplot(x) +
    geom_geoscale(gs = gs, z = "v") +
    theme_geoscale()
  expect_s3_class(p, "ggplot")
  d <- ggplot2::layer_data(p, 1)
  expect_equal(sort(d$fill != d$fill[1]), sort(c(FALSE, TRUE)))
  # aggregated values: a -> 2, b -> 10, joined in dissolve order
  built <- lyr[[1]]$data
  expect_equal(built$value[built$cell == "a"], 2)
  expect_equal(built$value[built$cell == "b"], 10)
})

test_that("geom_geoscale infers the geoframe and coarser frames dissolve", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  x <- data.frame(top = "T", v = 5)
  lyr <- geom_geoscale(gs = gs, z = "v", data = x)   # infers `top`
  expect_equal(nrow(lyr[[1]]$data), 1L)
  expect_equal(lyr[[1]]$data$value, 5)

  # z = NULL draws plain boundaries at the leaf geoframe
  lyr0 <- geom_geoscale(gs = gs)
  expect_s3_class(lyr0[[1]], "LayerSf")
  expect_equal(nrow(lyr0[[1]]$data), 2L)
})

test_that("geom_geoscale validates its inputs", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  gs_nogeom <- geoscale_example()
  expect_error(geom_geoscale(gs = gs_nogeom, z = "v",
                             data = data.frame(cell = "A1", v = 1)),
               "no geometry")
  gs <- .toy_gs()
  expect_error(geom_geoscale(gs = gs, z = "v",
                             data = data.frame(nope = 1, v = 1)),
               "cannot infer")
})

test_that("theme_geoscale returns a theme with a solid background", {
  skip_if_not_installed("ggplot2")
  th <- theme_geoscale()
  expect_s3_class(th, "theme")
  expect_equal(th$plot.background$fill, "white")
  expect_s3_class(th$axis.text, "element_blank")
})

test_that("autoplot() returns the figure; plot() draws it", {
  skip_if_not_installed("ggplot2")
  gs <- geoscale_example()
  expect_s3_class(ggplot2::autoplot(gs), "ggplot")
  # autoplot() forwards every argument
  a <- ggplot2::ggplot_build(ggplot2::autoplot(gs, labels = FALSE))$data
  b <- ggplot2::ggplot_build(gg_geoscale(gs, labels = FALSE))$data
  expect_identical(a, b)
  # plot() prints and returns the figure invisibly
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  r <- withVisible(plot(gs))
  expect_false(r$visible)
  expect_s3_class(r$value, "ggplot")
})

test_that("gg_geoscale refuses arguments of another type and needs z", {
  skip_if_not_installed("ggplot2")
  gs <- geoscale_example()
  expect_error(gg_geoscale(gs, type = "map", view = "cabinet"),
               "does not apply")
  expect_error(gg_geoscale(gs, geoframe = "state"), "does not apply")
  expect_error(gg_geoscale(gs, data = data.frame(cell = "a", v = 1)), "`z`")
})

test_that("the stack view draws one plane per geoframe", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  p <- gg_geoscale(gs, type = "stack")
  expect_s3_class(p, "ggplot")
  expect_error(gg_geoscale(geoscale_example(), type = "stack"),
               "needs attached geometry")
})

test_that("precision snapping merges eps-jittered boundaries", {
  skip_if_not_installed("sf")
  eps <- 1e-13
  sq <- function(x0) {
    sf::st_polygon(list(cbind(c(x0, x0 + 1, x0 + 1, x0, x0),
                              c(0, 0, 1, 1, 0))))
  }
  lf <- data.frame(top = c("T", "T"), cell = c("a", "b"), w = c(1, 1))
  gs <- geoscale_from_leaftable(lf, geoframes = c("top", "cell"),
                                name = "jit") |>
    attach_geometry_geoscale(sf::st_sfc(sq(0), sq(1 + eps)))
  # jittered: the union keeps two parts
  parts0 <- length(sf::st_cast(
    sf::st_geometry(geoscale_geometry(gs, "top")), "POLYGON"))
  expect_equal(parts0, 2L)
  # precision snapping heals it
  parts1 <- length(sf::st_cast(
    sf::st_geometry(geoscale_geometry(gs, "top", precision = 1e6)),
    "POLYGON"))
  expect_equal(parts1, 1L)
})

test_that("dissolve collapses multi-part unions to one geometry per code", {
  skip_if_not_installed("sf")
  gs <- .toy_gs()
  real_union <- sf::st_union
  # simulate s2 misbehaving on an invalid polygon: union returns 2 parts
  testthat::local_mocked_bindings(
    st_union = function(x, ...) {
      u <- real_union(x, ...)
      if (length(u) == 1L) c(u, u) else u
    },
    .package = "sf"
  )
  g <- geoscale_geometry(gs, "top")
  expect_equal(nrow(g), 1L)   # one code -> one geometry, still
})

test_that("stack views, rotation and direction all render", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  for (vw in c("top-down", "cabinet", "military", "isometric",
               "perspective", "pyramid")) {
    expect_s3_class(gg_geoscale(gs, type = "stack", view = vw),
                    "ggplot")
  }
  # pyramid inverts perspective: same axes, reciprocal per-plane factor
  expect_equal(geoscales:::.stack_view("pyramid")$scale,
               1 / geoscales:::.stack_view("perspective")$scale)
  expect_s3_class(gg_geoscale(gs, type = "stack", angle = 30,
                                    ratio = 0.4), "ggplot")
  expect_s3_class(gg_geoscale(gs, type = "stack", rotate = 45,
                                    direction = "down"), "ggplot")
  expect_error(gg_geoscale(gs, type = "stack", view = "nope"))
  # one gap per pair of planes, top to bottom
  nk <- length(geoscale_geoframes(gs))
  expect_s3_class(gg_geoscale(gs, type = "stack",
                                    gap = seq(0.2, 0.4, length.out = nk - 1)),
                  "ggplot")
  expect_error(gg_geoscale(gs, type = "stack", gap = rep(0.3, nk + 1)),
               "one per pair")
  # coarser borders overlaid on the finer plane: one more sf layer
  p0 <- gg_geoscale(gs, type = "stack")
  p1 <- gg_geoscale(gs, type = "stack", outline = "top",
                          outline_linewidth = 1)
  expect_equal(length(p1$layers), length(p0$layers) + 1L)
  expect_error(gg_geoscale(gs, type = "stack", outline = "nope"),
               "unknown")
})

test_that("stack value fill recasts leaf data onto every plane", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  x <- data.frame(cell = c("a", "b"), v = c(1, 9))
  p <- gg_geoscale(gs, type = "stack", data = x, z = "v")
  expect_s3_class(p, "ggplot")
  # painter order is ascending z: with direction = "up" the leaf plane
  # (bottom) draws first and keeps its values; the top geoframe gets the
  # area-weighted mean (1*1 + 9*3) / 4 = 7
  d_leaf <- ggplot2::layer_data(p, 1)
  d_top  <- ggplot2::layer_data(p, 2)
  fills  <- ggplot2::ggplot_build(p)$plot$layers
  z_leaf <- fills[[1]]$data$.z
  z_top  <- fills[[2]]$data$.z
  expect_equal(sort(z_leaf), c(1, 9))
  expect_equal(z_top, 7)
  expect_equal(nrow(d_top), 1L)
  expect_equal(nrow(d_leaf), 2L)

  expect_error(gg_geoscale(gs, type = "stack", data = x),
               "`z` must name")
  # data keyed above the leaves fills its own plane and leaves the finer
  # one outlined, without a fill
  pc <- gg_geoscale(gs, type = "stack", z = "v",
                    data = data.frame(top = "T", v = 4))
  sf_l <- Filter(function(l) inherits(l$geom, "GeomSf"), pc$layers)
  has_z <- vapply(sf_l, function(l) ".z" %in% names(l$data), logical(1))
  expect_equal(sum(has_z), 1L)
  expect_equal(sf_l[[which(has_z)]]$data$.z, 4)
  expect_true(is.na(sf_l[[which(!has_z)]]$aes_params$fill))
  expect_error(gg_geoscale(gs, type = "stack", z = "v",
                           data = data.frame(nope = "T", v = 1)),
               "keyed by a geoframe")
})

test_that("stack frames, connectors and border styling render", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  base_n <- length(ggplot2::ggplot_build(
    gg_geoscale(gs, type = "stack"))$plot$layers)
  # frame = one polygon per plane; connectors = one segment layer
  p <- gg_geoscale(gs, type = "stack", frame = TRUE,
                         connectors = TRUE)
  expect_equal(length(ggplot2::ggplot_build(p)$plot$layers),
               base_n + 2 + 1)
  # custom border colours, one per plane, land on the sf layers
  p2 <- gg_geoscale(gs, type = "stack",
                          colour = c("grey20", "red"), linewidth = 0.1)
  cols <- unlist(lapply(p2$layers, function(l) {
    if (inherits(l$geom, "GeomSf")) l$aes_params$colour
  }))
  expect_setequal(cols, c("grey20", "red"))
  # a colour string picks the frame colour directly
  p3 <- gg_geoscale(gs, type = "stack", frame = "steelblue")
  expect_s3_class(p3, "ggplot")
  # frame_fill alone activates the sheets (edge NA, filled panes)
  p4 <- gg_geoscale(gs, type = "stack", frame_fill = "#6FA8DC26")
  expect_equal(length(ggplot2::ggplot_build(p4)$plot$layers), base_n + 2)
})

test_that("stack labels draw region names of the chosen geoframes", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  p <- gg_geoscale(gs, type = "stack", labels = "cell")
  lyrs <- ggplot2::ggplot_build(p)$plot$layers
  txt <- lyrs[[length(lyrs)]]$data
  expect_setequal(txt$.label, c("a", "b"))
  expect_error(gg_geoscale(gs, type = "stack", labels = "nope"),
               "unknown")
})

test_that("icicle data fill recasts values onto every band", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  x <- data.frame(cell = c("a", "b"), v = c(1, 9))
  p <- gg_geoscale(gs, data = x, z = "v", labels = TRUE)
  expect_s3_class(p, "ggplot")
  d <- p$data
  # leaf band keeps values; top band = km2-weighted mean (1*1+9*3)/4 = 7
  expect_equal(sort(d$.fill[d$geoframe == "cell"]), c(1, 9))
  expect_equal(d$.fill[d$geoframe == "top"], 7)
  # data keyed above the leaves: its band is filled, the finer one is not
  pc <- gg_geoscale(gs, data = data.frame(top = "T", v = 4), z = "v")
  dc <- pc$data
  expect_equal(dc$.fill[dc$geoframe == "top"], 4)
  expect_true(all(is.na(dc$.fill[dc$geoframe == "cell"])))
  expect_false(any(dc$.valued[dc$geoframe == "cell"]))
  expect_error(gg_geoscale(gs, data = data.frame(nope = "T", v = 1),
                           z = "v"),
               "keyed by a geoframe")
})

test_that("geom_geoscale carries finer codes up to the drawn geoframe", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  # leaf codes in a column named `region`, drawn one geoframe up
  x <- data.frame(region = c("a", "b"), v = c(2, 5))
  lyr <- geom_geoscale(gs = gs, z = "v", data = x, geoframe = "top", fun = sum)
  expect_equal(lyr[[1]]$data$value, 7)
  # and at their own geoframe, found through the `region` column
  lyr <- geom_geoscale(gs = gs, z = "v", data = x, geoframe = "cell")
  expect_equal(lyr[[1]]$data$value, c(2, 5))
})

test_that("a single-region top plane of the stack is filled from the palette", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()                       # top (1 region) over cell (2)
  b <- ggplot2::ggplot_build(gg_geoscale(gs, type = "stack"))
  fills <- unlist(lapply(b$data, function(d) d$fill))
  # the two leaves keep the first two colours; the top plane takes the third
  expect_setequal(fills, geoscales:::.GEO_CAT_FILLS[1:3])
  expect_false("grey85" %in% fills)
})

test_that("the stack leaves hidden geoframes out unless asked", {
  skip_if_not_installed("ggplot2")
  gs <- hide_geoframes_geoscale(.toy_gs(), "cell")
  n_sf <- function(p) {
    sum(vapply(p$layers, function(l) inherits(l$geom, "GeomSf"), logical(1)))
  }
  expect_equal(n_sf(gg_geoscale(gs, type = "stack")), 1L)
  expect_equal(n_sf(gg_geoscale(gs, type = "stack", geoframes = TRUE)), 2L)
  # a hidden geoframe may still be asked for by name
  expect_equal(n_sf(gg_geoscale(gs, type = "stack", geoframes = "cell")), 1L)
})
