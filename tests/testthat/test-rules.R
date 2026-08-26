test_that("rules can be registered, read back and cleared", {
  clear_geoscale_rules()
  on.exit(clear_geoscale_rules(), add = TRUE)

  register_geoscale_rule("capacity", "sum")
  register_geoscale_rule("eff", "weighted_mean", weight = "pop")

  expect_equal(get_geoscale_rule("capacity")$rule, "sum")
  expect_equal(get_geoscale_rule("eff")$weight, "pop")
  expect_null(get_geoscale_rule("never_registered"))

  tbl <- list_geoscale_rules()
  expect_equal(tbl$param, c("capacity", "eff"))
  expect_true(is.na(tbl$weight[tbl$param == "capacity"]))

  clear_geoscale_rules("capacity")
  expect_null(get_geoscale_rule("capacity"))
})

test_that("an invalid rule name is rejected", {
  expect_error(register_geoscale_rule("x", "nonsense"), "arg")
})

test_that("recast_geoscale infers rules per column from the registry", {
  clear_geoscale_rules()
  on.exit(clear_geoscale_rules(), add = TRUE)
  register_geoscale_rule("capacity", "sum")
  register_geoscale_rule("eff", "weighted_mean", weight = "pop")

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
  clear_geoscale_rules()
  on.exit(clear_geoscale_rules(), add = TRUE)
  register_geoscale_rule("capacity", "sum")

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
  clear_geoscale_rules()
  on.exit(clear_geoscale_rules(), add = TRUE)
  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2"), whatever = c(1, 3))
  expect_error(recast_geoscale(x, gs, "atom", "state"),
               "no aggregation rule.*whatever.*register_geoscale_rule")
  # registering the column (or passing rule=) resolves it
  register_geoscale_rule("whatever", "sum")
  out <- suppressWarnings(recast_geoscale(x, gs, "atom", "state"))
  expect_equal(out$whatever[out$state == "N1"], 4, tolerance = 1e-9)
})

test_that("the rule and geoframe constants are pinned", {
  expect_identical(GEOSCALE_RULES,
                   c("sum", "weighted_mean", "mean", "copy", "sd"))
  # same rule SET as the sibling (element order is presentation only)
  if (requireNamespace("timescales", quietly = TRUE)) {
    expect_setequal(GEOSCALE_RULES, timescales::CALENDAR_RULES)
  }
  expect_identical(CORE_GEOFRAMES,
                   c("GLOBE", "CONTINENT", "COUNTRY", "STATE", "ZONE",
                     "CELL"))
})
