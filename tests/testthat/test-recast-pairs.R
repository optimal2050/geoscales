gs <- geoscale_example()

# A1,A2 -> state N1; A3,A4 -> N2; A5,A6 -> S1
lines <- data.frame(
  src = c("A1", "A3", "A1"),
  dst = c("A2", "A5", "A5"),
  capacity = c(100, 200, 300)
)

test_that("pairs inside one target region are dropped as internal", {
  expect_warning(out <- recast_pairs(lines, gs, to = "state", rule = "sum"),
                 "internal")
  expect_equal(nrow(out), 2L)
  expect_false(any(out$src == out$dst))
  expect_equal(sum(out$capacity), 500)
})

test_that("drop_internal = FALSE keeps them as self-pairs", {
  out <- recast_pairs(lines, gs, to = "state", rule = "sum",
                      drop_internal = FALSE)
  expect_equal(nrow(out), 3L)
  expect_equal(out$capacity[out$src == "N1" & out$dst == "N1"], 100)
  expect_equal(sum(out$capacity), sum(lines$capacity))
})

test_that("parallel corridors between the same pair merge", {
  x <- data.frame(src = c("A1", "A2"), dst = c("A5", "A6"),
                  capacity = c(10, 20))
  out <- recast_pairs(x, gs, to = "state", rule = "sum")
  expect_equal(nrow(out), 1L)
  expect_equal(out$capacity, 30)
})

test_that("directed = FALSE merges the two orientations", {
  x <- data.frame(src = c("A1", "A5"), dst = c("A5", "A1"),
                  capacity = c(10, 20))
  expect_equal(nrow(recast_pairs(x, gs, to = "state", rule = "sum")), 2L)
  out <- recast_pairs(x, gs, to = "state", rule = "sum", directed = FALSE)
  expect_equal(nrow(out), 1L)
  expect_equal(out$capacity, 30)
})

test_that("identifier columns are preserved as groups", {
  x <- data.frame(src = "A1", dst = c("A5", "A5"), year = c(2030, 2050),
                  capacity = c(10, 20))
  out <- recast_pairs(x, gs, to = "state", rule = "sum", values = "capacity")
  expect_equal(nrow(out), 2L)
  expect_equal(out$capacity[out$year == 2050], 20)
})

test_that("weighted_mean uses a named column of x", {
  x <- data.frame(src = c("A1", "A2"), dst = c("A5", "A6"),
                  loss = c(0.1, 0.5), cap = c(300, 100))
  out <- recast_pairs(x, gs, to = "state", rule = "weighted_mean",
                      weight = "cap", values = "loss")
  expect_equal(out$loss, (0.1 * 300 + 0.5 * 100) / 400, tolerance = 1e-9)
})

test_that("a zero-weight group falls back to a plain mean", {
  x <- data.frame(src = c("A1", "A2"), dst = c("A5", "A6"),
                  loss = c(0.1, 0.5), cap = c(0, 0))
  out <- recast_pairs(x, gs, to = "state", rule = "weighted_mean",
                      weight = "cap", values = "loss")
  expect_equal(out$loss, 0.3, tolerance = 1e-9)
  expect_false(is.nan(out$loss))
})

test_that("a finer target is refused", {
  expect_error(recast_pairs(lines, gs, to = "atom", from = "state"),
               "aggregate only")
})

test_that("unknown endpoint codes warn and their pairs drop", {
  x <- data.frame(src = c("A1", "ZZ"), dst = c("A5", "A5"),
                  capacity = c(10, 20))
  expect_warning(out <- recast_pairs(x, gs, to = "state", rule = "sum"),
                 "not present at geoframe")
  expect_equal(nrow(out), 1L)
  expect_equal(out$capacity, 10)
})

test_that("missing endpoint columns are named in the error", {
  expect_error(recast_pairs(lines, gs, to = "state", src = "from_bus"),
               "from_bus")
  expect_error(recast_pairs(lines, gs, to = "state", src = "a", dst = "a"),
               "must differ")
})

test_that("recast_from_geoatoms weights by a named column of x", {
  d <- data.frame(region = c("A1", "A2", "A3", "A4"),
                  eff = c(0.9, 0.5, 0.8, 0.4),
                  cap = c(100, 0, 100, 0))
  out <- recast_from_geoatoms(d, gs, to = "state", rule = "weighted_mean",
                              weight = "cap", values = "eff")
  # N1 takes A1's value because A2 carries no capacity, not the 0.7 mean
  expect_equal(out$eff[out$state == "N1"], 0.9, tolerance = 1e-9)
  expect_equal(out$eff[out$state == "N2"], 0.8, tolerance = 1e-9)
})

test_that("a named weight column that x lacks is an error", {
  d <- data.frame(region = "A1", eff = 0.9)
  expect_error(recast_from_geoatoms(d, gs, to = "state", weight = "cap"),
               "no column named")
})

test_that("na_rm reads NA as silence, not as an unknown", {
  d <- data.frame(region = c("A1", "A2", "A3", "A4"),
                  cap = c(100, NA, NA, NA),
                  eff = c(0.9, NA, NA, NA),
                  w = c(10, 20, 0, 0))
  rl <- c(cap = "sum", eff = "weighted_mean")
  poisoned <- recast_from_geoatoms(d, gs, to = "state",
                                   values = c("cap", "eff"), rule = rl,
                                   weight = "w")
  expect_true(is.na(poisoned$cap[poisoned$state == "N1"]))

  out <- recast_from_geoatoms(d, gs, to = "state", values = c("cap", "eff"),
                              rule = rl, weight = "w", na_rm = TRUE)
  expect_equal(out$cap[out$state == "N1"], 100)
  # A2's weight is dropped with its NA, so the divisor is A1's 10 alone
  expect_equal(out$eff[out$state == "N1"], 0.9, tolerance = 1e-9)
  # an all-NA group says nothing and stays NA rather than becoming 0
  expect_true(is.na(out$cap[out$state == "N2"]))
})

test_that("rule accepts a named vector, one per column", {
  d <- data.frame(region = c("A1", "A2"), cap = c(10, 20), eff = c(0.4, 0.8),
                  w = c(1, 3))
  out <- recast_from_geoatoms(d, gs, to = "state", values = c("cap", "eff"),
                              rule = c(cap = "sum", eff = "weighted_mean"),
                              weight = "w")
  expect_equal(out$cap, 30)
  expect_equal(out$eff, (0.4 * 1 + 0.8 * 3) / 4, tolerance = 1e-9)
})

test_that("an unnamed rule vector longer than one is refused", {
  d <- data.frame(region = c("A1", "A2"), cap = c(10, 20), eff = c(0.4, 0.8))
  expect_error(
    recast_from_geoatoms(d, gs, to = "state", values = c("cap", "eff"),
                         rule = c("sum", "weighted_mean")),
    "NAMED vector")
})
