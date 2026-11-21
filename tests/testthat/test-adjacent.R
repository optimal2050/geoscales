# =========================================================================== #
# geoscale_adjacent() -- every count here is read off the fixture's geometry,
# not from a previous run. `.squares_gs()` is 1 x 1 squares A1..A6:
#
#     y=1 |  A1  A3  A5          country  N: A1 A2 A3 A4    S: A5 A6
#     y=0 |  A2  A4  A6          state    N1: A1 A2  N2: A3 A4  S1: A5 A6
#          x=0 x=1 x=2
#
# rook borders (7): A1-A2 A1-A3 A2-A4 A3-A4 A3-A5 A4-A6 A5-A6
# queen adds (4):   A1-A4 A2-A3 A3-A6 A4-A5
# =========================================================================== #

# @covers geoscale_adjacent depth=U

skip_if_not_installed("sf")

test_that("rook counts shared edges and queen adds the diagonals", {
  gs <- .squares_gs()
  rook  <- geoscale_adjacent(gs, "cell", contiguity = "rook")
  queen <- geoscale_adjacent(gs, "cell", contiguity = "queen")

  expect_equal(sum(rook) / 2, 7)
  expect_equal(sum(queen) / 2, 11)
  # queen is a superset: every rook border is a queen border
  expect_true(all(queen[rook]))

  # the four diagonals, named
  expect_false(rook["A1", "A4"])
  expect_true(queen["A1", "A4"])
  expect_false(rook["A2", "A3"])
  expect_true(queen["A2", "A3"])
  expect_false(rook["A3", "A6"])
  expect_true(queen["A3", "A6"])
  expect_false(rook["A4", "A5"])
  expect_true(queen["A4", "A5"])
})

test_that("the matrix is symmetric, hollow and named in member order", {
  gs <- .squares_gs()
  a <- geoscale_adjacent(gs, "cell")
  expect_true(isSymmetric(a))
  expect_true(all(!diag(a)))
  expect_equal(rownames(a), paste0("A", 1:6))
  expect_equal(colnames(a), rownames(a))
  expect_true(is.logical(a))
})

test_that("queen is the default", {
  gs <- .squares_gs()
  expect_identical(geoscale_adjacent(gs, "cell"),
                   geoscale_adjacent(gs, "cell", contiguity = "queen"))
})

test_that("`within` cuts every edge crossing the parent", {
  gs <- .squares_gs()
  # within state: only the three vertical pairs survive
  st <- geoscale_adjacent(gs, "cell", within = "state", contiguity = "rook")
  expect_equal(sum(st) / 2, 3)
  expect_true(st["A1", "A2"] && st["A3", "A4"] && st["A5", "A6"])
  expect_false(st["A1", "A3"])        # N1 -> N2
  expect_false(st["A3", "A5"])        # N2 -> S1

  # within country: N's four cells keep their four borders, S keeps one
  co <- geoscale_adjacent(gs, "cell", within = "country", contiguity = "rook")
  expect_equal(sum(co) / 2, 5)
  expect_false(co["A3", "A5"])
  expect_false(co["A4", "A6"])
  expect_true(co["A1", "A3"])
})

test_that("adjacency works at a coarser geoframe, on dissolved geometry", {
  gs <- .squares_gs()
  a <- geoscale_adjacent(gs, "state", contiguity = "rook")
  expect_equal(rownames(a), c("N1", "N2", "S1"))
  # N1 (x in 0..1) touches N2 (x in 1..2); N2 touches S1 (x in 2..3)
  expect_true(a["N1", "N2"] && a["N2", "S1"])
  expect_false(a["N1", "S1"])
})

test_that("`within` must be coarser than `geoframe`", {
  gs <- .squares_gs()
  expect_error(geoscale_adjacent(gs, "state", within = "cell"), "COARSER")
  expect_error(geoscale_adjacent(gs, "cell", within = "cell"), "COARSER")
  expect_error(geoscale_adjacent(gs, "cell", within = "nope"),
               "not a geoframe")
})

test_that("an island is isolated by default and joined on request", {
  sq <- function(x, y) {
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x),
                              c(y, y, y + 1, y + 1, y))))
  }
  gs <- geoscale_from_leaftable(
    data.frame(country = c("N", "N", "N"),
               cell = c("A1", "A2", "ISL"), km2 = 1),
    geoframes = c("country", "cell"), name = "isl")
  # A1 and A2 share an edge and lie in a row, so ISL's nearest is A2 with no
  # tie: a distance of 1 to A2's east edge against 2 to A1's. Stacking A1
  # above A2 instead would put A1's corner the same distance of 2 away as
  # A2's edge, and `which.min()` would break the tie by position rather than
  # by distance.
  gs <- attach_geometry_geoscale(
    gs, sf::st_sfc(sq(0, 0), sq(1, 0), sq(3, 0), crs = 4326))

  none <- geoscale_adjacent(gs, "cell", isolated = "none")
  expect_equal(sum(none["ISL", ]), 0L)
  expect_equal(sum(none) / 2, 1)

  near <- geoscale_adjacent(gs, "cell", isolated = "nearest")
  expect_true(near["ISL", "A2"])
  expect_false(near["ISL", "A1"])
  expect_true(isSymmetric(near))
  expect_equal(sum(near) / 2, 2)
})

test_that("isolation is resolved after `within`, never across it", {
  sq <- function(x, y) {
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x),
                              c(y, y, y + 1, y + 1, y))))
  }
  # ISL is nearest to B1, which is in the OTHER country. Fixing isolation
  # first and masking second would hand ISL the B1 edge and then cut it,
  # leaving ISL alone anyway; masking first makes it take A1 instead.
  gs <- geoscale_from_leaftable(
    data.frame(country = c("N", "N", "S"),
               cell = c("A1", "ISL", "B1"), km2 = 1),
    geoframes = c("country", "cell"), name = "isl2")
  gs <- attach_geometry_geoscale(
    gs, sf::st_sfc(sq(0, 0), sq(10, 0), sq(12, 0), crs = 4326))

  free <- geoscale_adjacent(gs, "cell", isolated = "nearest")
  expect_true(free["ISL", "B1"])          # nearest overall

  held <- geoscale_adjacent(gs, "cell", within = "country",
                             isolated = "nearest")
  expect_true(held["ISL", "A1"])          # nearest within N
  expect_false(held["ISL", "B1"])
})

test_that("a feature alone in its parent stays alone", {
  sq <- function(x, y) {
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x),
                              c(y, y, y + 1, y + 1, y))))
  }
  gs <- geoscale_from_leaftable(
    data.frame(country = c("N", "N", "S"),
               cell = c("A1", "A2", "B1"), km2 = 1),
    geoframes = c("country", "cell"), name = "lone")
  gs <- attach_geometry_geoscale(
    gs, sf::st_sfc(sq(0, 0), sq(1, 0), sq(5, 0), crs = 4326))
  a <- geoscale_adjacent(gs, "cell", within = "country",
                          isolated = "nearest")
  expect_equal(sum(a["B1", ]), 0L)
  expect_true(a["A1", "A2"])
})

test_that("an unassigned parent is its own group, not pooled with other NAs", {
  sq <- function(x, y) {
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x),
                              c(y, y, y + 1, y + 1, y))))
  }
  # X1 and X2 touch, and BOTH have no country. `==` on NA would give NA and
  # poison the mask; pooling them would invent a shared parent.
  gs <- geoscale_from_leaftable(
    data.frame(country = c("N", NA, NA),
               cell = c("A1", "X1", "X2"), km2 = 1),
    geoframes = c("country", "cell"), name = "na")
  gs <- attach_geometry_geoscale(
    gs, sf::st_sfc(sq(0, 0), sq(1, 0), sq(2, 0), crs = 4326))
  a <- geoscale_adjacent(gs, "cell", within = "country")
  expect_true(is.logical(a))
  expect_false(anyNA(a))
  expect_false(a["X1", "X2"])
  expect_equal(sum(a), 0L)
})

test_that("geometry is required, and a single feature gives an empty matrix", {
  expect_error(geoscale_adjacent(geoscale_example()), "no geometry")

  sq <- sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0))))
  gs <- geoscale_from_leaftable(
    data.frame(country = "N", cell = "A1", km2 = 1),
    geoframes = c("country", "cell"), name = "one")
  gs <- attach_geometry_geoscale(gs, sf::st_sfc(sq, crs = 4326))
  a <- geoscale_adjacent(gs, "cell")
  expect_equal(dim(a), c(1L, 1L))
  expect_false(a[1, 1])
})
