gs <- geoscale_example()
atoms <- c("A1", "A2", "A3", "A4", "A5", "A6")
cap <- data.frame(atom = atoms, capacity = c(1, 2, 3, 4, 5, 6))

test_that("aggregation up conserves the total", {
  out <- recast_geoscale(cap, gs, "atom", "country", rule = "sum")
  expect_equal(sum(out$capacity), sum(cap$capacity), tolerance = 1e-9)
  expect_equal(out$capacity[out$country == "N"], 10)
  expect_equal(out$capacity[out$country == "S"], 11)
})

test_that("disaggregation down splits proportionally to the weight", {
  y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
  out <- recast_geoscale(y, gs, "country", "state", rule = "sum", weight = "km2")
  expect_equal(sum(out$capacity), 30, tolerance = 1e-9)
  # N's atoms carry km2 100/200/300/400: N1 -> 300/1000, N2 -> 700/1000
  expect_equal(out$capacity[out$state == "N1"], 3, tolerance = 1e-9)
  expect_equal(out$capacity[out$state == "N2"], 7, tolerance = 1e-9)
})

test_that("down-then-up round-trips exactly", {
  up   <- recast_geoscale(cap, gs, "atom", "state", rule = "sum")
  back <- recast_geoscale(up, gs, "state", "atom", rule = "sum", weight = "km2")
  back <- back[match(atoms, back$atom), ]
  expect_equal(back$capacity, cap$capacity, tolerance = 1e-9)
})

test_that("intensive values are copied down and weight-averaged up", {
  eff <- data.frame(atom = atoms, eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6))
  up <- recast_geoscale(eff, gs, "atom", "state", rule = "weighted_mean",
                   weight = "pop")
  # N1: (0.3*10 + 0.4*90) / 100
  expect_equal(up$eff[up$state == "N1"], 0.39, tolerance = 1e-9)
  expect_equal(up$eff[up$state == "N2"], 0.50, tolerance = 1e-9)

  down <- recast_geoscale(up, gs, "state", "atom", rule = "weighted_mean",
                     weight = "pop")
  expect_equal(down$eff[down$atom == "A1"], 0.39, tolerance = 1e-9)
  expect_equal(down$eff[down$atom == "A2"], 0.39, tolerance = 1e-9)
})

test_that("cross-cutting levels aggregate through the atom layer", {
  # zone ZB straddles states N2 and S1, so it must draw from both.
  s <- data.frame(state = c("N1", "N2", "S1"), capacity = c(3, 7, 11))
  out <- recast_geoscale(s, gs, "state", "zone", rule = "sum", weight = "km2")
  expect_equal(sum(out$capacity), 21, tolerance = 1e-9)
  expect_equal(out$capacity[out$zone == "ZB"], 12, tolerance = 1e-9)
  expect_equal(out$capacity[out$zone == "ZC"], 6, tolerance = 1e-9)
})

test_that("identifier columns are preserved as grouping columns", {
  p <- data.frame(
    atom = rep(c("A1", "A2", "A3"), each = 2),
    year = rep(c(2020L, 2021L), 3),
    capacity = c(1, 2, 3, 4, 5, 6)
  )
  out <- recast_geoscale(p, gs, "atom", "state", rule = "sum",
                    values = "capacity")
  expect_equal(nrow(out), 4L)
  expect_type(out$year, "integer")
  got <- out$capacity[out$state == "N1" & out$year == 2020]
  expect_equal(got, 4, tolerance = 1e-9)
})

test_that("na_action controls partial coverage", {
  x2 <- rbind(cap, data.frame(atom = "ROW", capacity = 100))

  expect_warning(
    drop <- recast_geoscale(x2, gs, "atom", "country", rule = "sum"),
    "no code at level"
  )
  expect_equal(sum(drop$capacity), 21, tolerance = 1e-9)

  keep <- recast_geoscale(x2, gs, "atom", "country", rule = "sum",
                     na_action = "keep")
  expect_equal(sum(keep$capacity), 121, tolerance = 1e-9)
  expect_true(any(is.na(keep$country)))

  expect_error(
    recast_geoscale(x2, gs, "atom", "country", rule = "sum", na_action = "error"),
    "na_action"
  )
})

test_that("a partly uncovered source region loses its uncovered share", {
  df <- data.frame(top = c("T", "T", "T"), mid = c("M1", "M2", NA),
                   leaf = c("L1", "L2", "L3"), km2 = c(100, 100, 200))
  g <- geoscale_from_leaves(df, levels = c("top", "mid", "leaf"))
  v <- data.frame(top = "T", capacity = 100)

  expect_warning(out <- recast_geoscale(v, g, "top", "mid", rule = "sum"),
                 "dropped")
  # Half the area is uncovered, so only half the value can be placed.
  expect_equal(sum(out$capacity), 50, tolerance = 1e-9)

  kept <- recast_geoscale(v, g, "top", "mid", rule = "sum", na_action = "keep")
  expect_equal(sum(kept$capacity), 100, tolerance = 1e-9)
})

test_that("unknown source codes warn and are dropped", {
  x <- data.frame(atom = c("A1", "NOPE"), capacity = c(5, 9))
  expect_warning(out <- recast_geoscale(x, gs, "atom", "country", rule = "sum"),
                 "not present at level")
  expect_equal(sum(out$capacity), 5, tolerance = 1e-9)
})

test_that("the copy rule requires constant values", {
  cc <- data.frame(atom = atoms, rate = rep(0.07, 6))
  out <- recast_geoscale(cc, gs, "atom", "country", rule = "copy")
  expect_equal(unique(out$rate), 0.07)

  cc$rate[1] <- 0.09
  expect_error(recast_geoscale(cc, gs, "atom", "country", rule = "copy"),
               "not constant")
})

test_that("bad levels and missing keys error clearly", {
  expect_error(recast_geoscale(cap, gs, "nope", "country"), "not a level")
  expect_error(recast_geoscale(cap, gs, "atom", "nope"), "not a level")
  expect_error(recast_geoscale(data.frame(v = 1), gs, "atom", "country"),
               "no column named")
})
