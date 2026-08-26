# =========================================================================== #
# Property sweep: the invariant contracts of recast/join over the rule x
# direction x na_action grid (helper-invariants.R states the contracts,
# helper-fixtures.R the fixtures). One-off regression tests stay in their
# topic files; THIS file is the systematic net.
# =========================================================================== #

# ---- recast: conservation / envelope grid --------------------------------- #

# @covers recast_geoscale depth=P
test_that("sum conserves and completes across the direction grid", {
  gs <- geoscale_example()
  x <- fx_tbl(gs, ids = c("A", "B"))
  up <- recast_geoscale(x, gs, "atom", "country", rule = "sum")
  expect_conserves(x, up, "cap", by = "id")
  expect_completion(up, geoscale_regions(gs, "country"), "country")

  # cross-cutting geoframes route through the atoms and still conserve
  st <- recast_geoscale(fx_tbl(gs), gs, "atom", "state", rule = "sum")
  cross <- recast_geoscale(st, gs, "state", "zone", rule = "sum",
                           weight = "km2")
  expect_conserves(st, cross, "cap")
  expect_completion(cross, geoscale_regions(gs, "zone"), "zone")

  # identity "recast" is refused, not silently returned
  expect_error(recast_geoscale(fx_tbl(gs), gs, "atom", "atom",
                               rule = "sum"))
})

# @covers recast_geoscale depth=P
test_that("sum round-trips down-then-up per id group", {
  gs <- geoscale_example()
  x_c <- data.frame(country = rep(c("N", "S"), 2),
                    cap = c(120, 60, 80, 40),
                    id = rep(c("A", "B"), each = 2))
  down <- recast_geoscale(x_c, gs, "country", "state", rule = "sum",
                          weight = "km2")
  back <- recast_geoscale(down, gs, "state", "country", rule = "sum")
  expect_round_trip(x_c, back, "cap", key = c("id", "country"))
})

# @covers recast_geoscale depth=P
test_that("mean and weighted_mean stay in the envelope; weighting matters", {
  gs <- geoscale_example()          # km2 100..600: very unequal weights
  x <- fx_tbl(gs, values = list(v = c(10, 2, 7, 100, 3, 8)))
  for (r in c("mean", "weighted_mean")) {
    up <- recast_geoscale(x, gs, "atom", "country", rule = r,
                          weight = "km2")
    expect_within_envelope(x, up, "v")
  }
  wm <- recast_geoscale(x, gs, "atom", "country", rule = "weighted_mean",
                        weight = "km2")
  mn <- recast_geoscale(x, gs, "atom", "country", rule = "mean")
  expect_weighting_matters(wm, mn, "v")
})

# @covers recast_geoscale depth=P
test_that("copy carries constants and rejects non-constants; sd aggregates", {
  gs <- geoscale_example()
  x <- fx_tbl(gs, values = list(flag = 7))
  up <- recast_geoscale(x, gs, "atom", "country", rule = "copy")
  expect_true(all(as.data.frame(up)$flag == 7))
  x2 <- fx_tbl(gs)
  expect_error(recast_geoscale(x2, gs, "atom", "country", rule = "copy"),
               "copy")
  sd_up <- recast_geoscale(x2, gs, "atom", "country", rule = "sd")
  expect_true(all(as.data.frame(sd_up)$cap >= 0))
})

# @covers recast_geoscale depth=P
test_that("na_action grid behaves identically for every aggregating rule", {
  gs <- geoscale_example()
  x <- rbind(fx_tbl(gs, values = list(v = 1)),
             data.frame(atom = "ROW", v = 1))     # uncovered at country
  for (r in c("sum", "mean", "weighted_mean")) {
    expect_warning(
      dropped <- recast_geoscale(x, gs, "atom", "country", rule = r,
                                 weight = "km2"),
      "no code at geoframe")
    expect_false(anyNA(as.data.frame(dropped)$country))
    expect_error(
      recast_geoscale(x, gs, "atom", "country", rule = r, weight = "km2",
                      na_action = "error"),
      "na_action")
    kept <- recast_geoscale(x, gs, "atom", "country", rule = r,
                            weight = "km2", na_action = "keep")
    expect_true(anyNA(as.data.frame(kept)$country))
    if (r == "sum") expect_conserves(x, kept, "v")
  }
  # a MISSING SOURCE region is the other path: NA values + a warning
  x2 <- fx_tbl(gs); x2 <- x2[x2$atom != "A1", ]
  for (r in c("sum", "mean", "weighted_mean")) {
    expect_warning(
      out <- recast_geoscale(x2, gs, "atom", "state", rule = r,
                             weight = "km2"),
      "missing from")
    out <- as.data.frame(out)
    expect_true(is.na(out$cap[out$state == "N1"]))
    expect_false(anyNA(out$cap[out$state != "N1"]))
  }
})

# ---- routes: composition identity ----------------------------------------- #

# @covers recast_to_geoatoms recast_from_geoatoms depth=P
test_that("geoatoms composition equals the fused recast, per rule, with ids", {
  gs <- geoscale_example()
  x <- data.frame(country = rep(c("N", "S"), 2),
                  cap = c(120, 60, 80, 40), level = 5,
                  id = rep(c("A", "B"), each = 2))
  for (r in c("sum", "mean", "weighted_mean")) {
    base <- recast_to_geoatoms(x, gs, from = "country", rule = r,
                               weight = "km2")
    via <- recast_from_geoatoms(base, gs, to = "state", rule = r,
                                values = c("cap", "level"))
    fused <- recast_geoscale(x, gs, "country", "state", rule = r,
                             weight = "km2")
    expect_composition_identity(via, fused, c("cap", "level"),
                                key = c("id", "state"))
  }
  # attach_weight = FALSE still composes for sum
  base0 <- recast_to_geoatoms(x, gs, from = "country", rule = "sum",
                              weight = "km2", attach_weight = FALSE)
  expect_false("weight" %in% names(base0))
  via0 <- recast_from_geoatoms(base0, gs, to = "state", rule = "sum",
                               values = c("cap", "level"))
  fused0 <- recast_geoscale(x, gs, "country", "state", rule = "sum",
                            weight = "km2")
  expect_composition_identity(via0, fused0, c("cap", "level"),
                              key = c("id", "state"))
})

# ---- join: the contract over key modes ------------------------------------ #

# @covers join_geoscale depth=P
test_that("join contract holds across key modes and options", {
  gs <- geoscale_example()
  # existing <name> column mode (the timescales twin of this test exists;
  # this is the geoscales side of the mirror)
  x <- fx_tbl(gs)
  names(x)[1] <- "example"
  j1 <- expect_join_contract(
    x, join_geoscale(x, gs, geoframe = "atom", meta = TRUE), "example")
  expect_true(any(startsWith(names(j1), "example.")))

  x2 <- fx_tbl(gs)                            # inferred atom-column mode
  j2 <- join_geoscale(x2, gs, meta = TRUE, weight = "km2")
  expect_join_contract(x2, j2, "example")

  # explicit key that is not a geoframe name
  x3 <- data.frame(cell = fx_tbl(gs)$atom, v = 1:6)
  j3 <- join_geoscale(x3, gs, key = "cell", geoframe = "atom",
                      geoframes = "country")
  expect_join_contract(x3, j3, "example")

  # as_factor governs the requested membership columns
  jf <- join_geoscale(x2, gs, geoframes = "country", as_factor = TRUE)
  expect_s3_class(jf$example.country, "factor")
  jc <- join_geoscale(x2, gs, geoframes = "country", as_factor = FALSE)
  expect_type(jc$example.country, "character")
})

# @covers join_geoscale depth=P
test_that("join edge shapes: duplicate keys, NA keys, idempotence", {
  gs <- geoscale_example()
  dup <- fx_tbl(gs)[c(1, 1, 2), ]
  expect_join_contract(dup, join_geoscale(dup, gs, geoframe = "atom"),
                       "example")

  nax <- fx_tbl(gs)
  nax$atom[1] <- NA_character_
  jn <- suppressWarnings(join_geoscale(nax, gs, geoframe = "atom"))
  expect_identical(nrow(jn), nrow(nax))
  expect_true(is.na(jn$example[1]))

  # a repeated bare join reuses the existing <name> column (a no-op);
  # re-adding the same derived columns refuses to overwrite
  x <- fx_tbl(gs)
  j1 <- join_geoscale(x, gs, geoframe = "atom")
  expect_identical(join_geoscale(j1, gs, geoframe = "atom"), j1)
  jm <- join_geoscale(x, gs, geoframe = "atom", meta = TRUE)
  expect_error(join_geoscale(jm, gs, geoframe = "atom", meta = TRUE),
               "overwrit|exist|collid")
})

# ---- parity sync: axes previously tested on one sibling only -------------- #

# @covers recast_geoscale recast_from_geoatoms depth=P
test_that("values auto-detection and from_geoatoms na_action", {
  gs <- geoscale_example()
  # auto-detection picks every numeric non-key column, and only those
  x <- fx_tbl(gs, values = list(cap = NULL, v2 = 3))
  x$note <- "a"                                # character: never a value
  out <- as.data.frame(recast_geoscale(x, gs, "atom", "country",
                                       rule = "sum"))
  expect_true(all(c("cap", "v2") %in% names(out)))
  expect_conserves(x, out, c("cap", "v2"))

  # from_geoatoms with a missing atom: PARTIAL aggregate, silently --
  # unlike the fused verb, which warns and yields NA for a missing
  # source. Pinned as-is 2026-08-25 (it is what a deliberately filtered
  # atom set needs, e.g. spatial sampling); FLAGGED to the maintainer as
  # a route-vs-fused asymmetry to rule on.
  base <- recast_to_geoatoms(
    data.frame(country = c("N", "S"), cap = c(120, 60)),
    gs, from = "country", rule = "sum", weight = "km2")
  base1 <- base[base$region != "A1", ]
  for (na in c("drop", "keep")) {
    got <- as.data.frame(
      recast_from_geoatoms(base1, gs, to = "state", rule = "sum",
                           values = "cap", na_action = na))
    expect_false(anyNA(got$cap))
    expect_equal(got$cap[got$state == "N1"],
                 base$cap[base$region == "A2"], tolerance = 1e-9)
  }
})
