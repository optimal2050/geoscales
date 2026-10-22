# Leaftable rows are in nested order by default --------------------------------

test_that("rows sort by geoframe, coarsest first, unassigned last", {
  df <- data.frame(country = c("B", NA, "A", "B"), atom = c("b1", "x", "a1", "b2"),
                   km2 = c(1, 2, 3, 4))
  gs <- geoscale_from_leaftable(df, geoframes = c("country", "atom"))
  expect_identical(geoscale_leaftable(gs)$region, c("b1", "b2", "a1", "x"))
  given <- geoscale_from_leaftable(df, geoframes = c("country", "atom"),
                                   row_order = "given")
  expect_identical(geoscale_leaftable(given)$region, df$atom)
})

test_that("geometry follows the sorted rows", {
  skip_if_not_installed("sf")
  df <- data.frame(country = c("B", "A"), atom = c("b1", "a1"))
  g <- sf::st_sfc(sf::st_point(c(2, 0)), sf::st_point(c(1, 0)))
  gs <- geoscale_from_leaftable(df, geoframes = c("country", "atom"),
                                geometry = g)
  xy <- sf::st_coordinates(S7::prop(gs, "geometry"))
  expect_identical(geoscale_leaftable(gs)$region, c("b1", "a1"))
  expect_equal(xy[, "X"], c(2, 1))
})
