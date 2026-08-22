# geom_geoscale() / theme_geoscale() / plot.Geoscale ---------------------------

.toy_gs <- function() {
  skip_if_not_installed("sf")
  lf <- data.frame(top = c("T", "T"), atom = c("a", "b"),
                   km2 = c(1, 3))
  gs <- geoscale_from_leaftable(lf, geoframes = c("top", "atom"),
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
  x <- data.frame(atom = c("a", "a", "b"), v = c(1, 3, 10))
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
  expect_equal(built$value[built$atom == "a"], 2)
  expect_equal(built$value[built$atom == "b"], 10)
})

test_that("geom_geoscale infers the geoframe and coarser frames dissolve", {
  skip_if_not_installed("ggplot2")
  gs <- .toy_gs()
  x <- data.frame(top = "T", v = 5)
  lyr <- geom_geoscale(gs = gs, z = "v", data = x)   # infers `top`
  expect_equal(nrow(lyr[[1]]$data), 1L)
  expect_equal(lyr[[1]]$data$value, 5)

  # z = NULL draws plain boundaries at the atom geoframe
  lyr0 <- geom_geoscale(gs = gs)
  expect_s3_class(lyr0[[1]], "LayerSf")
  expect_equal(nrow(lyr0[[1]]$data), 2L)
})

test_that("geom_geoscale validates its inputs", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  gs_nogeom <- geoscale_example()
  expect_error(geom_geoscale(gs = gs_nogeom, z = "v",
                             data = data.frame(atom = "A1", v = 1)),
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

test_that("plot() dispatches to geoscale_autoplot", {
  skip_if_not_installed("ggplot2")
  p <- plot(geoscale_example())
  expect_s3_class(p, "ggplot")
})
