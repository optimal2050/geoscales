test_that("geoscale_build assembles crosswalks into a wide table", {
  b <- geoscale_build(
    data.frame(country = c("N", "N", "S"), state = c("N1", "N2", "S1")),
    data.frame(state = c("N1", "N1", "N2", "S1"),
               cell  = c("A1", "A2", "A3", "A4")),
    geoframes  = c("country", "state", "cell"),
    weights = data.frame(cell = c("A1", "A2", "A3", "A4"),
                         km2 = c(10, 20, 30, 40))
  )
  expect_equal(S7::prop(b, "geoframes"), c("country", "state", "cell"))
  expect_equal(nrow(S7::prop(b, "leaftable")), 4L)
  expect_equal(geoscale_children(b, "country", "N"), c("N1", "N2"))
  expect_equal(geoscale_weights(b), "km2")
})

test_that("geoscale_build accepts a cross-cutting geoframe", {
  # State N2 spans leaves A2 and A3, which sit in different zones, so state
  # and zone cross-cut even though both nest inside country.
  b <- geoscale_build(
    data.frame(state = c("N1", "N2", "S1"), country = c("N", "N", "S")),
    data.frame(state = c("N1", "N2", "N2", "S1"),
               cell  = c("A1", "A2", "A3", "A4")),
    data.frame(zone = c("Z1", "Z1", "Z2", "Z2"),
               cell = c("A1", "A2", "A3", "A4")),
    geoframes = c("country", "zone", "state", "cell")
  )
  expect_equal(nrow(S7::prop(b, "leaftable")), 4L)
  expect_true(geoscale_nests(b, "country", "state"))
  expect_false(geoscale_nests(b, "zone", "state"))
})

test_that("geoscale_build reports unreachable and duplicated input", {
  expect_error(
    geoscale_build(data.frame(a = "x", b = "y"), geoframes = c("a", "b", "c")),
    "leaf geoframe"
  )
  # Two different parents claiming the same leaf is a genuine conflict
  # (identical rows would simply be de-duplicated).
  expect_error(
    geoscale_build(
      data.frame(top = c("T1", "T2"), cell = c("A", "A")),
      geoframes = c("top", "cell")
    ),
    "duplicated leaf"
  )
})

test_that("geoscale_layout tiles each geoframe across the full width", {
  gs <- geoscale_example()
  d <- geoscale_layout(gs, weight = "km2")
  expect_named(d, c("geoframe", "region", "rank", "xmin", "xmax",
                    "ymin", "ymax", "weight", "share"))
  # Leaves cover the whole axis; coarser geoframes omit the unassigned ROW leaf
  leaf_rows <- d[d$geoframe == "cell", ]
  expect_equal(min(leaf_rows$xmin), 0, tolerance = 1e-9)
  expect_equal(max(leaf_rows$xmax), 1, tolerance = 1e-9)
  expect_equal(sum(d$share[d$geoframe == "state"]),
               sum(leaf_rows$share[leaf_rows$region != "ROW"]),
               tolerance = 1e-9)
})

test_that("geoscale_layout keeps sibling regions contiguous", {
  gs <- geoscale_example()
  d <- geoscale_layout(gs, weight = "km2")
  cn <- d[d$geoframe == "country", ]
  # Two countries, each a single unbroken rectangle
  expect_equal(nrow(cn), 2L)
  expect_equal(cn$xmax[cn$region == "N"], cn$xmin[cn$region == "S"],
               tolerance = 1e-9)
})

test_that("plotting works when ggplot2 is available", {
  skip_if_not_installed("ggplot2")
  gs <- geoscale_example()
  p <- gg_geoscale(gs)
  expect_s3_class(p, "ggplot")
  expect_s3_class(ggplot2::autoplot(gs), "ggplot")
})

# A four-square strip, paired into two zones, with a display name per cell.
# Small enough to reason about, and the only fixture in the suite with geometry.
.plot_fixture <- function(...) {
  sq <- function(i) {
    sf::st_polygon(list(cbind(c(i, i + 1, i + 1, i, i), c(0, 0, 1, 1, 0))))
  }
  lf <- data.frame(top = "T", zone = c("Z1", "Z1", "Z2", "Z2"),
                   cell = c("u1", "u2", "u3", "u4"),
                   name = c("Alpha", "Beta", "Gamma", "Delta"),
                   km2 = c(1, 2, 3, 4), stringsAsFactors = FALSE)
  g <- geoscale_from_leaftable(lf, geoframes = c("top", "zone", "cell"),
                            leaf = "cell", weights = "km2", name = "fx", ...)
  attach_geometry_geoscale(
    g, sf::st_sf(cell = lf$cell, geometry = sf::st_sfc(lapply(0:3, sq))),
    by = "cell", geoframe = "cell")
}

test_that("the map draws outlines and a filled choropleth", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  gs <- .plot_fixture()
  d <- data.frame(cell = c("u1", "u2", "u3", "u4"), x = c(10, 20, 30, 40))

  expect_s3_class(gg_geoscale(gs, type = "map"), "ggplot")
  p <- gg_geoscale(gs, type = "map", data = d, geoframe = "cell", z = "x")
  expect_s3_class(p, "ggplot")
  # geometry is dissolved to the requested geoframe before drawing
  built <- ggplot2::ggplot_build(gg_geoscale(gs, type = "map",
                                             geoframe = "zone"))
  expect_equal(nrow(built$data[[1]]), 2L)

  expect_error(gg_geoscale(gs, type = "map", data = d, geoframe = "zone",
                           z = "x"),
               "keyed by `cell`")
  expect_error(gg_geoscale(gs, type = "map", data = d, geoframe = "cell",
                           z = "nope"),
               "`z` must name")
})

test_that("the map honours palette and takes titles through labs()", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  gs <- .plot_fixture()
  d <- data.frame(cell = c("u1", "u2", "u3", "u4"), x = c(10, 20, 30, 40))

  p <- gg_geoscale(gs, type = "map", data = d, geoframe = "cell", z = "x",
                   palette = "D") +
    ggplot2::labs(title = "Gen", subtitle = "by cell", fill = NULL)
  expect_equal(p$labels$title, "Gen")
  expect_equal(p$labels$subtitle, "by cell")
  expect_null(p$labels$fill)
  # viridis "D" starts at #440154; the default gradient starts at #132B43
  expect_equal(as.character(ggplot2::ggplot_build(p)$data[[1]]$fill)[1],
               "#440154")

  # defaults must reproduce the pre-enrichment output
  q <- gg_geoscale(gs, type = "map", data = d, geoframe = "cell", z = "x")
  expect_equal(as.character(ggplot2::ggplot_build(q)$data[[1]]$fill)[1],
               "#132B43")
  expect_equal(q$labels$fill, "x")
  expect_null(q$labels$title)
})

test_that("labels are used where a geoframe declares them", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  # Labels are declared per geoframe: the cells have names, the zones and the
  # top do not, so those are shown by their codes.
  gsl <- .plot_fixture(labels = data.frame(
    geoframe = "cell", region = c("u1", "u2", "u3", "u4"),
    label = c("Alpha", "Beta", "Gamma", "Delta")
  ))
  txt <- function(p) ggplot2::ggplot_build(p)$data[[2]]$label

  expect_equal(txt(gg_geoscale(gsl, type = "map", geoframe = "cell",
                               labels = TRUE)),
               c("Alpha", "Beta", "Gamma", "Delta"))
  expect_equal(txt(gg_geoscale(gsl, type = "map", geoframe = "zone",
                               labels = TRUE)),
               c("Z1", "Z2"))
  # icicle labels are drawn widest-rectangle-first (check_overlap keeps the
  # first drawn), so compare as sets, not in layout order
  expect_setequal(txt(gg_geoscale(gsl)),
                  c("T", "Z1", "Z2", "Alpha", "Beta", "Gamma", "Delta"))

  # no `labels` declared -> codes everywhere, exactly as before
  gs <- .plot_fixture()
  expect_equal(txt(gg_geoscale(gs, type = "map", geoframe = "cell",
                               labels = TRUE)),
               c("u1", "u2", "u3", "u4"))
  expect_setequal(txt(gg_geoscale(gs)),
                  c("T", "Z1", "Z2", "u1", "u2", "u3", "u4"))
})

test_that("geometry entry points error clearly without geometry", {
  gs <- geoscale_example()
  skip_if_not_installed("sf")
  expect_error(geoscale_geometry(gs), "no geometry attached")
  expect_error(add_area_geoscale(gs), "no geometry attached")
})

test_that("providers can be registered and listed", {
  register_geoscale_provider(
    "toy",
    fetch = function(...) {
      data.frame(top = c("T", "T"), cell = c("a", "b"), km2 = c(1, 2))
    },
    geoframes = c("top", "cell"), weights = "km2", desc = "toy"
  )
  expect_true("toy" %in% list_geoscale_providers()$name)
  expect_true("naturalearth" %in% list_geoscale_providers()$name)

  gs <- geoscale_from_provider("toy")
  expect_equal(S7::prop(gs, "geoframes"), c("top", "cell"))
  expect_equal(geoscale_weights(gs), "km2")
  expect_equal(S7::prop(gs, "meta")$source, "toy")

  expect_error(get_geoscale_provider("nope"), "unknown provider")
})

test_that("provider geometry follows the rows into nested order", {
  skip_if_not_installed("sf")
  # one unit square per cell, at x = 10, 20, 30 for b1, a1, b2
  square <- function(x) {
    sf::st_polygon(list(rbind(c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1),
                              c(x, 0))))
  }
  at <- c(b1 = 10, a1 = 20, b2 = 30)
  src <- sf::st_sf(
    top = c("B", "A", "B"), cell = names(at),
    geometry = sf::st_sfc(lapply(unname(at), square))
  )
  gs <- geoscale_from_provider(src, geoframes = c("top", "cell"))
  expect_true(S7::prop(gs, "meta")$row_permuted)
  cells <- geoscale_leaftable(gs)$cell
  # members keep their order of appearance, so B comes first
  expect_identical(cells, c("b1", "b2", "a1"))
  left <- vapply(S7::prop(gs, "geometry"),
                 function(g) sf::st_bbox(g)[["xmin"]], numeric(1))
  expect_identical(unname(left), unname(at[cells]))

  # rows already in nested order keep their geometry in place
  ord <- src[c(2, 1, 3), ]
  gs2 <- geoscale_from_provider(ord, geoframes = c("top", "cell"))
  expect_false(S7::prop(gs2, "meta")$row_permuted)
  left2 <- vapply(S7::prop(gs2, "geometry"),
                  function(g) sf::st_bbox(g)[["xmin"]], numeric(1))
  expect_identical(unname(left2), unname(at[geoscale_leaftable(gs2)$cell]))
})

test_that("the Natural Earth provider errors helpfully when absent", {
  skip_if(requireNamespace("rnaturalearth", quietly = TRUE))
  expect_error(ne_source(), "rnaturalearth")
})
