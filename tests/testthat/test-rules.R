test_that("rules can be registered, read back and cleared", {
  geo_clear_rules()
  on.exit(geo_clear_rules(), add = TRUE)

  geo_register_rule("capacity", "sum")
  geo_register_rule("eff", "weighted_mean", weight = "pop")

  expect_equal(geo_get_rule("capacity")$rule, "sum")
  expect_equal(geo_get_rule("eff")$weight, "pop")
  expect_null(geo_get_rule("never_registered"))

  tbl <- geo_list_rules()
  expect_equal(tbl$param, c("capacity", "eff"))
  expect_true(is.na(tbl$weight[tbl$param == "capacity"]))

  geo_clear_rules("capacity")
  expect_null(geo_get_rule("capacity"))
})

test_that("an invalid rule name is rejected", {
  expect_error(geo_register_rule("x", "nonsense"), "arg")
})

test_that("geo_recast infers rules per column from the registry", {
  geo_clear_rules()
  on.exit(geo_clear_rules(), add = TRUE)
  geo_register_rule("capacity", "sum")
  geo_register_rule("eff", "weighted_mean", weight = "pop")

  gs <- geoscale_example()
  mix <- data.frame(
    atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
    capacity = c(1, 2, 3, 4, 5, 6),
    eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6)
  )
  out <- geo_recast(mix, gs, "atom", "state")

  # capacity summed, eff population-weighted, in the same call
  expect_equal(out$capacity[out$state == "N1"], 3, tolerance = 1e-9)
  expect_equal(out$eff[out$state == "N1"], 0.39, tolerance = 1e-9)
})

test_that("an explicit rule overrides the registry", {
  geo_clear_rules()
  on.exit(geo_clear_rules(), add = TRUE)
  geo_register_rule("capacity", "sum")

  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2"), capacity = c(1, 3))
  out <- geo_recast(x, gs, "atom", "state", rule = "mean")
  expect_equal(out$capacity[out$state == "N1"], 2, tolerance = 1e-9)
})

test_that("unregistered columns default to sum", {
  geo_clear_rules()
  on.exit(geo_clear_rules(), add = TRUE)
  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2"), whatever = c(1, 3))
  out <- geo_recast(x, gs, "atom", "state")
  expect_equal(out$whatever, 4, tolerance = 1e-9)
})
