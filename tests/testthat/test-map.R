# geoscale_map() -- the crosswalk through the atom layer ----------------------

gs <- geoscale_example()

test_that("within-object map carries counts, weights and from-totals", {
  m <- geoscale_map("country", "state", gs = gs, weight = "km2")
  expect_named(m, c("country", "state", "n_from", "n_overlap", "w",
                    "w_from"))
  # N: atoms A1..A4 (km2 100+200+300+400); N1 = A1,A2
  expect_equal(m$w[m$country == "N" & m$state == "N1"], 300)
  expect_equal(m$w_from[m$country == "N" & m$state == "N1"], 1000)
  expect_equal(m$n_from[m$country == "N" & m$state == "N1"], 4L)
  expect_equal(m$n_overlap[m$country == "N" & m$state == "N1"], 2L)
  # shares within a from-region sum to 1
  expect_equal(sum(m$w[m$country == "N"] / m$w_from[m$country == "N"]), 1,
               tolerance = 1e-12)
})

test_that("cross-cutting geoframes produce partial overlaps", {
  m <- geoscale_map("state", "zone", gs = gs)  # default weight km2
  # S1 (A5 km2 500, A6 km2 600) splits between ZB and ZC
  expect_equal(m$w[m$state == "S1" & m$zone == "ZB"], 500)
  expect_equal(m$w[m$state == "S1" & m$zone == "ZC"], 600)
  expect_equal(unique(m$w_from[m$state == "S1"]), 1100)
})

test_that("atoms uncovered by `to` appear as NA target rows", {
  m <- geoscale_map("atom", "country", gs = gs)
  expect_true(any(is.na(m$country[m$atom == "ROW"])))
  # ROW's weight still counts toward its own from-total
  expect_equal(m$w_from[m$atom == "ROW"], 1000)
})

test_that("same geoframe or unnamed pairs error clearly", {
  expect_error(geoscale_map("state", "state", gs = gs), "same geoframe")
  expect_error(geoscale_map("state", "zone"), "`gs` is required")
})

test_that("registered maps short-circuit the derivation", {
  on.exit(clear_geoscale_maps(), add = TRUE)
  fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
                     n_overlap = 1L, w = 1, w_from = 1)
  register_geoscale_map("state", "zone", fake, gs = gs)
  expect_identical(geoscale_map("state", "zone", gs = gs), fake)
  # removal restores the derived map
  register_geoscale_map("state", "zone", NULL, gs = gs)
  expect_gt(nrow(geoscale_map("state", "zone", gs = gs)), 1L)
  # malformed maps are rejected
  expect_error(register_geoscale_map("state", "zone", data.frame(a = 1)),
               "missing column")
})

test_that("cross-object map matches atoms on shared region keys", {
  lf <- data.frame(band = rep(c("X", "Y"), 3),
                   atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                   km2 = c(100, 200, 300, 400, 500, 600))
  gs_b <- geoscale_from_leaftable(lf, geoframes = c("band", "atom"),
                                  name = "bands")
  m <- suppressWarnings(geoscale_map(gs, gs_b))
  expect_named(m, c("example", "bands", "n_from", "n_overlap", "w",
                    "w_from"))
  # shared atoms map 1:1; ROW has no counterpart -> NA target + warning
  expect_warning(m2 <- geoscale_map(gs, gs_b), "no counterpart")
  expect_true(is.na(m2$bands[m2$example == "ROW"]))
  expect_equal(m2$bands[m2$example == "A1"], "A1")

  # same name or no shared keys error
  expect_error(geoscale_map(gs, gs), "same name")
  lf2 <- data.frame(g = "G", atom = c("Z1", "Z2"))
  gs_c <- geoscale_from_leaftable(lf2, geoframes = c("g", "atom"),
                                  name = "other")
  expect_error(suppressWarnings(geoscale_map(gs, gs_c)),
               "share no `region` keys")
})

test_that("map registry accessors round-trip", {
  on.exit(clear_geoscale_maps(), add = TRUE)
  clear_geoscale_maps()
  expect_equal(nrow(list_geoscale_maps()), 0L)
  fake <- data.frame(state = "N1", zone = "ZC", n_from = 1L,
                     n_overlap = 1L, w = 1, w_from = 1)
  register_geoscale_map("state", "zone", fake, gs = gs)
  expect_equal(nrow(list_geoscale_maps()), 1L)
  expect_identical(get_geoscale_map("state", "zone", gs = gs), fake)
  expect_null(get_geoscale_map("nope", "zone"))
})
