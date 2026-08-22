test_that("geoscale_build assembles crosswalks into a wide table", {
  b <- geoscale_build(
    data.frame(country = c("N", "N", "S"), state = c("N1", "N2", "S1")),
    data.frame(state = c("N1", "N1", "N2", "S1"),
               atom  = c("A1", "A2", "A3", "A4")),
    geoframes  = c("country", "state", "atom"),
    weights = data.frame(atom = c("A1", "A2", "A3", "A4"),
                         km2 = c(10, 20, 30, 40))
  )
  expect_equal(S7::prop(b, "geoframes"), c("country", "state", "atom"))
  expect_equal(nrow(S7::prop(b, "leaftable")), 4L)
  expect_equal(geoscale_children(b, "country", "N"), c("N1", "N2"))
  expect_equal(geoscale_weights(b), "km2")
})

test_that("geoscale_build accepts a cross-cutting geoframe", {
  # State N2 spans atoms A2 and A3, which sit in different zones, so state
  # and zone cross-cut even though both nest inside country.
  b <- geoscale_build(
    data.frame(state = c("N1", "N2", "S1"), country = c("N", "N", "S")),
    data.frame(state = c("N1", "N2", "N2", "S1"),
               atom  = c("A1", "A2", "A3", "A4")),
    data.frame(zone = c("Z1", "Z1", "Z2", "Z2"),
               atom = c("A1", "A2", "A3", "A4")),
    geoframes = c("country", "zone", "state", "atom")
  )
  expect_equal(nrow(S7::prop(b, "leaftable")), 4L)
  expect_true(geoscale_nests(b, "country", "state"))
  expect_false(geoscale_nests(b, "zone", "state"))
})

test_that("geoscale_build reports unreachable and duplicated input", {
  expect_error(
    geoscale_build(data.frame(a = "x", b = "y"), geoframes = c("a", "b", "c")),
    "atom geoframe"
  )
  # Two different parents claiming the same atom is a genuine conflict
  # (identical rows would simply be de-duplicated).
  expect_error(
    geoscale_build(
      data.frame(top = c("T1", "T2"), atom = c("A", "A")),
      geoframes = c("top", "atom")
    ),
    "duplicated atom"
  )
})

test_that("geoscale_layout tiles each geoframe across the full width", {
  gs <- geoscale_example()
  d <- geoscale_layout(gs, weight = "km2")
  expect_named(d, c("geoframe", "region", "rank", "xmin", "xmax",
                    "ymin", "ymax", "weight", "share"))
  # Atoms cover the whole axis; coarser geoframes omit the unassigned ROW atom
  atom_rows <- d[d$geoframe == "atom", ]
  expect_equal(min(atom_rows$xmin), 0, tolerance = 1e-9)
  expect_equal(max(atom_rows$xmax), 1, tolerance = 1e-9)
  expect_equal(sum(d$share[d$geoframe == "state"]),
               sum(atom_rows$share[atom_rows$region != "ROW"]),
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
  p <- geoscale_autoplot(gs)
  expect_s3_class(p, "ggplot")
  expect_s3_class(ggplot2::autoplot(gs), "ggplot")
})

# A four-square strip, paired into two zones, with a display name per unit.
# Small enough to reason about, and the only fixture in the suite with geometry.
.plot_fixture <- function(...) {
  sq <- function(i) sf::st_polygon(list(cbind(c(i, i + 1, i + 1, i, i),
                                              c(0, 0, 1, 1, 0))))
  lf <- data.frame(top = "T", zone = c("Z1", "Z1", "Z2", "Z2"),
                   unit = c("u1", "u2", "u3", "u4"),
                   name = c("Alpha", "Beta", "Gamma", "Delta"),
                   km2 = c(1, 2, 3, 4), stringsAsFactors = FALSE)
  g <- geoscale_from_leaftable(lf, geoframes = c("top", "zone", "unit"),
                            key = "unit", weights = "km2", name = "fx", ...)
  attach_geometry_geoscale(
    g, sf::st_sf(unit = lf$unit, geometry = sf::st_sfc(lapply(0:3, sq))),
    by = "unit", geoframe = "unit")
}

test_that("geoscale_plot draws outlines and a filled choropleth", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  gs <- .plot_fixture()
  d <- data.frame(unit = c("u1", "u2", "u3", "u4"), x = c(10, 20, 30, 40))

  expect_s3_class(geoscale_plot(gs), "ggplot")
  p <- geoscale_plot(gs, d, geoframe = "unit", fill = "x")
  expect_s3_class(p, "ggplot")
  # geometry is dissolved to the requested geoframe before drawing
  expect_equal(nrow(ggplot2::ggplot_build(geoscale_plot(gs, geoframe = "zone"))$data[[1]]), 2L)

  expect_error(geoscale_plot(gs, d, geoframe = "zone", fill = "x"), "no column")
  expect_error(geoscale_plot(gs, d, geoframe = "unit", fill = "nope"), "`fill` must name")
})

test_that("geoscale_plot honours palette, titles and the legend label", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  gs <- .plot_fixture()
  d <- data.frame(unit = c("u1", "u2", "u3", "u4"), x = c(10, 20, 30, 40))

  p <- geoscale_plot(gs, d, geoframe = "unit", fill = "x", palette = "D",
                title = "Gen", subtitle = "by unit", fill_label = NULL)
  expect_equal(p$labels$title, "Gen")
  expect_equal(p$labels$subtitle, "by unit")
  expect_null(p$labels$fill)
  # viridis "D" starts at #440154; the default gradient starts at #132B43
  expect_equal(as.character(ggplot2::ggplot_build(p)$data[[1]]$fill)[1], "#440154")

  # defaults must reproduce the pre-enrichment output
  q <- geoscale_plot(gs, d, geoframe = "unit", fill = "x")
  expect_equal(as.character(ggplot2::ggplot_build(q)$data[[1]]$fill)[1], "#132B43")
  expect_equal(q$labels$fill, "x")
  expect_null(q$labels$title)
})

test_that("labels are used only where they are unambiguous", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  # `@meta$labels` names a per-atom column. A zone made of Alpha and Beta has
  # no name of its own, so labelling it "Alpha" would invent one -- the code
  # must survive instead.
  gsl <- .plot_fixture(labels = "name")
  txt <- function(p) ggplot2::ggplot_build(p)$data[[2]]$label

  expect_equal(txt(geoscale_plot(gsl, geoframe = "unit", label = TRUE)),
               c("Alpha", "Beta", "Gamma", "Delta"))
  expect_equal(txt(geoscale_plot(gsl, geoframe = "zone", label = TRUE)), c("Z1", "Z2"))
  expect_equal(txt(geoscale_autoplot(gsl)),
               c("T", "Z1", "Z2", "Alpha", "Beta", "Gamma", "Delta"))

  # no `labels` declared -> codes everywhere, exactly as before
  gs <- .plot_fixture()
  expect_equal(txt(geoscale_plot(gs, geoframe = "unit", label = TRUE)),
               c("u1", "u2", "u3", "u4"))
  expect_equal(txt(geoscale_autoplot(gs)),
               c("T", "Z1", "Z2", "u1", "u2", "u3", "u4"))
})

test_that("geometry entry points error clearly without geometry", {
  gs <- geoscale_example()
  skip_if_not_installed("sf")
  expect_error(geoscale_geometry(gs), "no geometry attached")
  expect_error(add_area_geoscale(gs), "no geometry attached")
})

test_that("providers can be registered and listed", {
  register_geo_provider(
    "toy",
    fetch = function(...) {
      data.frame(top = c("T", "T"), unit = c("a", "b"), km2 = c(1, 2))
    },
    geoframes = c("top", "unit"), weights = "km2", desc = "toy"
  )
  expect_true("toy" %in% list_geo_providers()$name)
  expect_true("naturalearth" %in% list_geo_providers()$name)

  gs <- geoscale_from_provider("toy")
  expect_equal(S7::prop(gs, "geoframes"), c("top", "unit"))
  expect_equal(geoscale_weights(gs), "km2")
  expect_equal(S7::prop(gs, "meta")$source, "toy")

  expect_error(get_geo_provider("nope"), "unknown provider")
})

test_that("the Natural Earth provider errors helpfully when absent", {
  skip_if(requireNamespace("rnaturalearth", quietly = TRUE))
  expect_error(ne_source(), "rnaturalearth")
})
