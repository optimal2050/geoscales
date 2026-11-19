# Leaftable rows are in nested order by default --------------------------------

test_that("rows sort by geoframe, coarsest first, unassigned last", {
  df <- data.frame(country = c("B", NA, "A", "B"),
                   atom = c("b1", "x", "a1", "b2"),
                   km2 = c(1, 2, 3, 4))
  gs <- geoscale_from_leaftable(df, geoframes = c("country", "atom"))
  expect_identical(geoscale_leaftable(gs)$atom,c("b1", "b2", "a1", "x"))
  given <- geoscale_from_leaftable(df, geoframes = c("country", "atom"),
                                   row_order = "given")
  expect_identical(geoscale_leaftable(given)$atom,df$atom)
})

test_that("geometry follows the sorted rows", {
  skip_if_not_installed("sf")
  df <- data.frame(country = c("B", "A"), atom = c("b1", "a1"))
  g <- sf::st_sfc(sf::st_point(c(2, 0)), sf::st_point(c(1, 0)))
  gs <- geoscale_from_leaftable(df, geoframes = c("country", "atom"),
                                geometry = g)
  xy <- sf::st_coordinates(S7::prop(gs, "geometry"))
  expect_identical(geoscale_leaftable(gs)$atom,c("b1", "a1"))
  expect_equal(xy[, "X"], c(2, 1))
})

# A by-position bind cannot be checked, so it is guarded ------------------------

test_that("attaching a bare sfc to a re-sorted leaftable is refused", {
  skip_if_not_installed("sf")
  # the sort moves `a1` ahead of `x`, so input position no longer tracks rows
  df <- data.frame(country = c("B", NA, "A", "B"),
                   atom = c("b1", "x", "a1", "b2"))
  gs <- geoscale_from_leaftable(df, geoframes = c("country", "atom"))
  expect_true(S7::prop(gs, "meta")$row_permuted)

  g <- sf::st_sfc(sf::st_point(c(1, 0)), sf::st_point(c(2, 0)),
                  sf::st_point(c(3, 0)), sf::st_point(c(4, 0)))
  expect_error(attach_geometry_geoscale(gs, g), "re-sorted")

  # acknowledged, it goes through unchanged
  ok <- attach_geometry_geoscale(gs, g, positional = TRUE)
  expect_equal(sf::st_coordinates(S7::prop(ok, "geometry"))[, "X"],
               c(1, 2, 3, 4))

  # the by-code route needs no acknowledgement and keys to the sorted rows
  sfo <- sf::st_sf(atom = df$atom, geometry = g)
  by_code <- attach_geometry_geoscale(gs, sfo, by = "atom")
  expect_equal(sf::st_coordinates(S7::prop(by_code, "geometry"))[, "X"],
               c(1, 4, 3, 2))
})

test_that("an unpermuted leaftable binds by position without complaint", {
  skip_if_not_installed("sf")
  # nothing moved, so input position IS leaftable order and the bind is sound
  df <- data.frame(country = c("A", "B"), atom = c("a1", "b1"))
  gs <- geoscale_from_leaftable(df, geoframes = c("country", "atom"))
  expect_false(S7::prop(gs, "meta")$row_permuted)

  g <- sf::st_sfc(sf::st_point(c(1, 0)), sf::st_point(c(2, 0)))
  expect_silent(attach_geometry_geoscale(gs, g))
})
