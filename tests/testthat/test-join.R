# join_geoscale() -- attach a Geoscale to region-keyed data -------------------

gs <- geoscale_example()

test_that("the label column is named after the Geoscale", {
  x <- data.frame(state = c("N1", "N2", "S1"), v = 1:3)
  j <- join_geoscale(x, gs)
  expect_true("example" %in% names(j))
  expect_equal(as.character(j$example), x$state)
  # nothing else is attached by default
  expect_named(j, c("state", "v", "example"))
})

test_that("membership, share and weight come '<name>.'-prefixed", {
  x <- data.frame(state = c("N1", "N2", "S1"), v = 1:3)
  j <- join_geoscale(x, gs, geoframes = TRUE, meta = TRUE, weight = "pop")
  expect_true(all(c("example.country", "example.weight", "example.share")
                  %in% names(j)))
  expect_equal(as.character(j$example.country), c("N", "N", "S"))
  # pop: N1 = 100, N2 = 100, S1 = 100; shares over the geoframe total 300
  expect_equal(j$example.weight, c(100, 100, 100))
  expect_equal(j$example.share, c(1, 1, 1) / 3, tolerance = 1e-12)
})

test_that("membership columns respect as_factor and cross-cuts get NA", {
  x <- data.frame(zone = c("N1", "ZB", "ZC"), v = 1:3)
  # ZB straddles two states -> NA with a warning
  expect_warning(
    j <- join_geoscale(x, gs, geoframes = "state"),
    "does not nest")
  expect_true(is.na(j$example.state[j$zone == "ZB"]))
  expect_s3_class(j$example.state, "factor")

  j2 <- suppressWarnings(
    join_geoscale(x, gs, geoframes = "state", as_factor = FALSE))
  expect_type(j2$example.state, "character")
})

test_that("two Geoscales coexist on one dataset", {
  gs_b <- .bands_gs()
  x <- data.frame(atom = c("A1", "A2", "A5"), v = 1:3)
  j <- join_geoscale(x, gs, geoframes = "country")
  j <- join_geoscale(j, gs_b, geoframes = "band", geoframe = "atom",
                     key = "atom")
  expect_true(all(c("example", "example.country", "bands", "bands.band")
                  %in% names(j)))
  expect_equal(as.character(j$bands.band), c("X", "Y", "X"))
})

test_that("existing columns are never overwritten", {
  x <- data.frame(state = c("N1", "N2"), example = c("a", "b"), v = 1:2)
  expect_error(join_geoscale(x, gs, geoframe = "state", key = "state"),
               "overwrite")
})

test_that("an unnamed Geoscale refuses to attach", {
  lf <- data.frame(top = "T", atom = c("a", "b"))
  anon <- geoscale_from_leaftable(lf, geoframes = c("top", "atom"))
  expect_error(join_geoscale(data.frame(atom = "a", v = 1), anon),
               "has no name")
})

test_that("meta without declared weights warns and skips", {
  lf <- data.frame(top = c("T", "T"), atom = c("a", "b"))
  gsw <- geoscale_from_leaftable(lf, geoframes = c("top", "atom"),
                                 name = "noweights")
  expect_warning(
    j <- join_geoscale(data.frame(atom = c("a", "b"), v = 1:2), gsw,
                       meta = TRUE),
    "no weight columns")
  expect_false("noweights.weight" %in% names(j))
})
