# Backend matrix: the same pipeline over df / tibble / dt / dtplyr / arrow ----
#
# Numeric results must be identical across backends; eager classes come back
# as themselves, lazy inputs (dtplyr, arrow) return uncollected queries
# unless collect = TRUE (and lazy results carry observed groups only).

gs <- geoscale_example()
atoms <- c("A1", "A2", "A3", "A4", "A5", "A6")
cap <- data.frame(atom = atoms, capacity = c(1, 2, 3, 4, 5, 6))
ref <- recast_geoscale(cap, gs, "atom", "country", rule = "sum")

test_that("tibble in, tibble out, same numbers", {
  skip_if_not_installed("tibble")
  out <- recast_geoscale(tibble::as_tibble(cap), gs, "atom", "country",
                         rule = "sum")
  expect_s3_class(out, "tbl_df")
  expect_equal(as.data.frame(out), ref)
})

test_that("data.table in, data.table out, same numbers", {
  skip_if_not_installed("data.table")
  out <- recast_geoscale(data.table::as.data.table(cap), gs, "atom",
                         "country", rule = "sum")
  expect_s3_class(out, "data.table")
  expect_equal(as.data.frame(out), ref)
})

test_that("dtplyr lazy in: uncollected query out, collect = TRUE computes", {
  skip_if_not_installed("data.table")
  skip_if_not_installed("dtplyr")
  lz <- dtplyr::lazy_dt(cap)
  q <- recast_geoscale(lz, gs, "atom", "country", rule = "sum")
  expect_s3_class(q, "dtplyr_step")
  got <- as.data.frame(dplyr::collect(q))
  # lazy = observed groups; compare against the observed rows of ref
  got <- got[order(got$country), c("country", "capacity")]
  ref_obs <- ref[!is.na(ref$capacity), c("country", "capacity")]
  expect_equal(got, ref_obs, ignore_attr = TRUE)

  out <- recast_geoscale(lz, gs, "atom", "country", rule = "sum",
                         collect = TRUE)
  expect_s3_class(out, "data.table")
  expect_equal(as.data.frame(out), ref)
})

test_that("arrow in: uncollected query out, collect = TRUE materialises", {
  skip_if_not_installed("arrow")
  tbl <- arrow::arrow_table(cap)
  q <- recast_geoscale(tbl, gs, "atom", "country", rule = "sum")
  expect_true(inherits(q, c("arrow_dplyr_query", "ArrowTabular")))
  got <- as.data.frame(dplyr::collect(q))
  got <- got[order(got$country), c("country", "capacity")]
  ref_obs <- ref[!is.na(ref$capacity), c("country", "capacity")]
  expect_equal(got, ref_obs, ignore_attr = TRUE)

  out <- recast_geoscale(tbl, gs, "atom", "country", rule = "sum",
                         collect = TRUE)
  expect_equal(as.data.frame(out), ref)
})

test_that("weighted_mean and the halves agree across backends", {
  skip_if_not_installed("data.table")
  eff <- data.frame(atom = atoms, eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6))
  ref_wm <- recast_geoscale(eff, gs, "atom", "state",
                            rule = "weighted_mean", weight = "pop")
  out <- recast_geoscale(data.table::as.data.table(eff), gs, "atom",
                         "state", rule = "weighted_mean", weight = "pop")
  expect_equal(as.data.frame(out), ref_wm)

  a_ref <- recast_to_geoatoms(eff, gs, from = "atom", rule = "weighted_mean",
                              weight = "pop")
  a_dt <- recast_to_geoatoms(data.table::as.data.table(eff), gs,
                             from = "atom", rule = "weighted_mean",
                             weight = "pop")
  expect_s3_class(a_dt, "data.table")
  expect_equal(as.data.frame(a_dt), a_ref)
})

test_that("join_geoscale is backend-aware", {
  skip_if_not_installed("data.table")
  x <- data.frame(state = c("N1", "N2", "S1"), v = 1:3)
  ref_j <- join_geoscale(x, gs, geoframes = TRUE, meta = TRUE)
  out <- join_geoscale(data.table::as.data.table(x), gs,
                       geoframes = TRUE, meta = TRUE)
  expect_s3_class(out, "data.table")
  expect_equal(as.data.frame(out), ref_j, ignore_attr = TRUE)
})
