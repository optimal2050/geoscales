# `from`/`to` renamed `source`/`target` in 0.7.0; the old names still work ---

test_that("from/to still work, with a deprecation warning", {
  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                  capacity = c(1, 2, 3, 4, 5, 6))
  rlang::local_options(lifecycle_verbosity = "warning")
  new <- recast_geoscale(x, gs, source = "atom", target = "country",
                         rule = "sum")
  old <- suppressWarnings(recast_geoscale(x, gs, from = "atom", to = "country",
                                          rule = "sum"))
  expect_identical(old, new)
  expect_warning(geoscale_children(gs, "country", "N", to = "state"),
                 "deprecated")
})

test_that("passing both spellings is an error", {
  gs <- geoscale_example()
  expect_error(geoscale_map(gs, "country", target = "state", to = "state"),
               "pass `target` only")
})
