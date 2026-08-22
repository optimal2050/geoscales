gs <- geoscale_example()

test_that("navigation requires an explicit geoframe", {
  # "N1" exists at both `state` and `zone`; the answers must differ.
  expect_equal(geoscale_children(gs, "state", "N1"), "N1")
  expect_setequal(geoscale_children(gs, "zone", "N1"), c("A1", "A2"))
  expect_error(geoscale_children(gs, "nope", "N1"), "not a geoframe")
  expect_error(geoscale_children(gs, "state", "GHOST"), "not found at geoframe")
})

test_that("children and parents step one geoframe", {
  expect_equal(geoscale_children(gs, "country", "N"), c("N1", "N2"))
  expect_equal(geoscale_parents(gs, "state", "N1", to = "country"), "N")
  expect_error(geoscale_children(gs, "atom", "A1"), "finest geoframe")
  expect_error(geoscale_parents(gs, "country", "N"), "coarsest geoframe")
})

test_that("descendants and ancestors are geoframe-tagged", {
  d <- geoscale_descendants(gs, "country", "N")
  expect_named(d, c("geoframe", "region"))
  # A5 belongs to country S and must not appear
  expect_false("A5" %in% d$region[d$geoframe == "atom"])
  expect_setequal(d$region[d$geoframe == "atom"], c("A1", "A2", "A3", "A4"))

  a <- geoscale_ancestors(gs, "atom", "A5")
  expect_equal(a$region[a$geoframe == "country"], "S")
})

test_that("geoscale_nests detects cross-cutting geoframes", {
  expect_true(geoscale_nests(gs, "country", "state"))
  z <- geoscale_nests(gs, "state", "zone")
  expect_false(z)
  expect_equal(attr(z, "offenders"), "ZB")
})

test_that("ancestry is atom-mediated, not a transitive closure", {
  anc <- geoscale_ancestry(gs)
  ca <- anc[anc$parent_geoframe == "country" & anc$child_geoframe == "atom", ]
  # A closure through the straddling zone ZB would wrongly give N -> A5
  expect_setequal(ca$child[ca$parent == "N"], c("A1", "A2", "A3", "A4"))
  expect_setequal(ca$child[ca$parent == "S"], c("A5", "A6"))
})

test_that("geoscale_family reports the observed mapping", {
  fam <- geoscale_family(gs, "state", "zone")
  expect_named(fam, c("parent_geoframe", "parent", "child_geoframe", "child"))
  expect_equal(nrow(fam), 4L)
  expect_setequal(fam$parent[fam$child == "ZB"], c("N2", "S1"))
})

test_that("filter_geoscale and `[` subset consistently", {
  a <- filter_geoscale(gs, "country", "N")
  b <- gs["country", "N"]
  expect_equal(nrow(S7::prop(a, "leaftable")), 4L)
  expect_equal(S7::prop(a, "leaftable"), S7::prop(b, "leaftable"))
  expect_equal(geoscale_regions(a, "country"), "N")
  expect_error(gs["country"], "gs\\[geoframe, region\\]")
})

test_that("prune_geoscale collapses to a coarser geoframe and sums weights", {
  p <- prune_geoscale(gs, "state")
  expect_equal(S7::prop(p, "geoframes"), c("country", "state"))
  lf <- S7::prop(p, "leaftable")
  expect_equal(nrow(lf), 3L)              # ROW has no state code
  expect_equal(lf$km2[lf$state == "N1"], 300)
  expect_equal(lf$pop[lf$state == "N1"], 100)
})

test_that("geoscale_share normalises overall and within a parent", {
  s <- geoscale_share(gs, "state", weight = "km2")
  expect_equal(sum(s$share), 1, tolerance = 1e-9)

  w <- geoscale_share(gs, "state", weight = "km2", within = "country")
  expect_equal(w$share[w$state == "N1"], 0.3, tolerance = 1e-9)
  expect_equal(w$share[w$state == "N2"], 0.7, tolerance = 1e-9)
  expect_equal(w$share[w$state == "S1"], 1.0, tolerance = 1e-9)
})

test_that("an unknown weight is rejected", {
  expect_error(geoscale_share(gs, "state", weight = "nope"), "not a weight column")
})
