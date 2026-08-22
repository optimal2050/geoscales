test_that("rules can be registered, read back and cleared", {
  clear_geo_rules()
  on.exit(clear_geo_rules(), add = TRUE)

  register_geo_rule("capacity", "sum")
  register_geo_rule("eff", "weighted_mean", weight = "pop")

  expect_equal(get_geo_rule("capacity")$rule, "sum")
  expect_equal(get_geo_rule("eff")$weight, "pop")
  expect_null(get_geo_rule("never_registered"))

  tbl <- list_geo_rules()
  expect_equal(tbl$param, c("capacity", "eff"))
  expect_true(is.na(tbl$weight[tbl$param == "capacity"]))

  clear_geo_rules("capacity")
  expect_null(get_geo_rule("capacity"))
})

test_that("an invalid rule name is rejected", {
  expect_error(register_geo_rule("x", "nonsense"), "arg")
})

test_that("recast_geoscale infers rules per column from the registry", {
  clear_geo_rules()
  on.exit(clear_geo_rules(), add = TRUE)
  register_geo_rule("capacity", "sum")
  register_geo_rule("eff", "weighted_mean", weight = "pop")

  gs <- geoscale_example()
  mix <- data.frame(
    atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
    capacity = c(1, 2, 3, 4, 5, 6),
    eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6)
  )
  out <- recast_geoscale(mix, gs, "atom", "state")

  # capacity summed, eff population-weighted, in the same call
  expect_equal(out$capacity[out$state == "N1"], 3, tolerance = 1e-9)
  expect_equal(out$eff[out$state == "N1"], 0.39, tolerance = 1e-9)
})

test_that("an explicit rule overrides the registry", {
  clear_geo_rules()
  on.exit(clear_geo_rules(), add = TRUE)
  register_geo_rule("capacity", "sum")

  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2"), capacity = c(1, 3))
  # A1/A2 cover only state N1; the other states' missing-source warning
  # is expected here
  expect_warning(
    out <- recast_geoscale(x, gs, "atom", "state", rule = "mean"),
    "missing from")
  expect_equal(out$capacity[out$state == "N1"], 2, tolerance = 1e-9)
})

test_that("unregistered columns error: no rule fallback", {
  clear_geo_rules()
  on.exit(clear_geo_rules(), add = TRUE)
  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2"), whatever = c(1, 3))
  expect_error(recast_geoscale(x, gs, "atom", "state"),
               "no aggregation rule.*whatever.*register_geo_rule")
  # registering the column (or passing rule=) resolves it
  register_geo_rule("whatever", "sum")
  out <- suppressWarnings(recast_geoscale(x, gs, "atom", "state"))
  expect_equal(out$whatever[out$state == "N1"], 4, tolerance = 1e-9)
})
