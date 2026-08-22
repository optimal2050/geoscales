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

# Sample bookkeeping (coverage / parent_totals / name mangling) ----------------

test_that("filter_geoscale book-keeps the sample", {
  gs <- geoscale_example()
  n <- filter_geoscale(gs, "country", "N")
  m <- S7::prop(n, "meta")
  expect_equal(m$name, "example[country:N]")
  expect_equal(m$parent_name, "example")
  # km2: N atoms 100+200+300+400 of 3100; pop: 200 of 300
  expect_equal(m$coverage[["km2"]], 1000 / 3100)
  expect_equal(m$coverage[["pop"]], 200 / 300)
  expect_equal(m$parent_totals[["km2"]], 3100)
  expect_equal(geoscale_coverage(n, "km2"), 1000 / 3100)
  expect_equal(geoscale_coverage(gs), c(km2 = 1, pop = 1))
})

test_that("filter-of-filter composes against the root parent", {
  gs <- geoscale_example()
  n  <- filter_geoscale(gs, "country", "N")
  n1 <- filter_geoscale(n, "state", "N1")
  m <- S7::prop(n1, "meta")
  expect_equal(m$parent_name, "example")
  expect_equal(m$name, "example[state:N1]")
  expect_equal(m$coverage[["km2"]], 300 / 3100)   # A1+A2 of the ROOT total
})

test_that("a no-op filter is a true no-op", {
  gs <- geoscale_example()
  all_countries <- geoscale_regions(gs, "atom")
  same <- filter_geoscale(gs, "atom", all_countries)
  m <- S7::prop(same, "meta")
  expect_equal(m$name, "example")
  expect_null(m$coverage)
  expect_equal(geoscale_coverage(same), c(km2 = 1, pop = 1))
})

test_that("the validator rejects tampered coverage", {
  gs <- geoscale_example()
  n <- filter_geoscale(gs, "country", "N")
  m <- S7::prop(n, "meta")
  m$coverage[["km2"]] <- 0.9
  expect_error(
    Geoscale(leaftable = S7::prop(n, "leaftable"),
             geoframes = S7::prop(n, "geoframes"),
             members   = S7::prop(n, "members"),
             meta      = m),
    "does not match the leaftable")
  m2 <- S7::prop(n, "meta")
  m2$coverage[["km2"]] <- 1.7
  expect_error(
    Geoscale(leaftable = S7::prop(n, "leaftable"),
             geoframes = S7::prop(n, "geoframes"),
             members   = S7::prop(n, "members"),
             meta      = m2),
    "lie in", fixed = TRUE)
})

test_that("prune_geoscale preserves meta, mangles the name, records NA loss", {
  gs <- geoscale_example()
  p <- prune_geoscale(gs, "state")
  m <- S7::prop(p, "meta")
  expect_equal(m$name, "example@state")
  expect_equal(m$parent_name, "example")
  expect_equal(m$desc, S7::prop(gs, "meta")$desc)   # meta preserved
  # ROW (NA at state) dropped: 2100 of 3100 km2 survive
  expect_equal(m$coverage[["km2"]], 2100 / 3100)
  expect_equal(geoscale_coverage(p, "pop"), 300 / 300)
})

test_that("prune_geoscale dissolves geometry when attached", {
  skip_if_not_installed("sf")
  gs <- geoscale_example()
  sq <- function(x0) sf::st_polygon(list(cbind(
    c(x0, x0 + 1, x0 + 1, x0, x0), c(0, 0, 1, 1, 0))))
  gs <- attach_geometry_geoscale(gs, sf::st_sfc(
    sq(0), sq(1), sq(2), sq(3), sq(4), sq(5), sq(6)))
  p <- prune_geoscale(gs, "state")
  g <- S7::prop(p, "geometry")
  expect_false(is.null(g))
  expect_equal(length(g), nrow(S7::prop(p, "leaftable")))
  # N1 = union of two unit squares = area 2
  lt <- S7::prop(p, "leaftable")
  a <- as.numeric(sf::st_area(g[lt$region == "N1"]))
  expect_equal(a, 2)
  # opt-out drops it
  p0 <- prune_geoscale(gs, "state", keep_geometry = FALSE)
  expect_null(S7::prop(p0, "geometry"))
})

test_that("two samples of one parent no longer collide in the map registry", {
  clear_geo_maps()
  gs <- geoscale_example()
  n <- filter_geoscale(gs, "country", "N")
  s <- filter_geoscale(gs, "country", "S")
  expect_false(S7::prop(n, "meta")$name == S7::prop(s, "meta")$name)
  m_n <- geoscale_map("state", "country", gs = n)
  register_geo_map("state", "country", m_n, gs = n)
  # the registration is scoped to n's mangled name; s does not see it
  expect_null(get_geo_map("state", "country", gs = s))
  clear_geo_maps()
})
