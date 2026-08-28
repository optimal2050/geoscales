# =========================================================================== #
# Base-generic methods on Geoscale: summary / names / as.data.frame /
# ggplot2::fortify (mirrored in timescales/tests/testthat/test-methods.R).
# =========================================================================== #

# @covers geoscale_coverage geoscale_leaftable geoscale_nests depth=U
test_that("summary() returns the classed quantitative view", {
  gs <- geoscale_example()
  s <- summary(gs)
  expect_s3_class(s, "summary_Geoscale")
  expect_named(s, c("name", "desc", "geoframes", "unassigned", "n_atoms",
                    "weights", "weight_totals", "default_weight",
                    "coverage", "sampled", "parent_name", "nesting",
                    "geometry", "source"))
  expect_identical(s$n_atoms, 7L)
  expect_equal(s$weight_totals,
               colSums(as.data.frame(geoscale_leaftable(gs))[,
                 geoscale_weights(gs), drop = FALSE], na.rm = TRUE))
  expect_false(s$sampled)
  # the cross-cutting state/zone pair is flagged with its offenders
  nst <- s$nesting
  row <- nst[nst$parent == "state" & nst$child == "zone", ]
  expect_identical(nrow(row), 1L)
  expect_false(row$nests)
  expect_gt(row$n_offenders, 0)
  expect_output(print(s), "summary of Geoscale 'example'")
  expect_output(print(s), "CROSS-CUTTING")
  expect_output(print(s), "geometry:       none")
})

test_that("summary() reports a sample's coverage and parent", {
  n <- filter_geoscale(geoscale_example(), "country", "N")
  s <- summary(n)
  expect_true(s$sampled)
  expect_lt(s$coverage[["km2"]], 1)
  expect_identical(s$parent_name, "example")
  expect_output(print(s), "SAMPLED")
})

test_that("summary() reports attached geometry sf-free", {
  skip_if_not_installed("sf")
  gs <- .squares_gs()
  s <- summary(gs)
  expect_true(s$geometry$attached)
  expect_identical(s$geometry$n_features, 6L)
  expect_output(print(s), "attached \\(6 features")
})

test_that("names() returns the geoframes, not leaftable columns", {
  gs <- geoscale_example()
  expect_identical(names(gs), geoscale_geoframes(gs))
  expect_identical(names(gs), c("country", "state", "zone", "atom"))
})

test_that("as.data.frame() equals the leaftable accessor", {
  gs <- geoscale_example()
  expect_identical(as.data.frame(gs), geoscale_leaftable(gs))
})

test_that("fortify() feeds ggplot() directly", {
  skip_if_not_installed("ggplot2")
  gs <- geoscale_example()
  expect_identical(ggplot2::fortify(gs), geoscale_leaftable(gs))
  p <- ggplot2::ggplot(gs) +
    ggplot2::geom_col(ggplot2::aes(atom, km2))
  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  expect_identical(nrow(built$data[[1]]), 7L)
})
