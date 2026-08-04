gs <- geoscale_example()

test_that("navigation requires an explicit level", {
  # "N1" exists at both `state` and `zone`; the answers must differ.
  expect_equal(geo_children(gs, "state", "N1"), "N1")
  expect_setequal(geo_children(gs, "zone", "N1"), c("A1", "A2"))
  expect_error(geo_children(gs, "nope", "N1"), "not a level")
  expect_error(geo_children(gs, "state", "GHOST"), "not found at level")
})

test_that("children and parents step one level", {
  expect_equal(geo_children(gs, "country", "N"), c("N1", "N2"))
  expect_equal(geo_parents(gs, "state", "N1", to = "country"), "N")
  expect_error(geo_children(gs, "atom", "A1"), "finest level")
  expect_error(geo_parents(gs, "country", "N"), "coarsest level")
})

test_that("descendants and ancestors are level-tagged", {
  d <- geo_descendants(gs, "country", "N")
  expect_named(d, c("level", "region"))
  # A5 belongs to country S and must not appear
  expect_false("A5" %in% d$region[d$level == "atom"])
  expect_setequal(d$region[d$level == "atom"], c("A1", "A2", "A3", "A4"))

  a <- geo_ancestors(gs, "atom", "A5")
  expect_equal(a$region[a$level == "country"], "S")
})

test_that("geo_nests detects cross-cutting levels", {
  expect_true(geo_nests(gs, "country", "state"))
  z <- geo_nests(gs, "state", "zone")
  expect_false(z)
  expect_equal(attr(z, "offenders"), "ZB")
})

test_that("ancestry is atom-mediated, not a transitive closure", {
  anc <- geo_ancestry(gs)
  ca <- anc[anc$parent_level == "country" & anc$child_level == "atom", ]
  # A closure through the straddling zone ZB would wrongly give N -> A5
  expect_setequal(ca$child[ca$parent == "N"], c("A1", "A2", "A3", "A4"))
  expect_setequal(ca$child[ca$parent == "S"], c("A5", "A6"))
})

test_that("geo_family reports the observed mapping", {
  fam <- geo_family(gs, "state", "zone")
  expect_named(fam, c("parent_level", "parent", "child_level", "child"))
  expect_equal(nrow(fam), 4L)
  expect_setequal(fam$parent[fam$child == "ZB"], c("N2", "S1"))
})

test_that("geo_filter and `[` subset consistently", {
  a <- geo_filter(gs, "country", "N")
  b <- gs["country", "N"]
  expect_equal(nrow(S7::prop(a, "leaves")), 4L)
  expect_equal(S7::prop(a, "leaves"), S7::prop(b, "leaves"))
  expect_equal(geo_regions(a, "country"), "N")
  expect_error(gs["country"], "gs\\[level, region\\]")
})

test_that("geo_prune collapses to a coarser level and sums weights", {
  p <- geo_prune(gs, "state")
  expect_equal(S7::prop(p, "levels"), c("country", "state"))
  lf <- S7::prop(p, "leaves")
  expect_equal(nrow(lf), 3L)              # ROW has no state code
  expect_equal(lf$km2[lf$state == "N1"], 300)
  expect_equal(lf$pop[lf$state == "N1"], 100)
})

test_that("geo_share normalises overall and within a parent", {
  s <- geo_share(gs, "state", weight = "km2")
  expect_equal(sum(s$share), 1, tolerance = 1e-9)

  w <- geo_share(gs, "state", weight = "km2", within = "country")
  expect_equal(w$share[w$state == "N1"], 0.3, tolerance = 1e-9)
  expect_equal(w$share[w$state == "N2"], 0.7, tolerance = 1e-9)
  expect_equal(w$share[w$state == "S1"], 1.0, tolerance = 1e-9)
})

test_that("an unknown weight is rejected", {
  expect_error(geo_share(gs, "state", weight = "nope"), "not a weight column")
})
