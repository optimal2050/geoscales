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

test_that("cross-cutting geoframes aggregate through the atom layer", {
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
  expect_warning(
    out <- recast_geoscale(p, gs, "atom", "state", rule = "sum",
                           values = "capacity"),
    "missing from")
  # completion contract: the FULL state vocabulary per identifier group,
  # NA where no atoms carried data
  expect_equal(nrow(out), 2L * length(geoscale_regions(gs, "state")))
  expect_type(out$year, "integer")
  got <- out$capacity[out$state == "N1" & out$year == 2020]
  expect_equal(got, 4, tolerance = 1e-9)
  expect_true(all(is.na(out$capacity[out$state == "S1"])))
})

test_that("na_action controls partial coverage", {
  x2 <- rbind(cap, data.frame(atom = "ROW", capacity = 100))

  expect_warning(
    drop <- recast_geoscale(x2, gs, "atom", "country", rule = "sum"),
    "no code at geoframe"
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
  g <- geoscale_from_leaftable(df, geoframes = c("top", "mid", "leaf"))
  v <- data.frame(top = "T", capacity = 100)

  expect_warning(out <- recast_geoscale(v, g, "top", "mid", rule = "sum"),
                 "dropped")
  # Half the area is uncovered, so only half the value can be placed.
  expect_equal(sum(out$capacity), 50, tolerance = 1e-9)

  kept <- recast_geoscale(v, g, "top", "mid", rule = "sum", na_action = "keep")
  expect_equal(sum(kept$capacity), 100, tolerance = 1e-9)
})

test_that("unknown source codes warn and are dropped", {
  x <- rbind(cap, data.frame(atom = "NOPE", capacity = 9))
  expect_warning(out <- recast_geoscale(x, gs, "atom", "country", rule = "sum"),
                 "not present at geoframe")
  expect_equal(sum(out$capacity), sum(cap$capacity), tolerance = 1e-9)

  # a source region missing from `x` produces NA, with a warning
  x2 <- data.frame(atom = c("A1", "A2"), capacity = c(5, 9))
  expect_warning(out2 <- recast_geoscale(x2, gs, "atom", "country",
                                         rule = "sum"),
                 "missing from")
  expect_true(is.na(out2$capacity[out2$country == "S"]))
})

test_that("the copy rule requires constant values", {
  cc <- data.frame(atom = atoms, rate = rep(0.07, 6))
  out <- recast_geoscale(cc, gs, "atom", "country", rule = "copy")
  expect_equal(unique(out$rate), 0.07)

  cc$rate[1] <- 0.09
  expect_error(recast_geoscale(cc, gs, "atom", "country", rule = "copy"),
               "not constant")
})

test_that("bad geoframes and missing keys error clearly", {
  expect_error(recast_geoscale(cap, gs, "nope", "country"), "not a geoframe")
  expect_error(recast_geoscale(cap, gs, "atom", "nope"), "not a geoframe")
  expect_error(recast_geoscale(data.frame(v = 1), gs, "atom", "country"),
               "no column named")
})

# --- rule "share": share within parent --------------------------------------

test_that("rule share stays keyed at `from` and sums to 1 per parent", {
  out <- suppressWarnings(
    recast_geoscale(cap, gs, "atom", "country", rule = "share"))
  expect_named(out, c("atom", "capacity"))
  # atoms of N carry 1..4 (total 10), of S 5 and 6 (total 11)
  expect_equal(out$capacity[out$atom == "A1"], 0.1, tolerance = 1e-12)
  expect_equal(out$capacity[out$atom == "A6"], 6 / 11, tolerance = 1e-12)
  lt <- as.data.frame(geoscale_leaftable(gs))
  m <- merge(out, unique(lt[, c("atom", "country")]))
  sums <- tapply(m$capacity, m$country, sum)
  expect_equal(as.vector(sums), rep(1, length(sums)), tolerance = 1e-12)
  # full source vocabulary, ROW (no country) completed as NA
  expect_setequal(out$atom, S7::prop(gs, "members")$atom)
  expect_true(is.na(out$capacity[out$atom == "ROW"]))
})

test_that("rule share: parent= and to= are the same spelling", {
  a <- suppressWarnings(
    recast_geoscale(cap, gs, "atom", "country", rule = "share"))
  b <- suppressWarnings(
    recast_geoscale(cap, gs, "atom", "atom", rule = "share",
                    parent = "country"))
  expect_equal(a, b)
})

test_that("rule share: default parent is the geoframe above `from`", {
  out <- suppressWarnings(
    recast_geoscale(cap, gs, "atom", "atom", rule = "share"))
  # geoframes are country, state, zone, atom -> parent = zone
  lt <- as.data.frame(geoscale_leaftable(gs))
  m <- merge(out, unique(lt[, c("atom", "zone")]))
  m <- m[!is.na(m$zone) & !is.na(m$capacity), ]
  sums <- tapply(m$capacity, m$zone, sum)
  expect_equal(as.vector(sums), rep(1, length(sums)), tolerance = 1e-12)
})

test_that("rule share treats identifier columns as independent groups", {
  xp <- rbind(transform(cap, year = 2030),
              transform(cap, year = 2050, capacity = capacity * 2))
  out <- suppressWarnings(
    recast_geoscale(xp, gs, "atom", "country", rule = "share",
                    values = "capacity"))
  lt <- as.data.frame(geoscale_leaftable(gs))
  m <- merge(out, unique(lt[, c("atom", "country")]))
  sums <- tapply(m$capacity, list(m$year, m$country), sum)
  expect_equal(unname(as.vector(sums)), rep(1, length(sums)),
               tolerance = 1e-12)
})

test_that("rule share: a zero-total parent yields NA shares", {
  z <- transform(cap, capacity = ifelse(atom %in% c("A5", "A6"), 0, capacity))
  out <- suppressWarnings(
    recast_geoscale(z, gs, "atom", "country", rule = "share"))
  expect_true(all(is.na(out$capacity[out$atom %in% c("A5", "A6")])))
  expect_equal(out$capacity[out$atom == "A1"], 0.1, tolerance = 1e-12)
})

test_that("rule share: na_action keep groups the uncovered atoms", {
  cap2 <- rbind(cap, data.frame(atom = "ROW", capacity = 7))
  out <- recast_geoscale(cap2, gs, "atom", "country", rule = "share",
                         na_action = "keep")
  # ROW is alone in the NA-parent group, so its share is 1
  expect_equal(out$capacity[out$atom == "ROW"], 1)
})

test_that("rule share errors are specific", {
  x2 <- transform(cap, other = capacity)
  expect_error(
    recast_geoscale(x2, gs, "atom", "country",
                    rule = c(capacity = "share", other = "sum")),
    "cannot be mixed")
  expect_error(
    recast_geoscale(cap, gs, "atom", "country", rule = "sum",
                    parent = "country"),
    "applies to rule")
  expect_error(
    recast_geoscale(cap, gs, "atom", "state", rule = "share",
                    parent = "country"),
    "conflicting parents")
  # parent finer than from: every country straddles several states
  y <- data.frame(country = c("N", "S"), capacity = c(1, 2))
  expect_error(
    recast_geoscale(y, gs, "country", "state", rule = "share"),
    "coarser|nest")
  expect_error(
    suppressWarnings(recast_from_geoatoms(
      transform(cap, region = atom), gs, to = "country", rule = "share",
      values = "capacity")),
    "not supported")
})

test_that("rule share resolves from the registry", {
  register_geoscale_rule("cap_share_test", "share")
  on.exit(clear_geoscale_rules("cap_share_test"))
  x3 <- data.frame(atom = cap$atom, cap_share_test = cap$capacity)
  out <- suppressWarnings(
    recast_geoscale(x3, gs, "atom", "country"))
  expect_equal(out$cap_share_test[out$atom == "A1"], 0.1, tolerance = 1e-12)
})

test_that("the stack data fill computes shares per plane on the fly", {
  vals <- suppressWarnings(.geoscale_frame_shares(
    gs, geoscale_geoframes(gs),
    data.frame(atom = cap$atom, capacity = cap$capacity), "capacity"))
  lt <- as.data.frame(geoscale_leaftable(gs))
  # coarsest plane (country): shares of the grand total
  expect_equal(sum(vals$country$capacity, na.rm = TRUE), 1,
               tolerance = 1e-12)
  # state nests in country: sums to 1 per country
  m <- merge(vals$state, unique(lt[, c("state", "country")]))
  m <- m[!is.na(m$country) & !is.na(m$capacity), ]
  expect_equal(as.vector(tapply(m$capacity, m$country, sum)),
               c(1, 1), tolerance = 1e-12)
  # zone cross-cuts state AND country, so it falls back to the grand total
  expect_equal(sum(vals$zone$capacity, na.rm = TRUE), 1, tolerance = 1e-12)
  # atoms nest in zone: sums to 1 per zone
  m <- merge(vals$atom, unique(lt[, c("atom", "zone")]))
  m <- m[!is.na(m$zone) & !is.na(m$capacity), ]
  sums <- tapply(m$capacity, m$zone, sum)
  expect_equal(as.vector(sums), rep(1, length(sums)), tolerance = 1e-12)
})

test_that("rule logshare computes the same shares as share", {
  a <- suppressWarnings(
    recast_geoscale(cap, gs, "atom", "country", rule = "share"))
  b <- suppressWarnings(
    recast_geoscale(cap, gs, "atom", "country", rule = "logshare"))
  expect_equal(a, b)
})
