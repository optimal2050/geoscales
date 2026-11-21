leaves <- function(x) {
  as.character(geoscale_leaftable(x)[[geoscale_leaf_column(x)]])
}

test_that("a weight is declared over the leaves and can become the default", {
  gs <- geoscale_example()
  a <- leaves(gs)
  pop <- stats::setNames(seq_along(a) * 10, a)
  g2 <- geoscale_add_weight(gs, population = pop, default = "population")
  expect_true("population" %in% geoscale_weights(g2))
  expect_equal(S7::prop(g2, "meta")$default_weight, "population")
  expect_equal(as.data.frame(g2)$population, unname(pop))
  # the share now follows the new weight, not the old default
  s <- geoscale_share(g2, "state")
  expect_equal(sum(s$share), 1)
  # the original is untouched
  expect_false("population" %in% geoscale_weights(gs))
})

test_that("a named weight is matched by leaf code, not by position", {
  gs <- geoscale_example()
  a <- leaves(gs)
  pop <- stats::setNames(seq_along(a) * 10, a)
  g2 <- geoscale_add_weight(gs, population = pop[rev(seq_along(pop))])
  expect_equal(as.data.frame(g2)$population, unname(pop))
})

test_that("a data.frame keyed by the leaf column carries several weights", {
  gs <- geoscale_example()
  a <- leaves(gs)
  g2 <- geoscale_add_weight(
    gs, data.frame(cell = a, gdp = seq_along(a), pop2 = seq_along(a) * 2))
  expect_true(all(c("gdp", "pop2") %in% geoscale_weights(g2)))
})

test_that("an existing weight is kept unless overwrite is asked for", {
  gs <- geoscale_example()
  a <- leaves(gs)
  expect_error(geoscale_add_weight(gs, km2 = rep(1, length(a))),
               "already declared")
  g2 <- geoscale_add_weight(gs, km2 = rep(1, length(a)), overwrite = TRUE)
  expect_equal(unique(as.data.frame(g2)$km2), 1)
})

test_that("a weight that cannot be used is refused, naming it", {
  gs <- geoscale_example()
  a <- leaves(gs)
  v <- stats::setNames(seq_along(a), a)
  expect_error(geoscale_add_weight(gs, population = v[1:2]), "no value for")
  expect_error(geoscale_add_weight(gs, population = unname(v)[1:2]),
               "one value per leaftable row")
  expect_error(geoscale_add_weight(gs, pop2 = -v), "must be >= 0")
  expect_error(geoscale_add_weight(gs, pop2 = v * 0), "sums to zero")
  expect_error(geoscale_add_weight(gs, zone = v), "not a weight")
  expect_error(geoscale_add_weight(gs, seq_along(a)), "must be named")
  expect_error(geoscale_add_weight(gs, population = v, default = "nope"),
               "must be one of the declared weights")
  expect_error(geoscale_add_weight(gs), "no weight given")
})

test_that("a scalar weight is spread over every leaf", {
  gs <- geoscale_example()
  g2 <- geoscale_add_weight(gs, flat = 1)
  expect_equal(unique(as.data.frame(g2)$flat), 1)
})
