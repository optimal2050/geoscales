test_that("the example Geoscale is well formed", {
  gs <- geoscale_example()
  expect_s3_class(gs, "geoscales::Geoscale")
  expect_equal(S7::prop(gs, "levels"),
               c("country", "state", "zone", "atom"))
  expect_equal(nrow(S7::prop(gs, "leaves")), 7L)
  expect_equal(geo_regions(gs, "country"), c("N", "S"))
  expect_equal(geo_weights(gs), c("km2", "pop"))
  expect_equal(geo_rank(gs, c("zone", "country")), c(3L, 1L))
})

test_that("members hold exactly the non-NA codes at each level", {
  gs <- geoscale_example()
  leaves <- S7::prop(gs, "leaves")
  for (lvl in S7::prop(gs, "levels")) {
    expect_setequal(geo_regions(gs, lvl),
                    unique(stats::na.omit(leaves[[lvl]])))
  }
})

test_that("blank codes are normalised to NA", {
  df <- data.frame(top = c("T", "  ", "T"), unit = c("a", "b", "c"),
                   km2 = c(1, 2, 3))
  gs <- geoscale_from_leaves(df, levels = c("top", "unit"))
  expect_true(is.na(S7::prop(gs, "leaves")$top[2]))
  expect_equal(geo_regions(gs, "top"), "T")
})

test_that("'region' is allowed as the finest level name only", {
  # Downstream models call their finest spatial unit "region" (energyRt does),
  # and there the level column IS the atom key column, so nothing collides.
  ok <- geoscale_from_leaves(
    data.frame(zone = c("N", "N", "S"), region = c("R1", "R2", "R3"),
               km2 = c(1, 2, 3)),
    levels = c("zone", "region")
  )
  expect_equal(geo_levels(ok, finest = TRUE), "region")
  expect_equal(geo_children(ok, "zone", "N"), c("R1", "R2"))

  # As a coarser level it would clash with the key column.
  expect_error(
    geoscale_from_leaves(
      data.frame(region = c("A", "B"), leaf = c("x", "y")),
      levels = c("region", "leaf")
    ),
    "reserved names"
  )
})

test_that("geo_levels reports the hierarchy", {
  gs <- geoscale_example()
  expect_equal(geo_levels(gs), c("country", "state", "zone", "atom"))
  expect_equal(geo_levels(gs, finest = TRUE), "atom")
})

test_that("the validator rejects a duplicate atom key", {
  bad <- data.frame(top = c("T", "T"), atom = c("A", "A"), km2 = c(1, 2))
  expect_error(geoscale_from_leaves(bad, levels = c("top", "atom")),
               "must be unique")
})

test_that("the validator rejects a negative weight", {
  bad <- data.frame(top = c("T", "T"), atom = c("A", "B"), km2 = c(1, -2))
  expect_error(geoscale_from_leaves(bad, levels = c("top", "atom")),
               ">= 0")
})

test_that("a level absent from leaves is rejected", {
  df <- data.frame(top = c("T", "T"), atom = c("A", "B"))
  expect_error(geoscale_from_leaves(df, levels = c("top", "nope", "atom")),
               "missing level column")
})

test_that("members disagreeing with leaves is rejected", {
  df <- data.frame(top = c("T", "T"), atom = c("A", "B"))
  expect_error(
    Geoscale(leaves = transform(df, region = df$atom),
             levels = c("top", "atom"),
             members = list(top = "T", atom = c("A", "B", "GHOST"))),
    "exactly the non-NA values"
  )
})

test_that("levels ordered fine-to-coarse warn", {
  df <- data.frame(a = c("x", "y", "z"), b = c("P", "P", "Q"),
                   c = c("1", "2", "3"))
  expect_warning(geoscale_from_leaves(df, levels = c("a", "b", "c")),
                 "coarsest first")
})

test_that("print is informative and returns invisibly", {
  gs <- geoscale_example()
  out <- capture.output(res <- withVisible(print(gs)))
  expect_false(res$visible)
  expect_true(any(grepl("Geoscale: example", out)))
  expect_true(any(grepl("unassigned", out)))
})
