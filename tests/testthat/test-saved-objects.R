# =========================================================================== #
# Objects in the form of an earlier class definition: the name of the leaf
# column under the attribute `key`, and the label table with the code column
# `unit`. The readers take them as they are; a write rebuilds the object.
#
# Two sources. `fixtures/geoscale-key.rds` is an object saved while the
# property was `key`, so it embeds that class definition; its finest
# geoframe is `atom`, one geoframe is hidden and `country` is labelled. The
# hand-built one has the earlier attributes under the current class: enough
# for this package's readers, while the shared engine needs the `leaf`
# property of the class it finds.
# =========================================================================== #

.labelled_gs <- function() {
  attach_labels_geoscale(
    geoscale_example(),
    data.frame(geoframe = "country", region = c("N", "S"),
               label = c("Northland", "Southland"))
  )
}

.old_form_gs <- function(gs = .labelled_gs()) {
  lb <- attr(gs, "labels", exact = TRUE)
  names(lb)[names(lb) == "member"] <- "unit"
  attr(gs, "labels") <- lb
  attr(gs, "key") <- attr(gs, "leaf", exact = TRUE)
  attr(gs, "leaf") <- NULL
  gs
}

.saved_gs <- function() {
  readRDS(test_path("fixtures", "geoscale-key.rds"))
}

.LABEL_NAMES <- c("geoframe", "region", "variant", "label")

# ---- built by hand ---------------------------------------------------------

test_that("the hand-built object is in the earlier form", {
  old <- .old_form_gs()
  expect_null(attr(old, "leaf", exact = TRUE))
  expect_identical(attr(old, "key", exact = TRUE), "cell")
  expect_named(attr(old, "labels", exact = TRUE),
               c("frame", "unit", "variant", "label"))
})

test_that("the readers take a hand-built object in the earlier form", {
  gs <- .labelled_gs()
  old <- .old_form_gs(gs)
  expect_identical(geoscale_leaf_column(old), "cell")
  expect_identical(geoscale_geoframes(old), geoscale_geoframes(gs))
  expect_identical(geoscale_labels(old), geoscale_labels(gs))
  expect_named(geoscale_labels(old), .LABEL_NAMES)
  expect_identical(geoscale_label(old, c("N", "S"), "country"),
                   c("Northland", "Southland"))
  expect_output(print(old), "Leaves: 7")
  expect_identical(summary(old)$n_leaves, 7L)
  expect_identical(geoscale_id(old), geoscale_id(gs))
})

test_that("the leaf route runs on a hand-built object in the earlier form", {
  gs <- .labelled_gs()
  old <- .old_form_gs(gs)
  x <- data.frame(country = c("N", "S"), cap = c(120, 60))
  down <- recast_to_geoleaves(x, old, rule = "sum", weight = "km2")
  expect_equal(down, recast_to_geoleaves(x, gs, rule = "sum", weight = "km2"),
               ignore_attr = TRUE)
  expect_named(down, c("cell", "cap", "weight"))
  up <- recast_from_geoleaves(down, old, target = "state", rule = "sum")
  expect_equal(sum(up$cap), 180)
})

test_that("a write rebuilds a hand-built object in the earlier form", {
  old <- .old_form_gs()
  h <- hide_geoframes_geoscale(old, "cell")
  expect_identical(attr(h, "leaf", exact = TRUE), "cell")
  expect_null(attr(h, "key", exact = TRUE))
  expect_named(attr(h, "labels", exact = TRUE),
               c("frame", "member", "variant", "label"))
  expect_identical(geoscale_geoframes(h, visible = FALSE), "cell")
  expect_identical(geoscale_labels(h), geoscale_labels(.labelled_gs()))
  expect_no_error(S7::validate(h))

  l2 <- attach_labels_geoscale(
    old, data.frame(geoframe = "state", region = "N1", label = "North one"))
  expect_identical(attr(l2, "leaf", exact = TRUE), "cell")
  expect_identical(nrow(geoscale_labels(l2)), 3L)
  expect_identical(geoscale_label(l2, "N1", "state"), "North one")
})

# ---- saved under the earlier class definition ------------------------------

test_that("the saved object embeds the earlier class definition", {
  s <- .saved_gs()
  expect_true("key" %in% S7::prop_names(s))
  expect_false("leaf" %in% S7::prop_names(s))
  expect_identical(attr(s, "key", exact = TRUE), "atom")
  expect_named(attr(s, "labels", exact = TRUE),
               c("frame", "unit", "variant", "label"))
})

test_that("the readers take a saved object", {
  s <- .saved_gs()
  expect_identical(geoscale_leaf_column(s), "atom")
  expect_identical(geoscale_geoframes(s),
                   c("country", "state", "zone", "atom"))
  expect_identical(geoscale_geoframes(s, visible = FALSE), "zone")
  expect_named(geoscale_labels(s), .LABEL_NAMES)
  expect_identical(geoscale_labels(s)$region, c("N", "S"))
  expect_identical(geoscale_label(s, c("N", "S"), "country"),
                   c("Northland", "Southland"))
  expect_no_error(S7::validate(s))
  expect_output(print(s), "Leaves: 7")
  expect_identical(summary(s)$n_leaves, 7L)
  tr <- geoscale_tree(s)
  expect_identical(tr$note[tr$part == "leaf"], "atom")
  expect_identical(tr$kind[tr$part == "atom"], "leaf column")
})

test_that("recasts and joins run on a saved object", {
  s <- .saved_gs()
  x <- data.frame(country = c("N", "S"), cap = c(120, 60))
  down <- recast_to_geoleaves(x, s, rule = "sum", weight = "km2")
  expect_named(down, c("atom", "cap", "weight"))
  expect_equal(sum(down$cap), 180)
  up <- recast_from_geoleaves(down, s, target = "state", rule = "sum")
  expect_equal(sum(up$cap), 180)
  st <- recast_geoscale(x, s, target = "state", rule = "sum", weight = "km2")
  expect_equal(st$cap[match(up$state, st$state)], up$cap)
  j <- join_geoscale(data.frame(atom = c("A1", "A5")), s,
                     geoframes = "country")
  expect_identical(as.character(j[["example.country"]]), c("N", "S"))
})

test_that("a write brings a saved object to the current form", {
  s <- .saved_gs()
  h <- hide_geoframes_geoscale(s, "atom")
  expect_true(all(c("leaf", "hidden") %in% S7::prop_names(h)))
  expect_identical(S7::prop(h, "leaf"), "atom")
  expect_null(attr(h, "key", exact = TRUE))
  expect_named(S7::prop(h, "labels"),
               c("frame", "member", "variant", "label"))
  expect_identical(geoscale_geoframes(h, visible = FALSE), c("zone", "atom"))
  expect_no_error(S7::validate(h))
  expect_identical(geoscale_geoframes(show_geoframes_geoscale(s),
                                      visible = FALSE), character())

  l2 <- attach_labels_geoscale(
    s, data.frame(geoframe = "state", region = "N1", label = "North one"))
  expect_identical(S7::prop(l2, "leaf"), "atom")
  expect_identical(geoscale_labels(l2)$region, c("N", "S", "N1"))
  expect_no_error(S7::validate(l2))
})

test_that("subsets of a saved object keep leaf column, labels and hidden", {
  s <- .saved_gs()
  f <- filter_geoscale(s, "country", "N")
  expect_identical(geoscale_leaf_column(f), "atom")
  expect_identical(geoscale_labels(f)$region, "N")
  expect_identical(geoscale_geoframes(f, visible = FALSE), "zone")
  expect_no_error(S7::validate(f))
  p <- prune_geoscale(s, "state")
  expect_identical(geoscale_leaf_column(p), "state")
  expect_identical(geoscale_labels(p)$region, c("N", "S"))
  z <- zoom_geoscale(s, focus = "A1")
  expect_identical(geoscale_leaf_column(z), "atom")
  w <- geoscale_add_weight(s, ones = 1)
  expect_true("ones" %in% geoscale_weights(w))
})
