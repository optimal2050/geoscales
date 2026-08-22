# recast_to_geoatoms() / recast_from_geoatoms() -- the route halves ----------

gs <- geoscale_example()
atoms <- c("A1", "A2", "A3", "A4", "A5", "A6")

test_that("to_geoatoms splits extensive values by the weight and attaches it", {
  y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
  a <- recast_to_geoatoms(y, gs, from = "country", rule = "sum",
                          weight = "km2")
  expect_named(a, c("region", "capacity", "weight"))
  expect_equal(sum(a$capacity), 30, tolerance = 1e-12)
  # N (km2 100..400 of A1..A4): proportional split
  expect_equal(a$capacity[a$region == "A1"], 1, tolerance = 1e-12)
  expect_equal(a$capacity[a$region == "A4"], 4, tolerance = 1e-12)
  expect_equal(a$weight[a$region == "A4"], 400)

  # intensive values are repeated, not split
  z <- data.frame(country = c("N", "S"), eff = c(0.4, 0.6))
  az <- recast_to_geoatoms(z, gs, from = "country",
                           rule = "weighted_mean", weight = "km2")
  expect_equal(az$eff[az$region == "A1"], 0.4)
  expect_equal(az$eff[az$region == "A6"], 0.6)
})

test_that("from_geoatoms aggregates atoms up, using the carried weight", {
  y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
  a <- recast_to_geoatoms(y, gs, from = "country", rule = "sum",
                          weight = "km2")
  s <- recast_from_geoatoms(a, gs, to = "state", rule = "sum")
  expect_equal(s$capacity[s$state == "N1"], 3, tolerance = 1e-12)
  expect_equal(s$capacity[s$state == "N2"], 7, tolerance = 1e-12)
  expect_equal(s$capacity[s$state == "S1"], 20, tolerance = 1e-12)

  # weighted_mean reproduces the source weighting exactly via `weight`
  z <- data.frame(state = c("N1", "N2", "S1"), eff = c(0.39, 0.5, 0.55))
  az <- recast_to_geoatoms(z, gs, from = "state",
                           rule = "weighted_mean", weight = "pop")
  up <- recast_from_geoatoms(az, gs, to = "state", rule = "weighted_mean")
  expect_equal(up$eff, z$eff, tolerance = 1e-12)
})

test_that("composition of the halves equals recast_geoscale", {
  cap <- data.frame(atom = atoms, capacity = c(1, 2, 3, 4, 5, 6))
  a <- recast_to_geoatoms(cap, gs, from = "atom", rule = "sum",
                          weight = "km2")
  half <- recast_from_geoatoms(a, gs, to = "state", rule = "sum")
  full <- recast_geoscale(cap, gs, "atom", "state", rule = "sum",
                          weight = "km2")
  expect_equal(half$capacity[match(full$state, half$state)],
               full$capacity, tolerance = 1e-12)
})

test_that("the halves recast across two Geoscales sharing atom keys", {
  lf <- data.frame(band = rep(c("X", "Y"), 3),
                   atom = atoms,
                   km2 = c(100, 200, 300, 400, 500, 600))
  gs_b <- geoscale_from_leaftable(lf, geoframes = c("band", "atom"),
                                  name = "bands")
  cap <- data.frame(atom = atoms, capacity = c(1, 2, 3, 4, 5, 6))

  a <- recast_to_geoatoms(cap, gs, from = "atom", rule = "sum")
  out <- recast_from_geoatoms(a, gs_b, to = "band", rule = "sum")
  expect_equal(out$capacity[out$band == "X"], 1 + 3 + 5)
  expect_equal(out$capacity[out$band == "Y"], 2 + 4 + 6)

  # the fused verb: `to` = another Geoscale targets its atom layer
  cty <- data.frame(country = c("N", "S"), capacity = c(10, 20))
  ab <- recast_geoscale(cty, gs, from = "country", to = gs_b,
                        rule = "sum", weight = "km2")
  expect_equal(sum(ab$capacity), 30, tolerance = 1e-12)
  expect_equal(ab$capacity[ab$atom == "A1"], 1, tolerance = 1e-12)
})

test_that("the sd rule aggregates dispersion", {
  cap <- data.frame(atom = atoms, capacity = c(1, 2, 3, 4, 5, 6))
  s <- recast_geoscale(cap, gs, "atom", "state", rule = "sd")
  expect_equal(s$capacity[s$state == "N1"], stats::sd(c(1, 2)),
               tolerance = 1e-9)
  expect_equal(s$capacity[s$state == "S1"], stats::sd(c(5, 6)),
               tolerance = 1e-9)
  a <- recast_to_geoatoms(cap, gs, from = "atom", rule = "mean")
  s2 <- recast_from_geoatoms(a, gs, to = "state", rule = "sd")
  expect_equal(s2$capacity[s2$state == "N2"], stats::sd(c(3, 4)),
               tolerance = 1e-9)
})

test_that("conflicting per-column weights are rejected in to_geoatoms", {
  clear_geo_rules()
  on.exit(clear_geo_rules(), add = TRUE)
  register_geo_rule("a", "sum", weight = "km2")
  register_geo_rule("b", "sum", weight = "pop")
  y <- data.frame(country = c("N", "S"), a = c(1, 2), b = c(3, 4))
  expect_error(recast_to_geoatoms(y, gs, from = "country"),
               "different weights")
})

test_that("recast_geoscale handles per-column weights in one call", {
  clear_geo_rules()
  on.exit(clear_geo_rules(), add = TRUE)
  register_geo_rule("cap_km2", "sum", weight = "km2")
  register_geo_rule("cap_pop", "sum", weight = "pop")
  y <- data.frame(country = c("N", "S"),
                  cap_km2 = c(10, 20), cap_pop = c(10, 20))
  out <- recast_geoscale(y, gs, "country", "state")
  # km2 split: N1 gets 300/1000; pop split: N1 gets 100/200
  expect_equal(out$cap_km2[out$state == "N1"], 3, tolerance = 1e-12)
  expect_equal(out$cap_pop[out$state == "N1"], 5, tolerance = 1e-12)
})
