# =========================================================================== #
# Backend contract, all entry points x all backends, via
# expect_backend_contract() (helper-backends.R). The dtplyr/arrow columns of
# the sweep run at tier `full`; two explicit lazy smoke tests keep one cell
# of each engine alive at `fast`. (No POSIXct columns in space, so no arrow
# ingestion skips here.)
# =========================================================================== #

# @covers recast_geoscale depth=B backends=data.frame,tibble,data.table,dtplyr,arrow
test_that("recast_geoscale honours the backend contract", {
  gs <- geoscale_example()
  x <- fx_tbl(gs, ids = c("A", "B"))
  expect_backend_contract(
    x,
    function(d, collect = NULL) recast_geoscale(
      d, gs, "atom", "country", rule = "sum", collect = collect),
    key_cols = c("id", "country"), value_cols = "cap")
  expect_backend_rejects(function(d, collect = NULL) recast_geoscale(
    d, gs, "atom", "country", rule = "sum"))
})

# @covers recast_to_geoatoms depth=B backends=data.frame,tibble,data.table,dtplyr,arrow
test_that("recast_to_geoatoms honours the backend contract", {
  gs <- geoscale_example()
  x <- data.frame(country = c("N", "S"), cap = c(120, 60))
  expect_backend_contract(
    x,
    function(d, collect = NULL) recast_to_geoatoms(
      d, gs, from = "country", rule = "sum", weight = "km2",
      collect = collect),
    key_cols = c("atom", "region"), value_cols = "cap")
  expect_backend_rejects(function(d, collect = NULL) recast_to_geoatoms(
    d, gs, from = "country", rule = "sum"))
})

# @covers recast_from_geoatoms depth=B backends=data.frame,tibble,data.table,dtplyr,arrow
test_that("recast_from_geoatoms honours the backend contract", {
  gs <- geoscale_example()
  base <- recast_to_geoatoms(
    data.frame(country = c("N", "S"), cap = c(120, 60)),
    gs, from = "country", rule = "sum", weight = "km2")
  expect_backend_contract(
    base,
    function(d, collect = NULL) recast_from_geoatoms(
      d, gs, to = "state", rule = "sum", values = "cap",
      collect = collect),
    key_cols = "state", value_cols = "cap")
  expect_backend_rejects(function(d, collect = NULL) recast_from_geoatoms(
    d, gs, to = "state", rule = "sum", values = "cap"))
})

# @covers join_geoscale depth=B backends=data.frame,tibble,data.table,dtplyr,arrow
test_that("join_geoscale honours the backend contract", {
  gs <- geoscale_example()
  x <- fx_tbl(gs)
  expect_backend_contract(
    x,
    function(d, collect = NULL) join_geoscale(
      d, gs, geoframe = "atom", geoframes = "country", meta = TRUE,
      as_factor = FALSE, collect = collect),
    key_cols = "atom")
  expect_backend_rejects(function(d, collect = NULL) join_geoscale(
    d, gs, geoframe = "atom"))
})

# ---- fast-tier lazy smokes (one live cell per engine below `full`) -------- #

test_that("arrow smoke: recast_geoscale stays lazy, collects right", {
  skip_if_not_installed("arrow")
  gs <- geoscale_example()
  x <- fx_tbl(gs, ids = c("A", "B"))
  expect_backend_contract(
    x,
    function(d, collect = NULL) recast_geoscale(
      d, gs, "atom", "country", rule = "sum", collect = collect),
    key_cols = c("id", "country"), value_cols = "cap",
    backends = "arrow")
})

test_that("dtplyr smoke: join_geoscale stays lazy, collects right", {
  skip_if_not_installed("dtplyr")
  skip_if_not_installed("data.table")
  gs <- geoscale_example()
  x <- fx_tbl(gs)
  expect_backend_contract(
    x,
    function(d, collect = NULL) join_geoscale(
      d, gs, geoframe = "atom", meta = TRUE, as_factor = FALSE,
      collect = collect),
    key_cols = "atom",
    backends = "dtplyr")
})
