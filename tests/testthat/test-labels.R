# Labels per geoframe, in variants.

.named <- function() {
  attach_labels_geoscale(
    geoscale_example(),
    data.frame(geoframe = "country", region = c("N", "S", NA),
               label = c("Northland", "Southland", "Country")),
    variant = "name"
  )
}

test_that("a geoframe may have labels while another has none", {
  gs <- .named()
  expect_equal(geoscale_label(gs, c("S", "N"), "country"),
               c("Southland", "Northland"))
  expect_equal(geoscale_label(gs, c("N1", "ZB"), "zone"), c("N1", "ZB"))
  expect_equal(geoscale_label(gs, NA, "country"), "Country")
  expect_equal(geoscale_label(gs, NA, "zone"), "zone")
  expect_equal(nrow(geoscale_labels(gs, geoframe = "state")), 0L)
})

test_that("a region carries alternative names as variants", {
  gs <- attach_labels_geoscale(
    .named(),
    data.frame(frame = "country", unit = "N", label = "Nordland"),
    variant = "de"
  )
  expect_setequal(unique(geoscale_labels(gs)$variant), c("name", "de"))
  expect_equal(geoscale_label(gs, c("N", "S"), "country", variant = "de"),
               c("Nordland", "S"))
  expect_equal(geoscale_label(gs, "N", "country"), "Northland")
  gs2 <- attach_labels_geoscale(
    gs, data.frame(frame = "country", unit = "S", label = "Suedland"),
    variant = "de", default = "de"
  )
  expect_equal(geoscale_label(gs2, c("N", "S"), "country"),
               c("Nordland", "Suedland"))
  expect_error(geoscale_label(gs, "N", "country", variant = "fr"), "variant")
})

test_that("the label table is validated", {
  gs <- geoscale_example()
  expect_error(
    attach_labels_geoscale(gs, data.frame(frame = "nope", unit = "N",
                                          label = "x")),
    "not in the object")
  expect_error(
    attach_labels_geoscale(gs, data.frame(frame = "country", unit = "ZZ",
                                          label = "x")),
    "not members")
  expect_error(
    attach_labels_geoscale(.named(), data.frame(frame = "country", unit = "N",
                                                label = "x"),
                           variant = "name"),
    "already present")
  expect_error(geoscale_from_leaftable(
    data.frame(top = "T", atom = c("a", "b")), geoframes = c("top", "atom"),
    labels = "name"), "data.frame")
})

test_that("labels follow the scale through filter, prune, zoom and weights", {
  gs <- .named()
  f <- filter_geoscale(gs, "country", "N")
  expect_equal(geoscale_labels(f)$unit, c("N", NA))
  p <- prune_geoscale(gs, "state")
  expect_equal(geoscale_label(p, c("N", "S"), "country"),
               c("Northland", "Southland"))
  expect_equal(nrow(geoscale_labels(prune_geoscale(
    attach_labels_geoscale(gs, data.frame(frame = "atom", unit = "A1",
                                          label = "First")), "state"),
    variant = "label")), 0L)
  z <- zoom_geoscale(gs, focus = "A1", geoframes = c("country", "state"))
  expect_equal(geoscale_label(z, "N", "country"), "Northland")
  w <- geoscale_add_weight(gs, gdp = 1)
  expect_equal(geoscale_labels(w), geoscale_labels(gs))
  expect_output(print(gs), "Labels: country \\[name\\]")
})
