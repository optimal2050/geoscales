# geoscale_tree(): the parts of a GeoScale and their marks, checked against
# the identity.

.has_tree <- function() {
  !is.null(get0("scale_tree", envir = asNamespace("nestedscales"),
                inherits = FALSE))
}

test_that("the tree names the parts of a GeoScale in its own words", {
  skip_if_not(.has_tree())
  gs <- geoscale_example()
  tr <- geoscale_tree(gs)
  expect_s3_class(tr, "scale_tree")
  top <- tr$part[tr$parent == ""]
  expect_true(all(c("leaftable", "geoframes", "members", "leaf", "meta",
                    "labels", "geometry", "hidden") %in% top))
  expect_false("frames" %in% top)
  mark <- function(part) tr$mark[tr$part == part & tr$parent == ""]
  verb <- function(part) tr$verb[tr$part == part]
  expect_identical(mark("geoframes"), "fixed")
  expect_identical(mark("members"), "derived")
  expect_identical(mark("geometry"), "mutable")
  expect_identical(mark("hidden"), "mutable")
  expect_identical(verb("labels"), "attach_labels_geoscale()")
  expect_identical(verb("geometry"), "attach_geometry_geoscale()")
  expect_identical(verb("hidden"), "hide_geoframes_geoscale()")
  w <- tr[tr$parent == "leaftable" & tr$kind == "weight", ]
  expect_setequal(w$part, geoscale_weights(gs))
  expect_true(all(w$verb == "geoscale_add_weight()"))
  expect_output(print(tr, ascii = TRUE), "^<GeoScale> example@")
  expect_output(str(gs), "hide_geoframes_geoscale()", fixed = TRUE)
})

test_that("the mutable parts of a GeoScale keep its identity", {
  skip_if_not(.has_tree())
  gs <- geoscale_example()
  id <- geoscale_id(gs)
  hid <- hide_geoframes_geoscale(gs, "cell")
  expect_identical(geoscale_id(hid), id)
  # `hidden` now holds the same value as `leaf`; both are still listed
  top <- geoscale_tree(hid)
  top <- top$part[top$parent == ""]
  expect_true(all(c("leaf", "hidden") %in% top))
  expect_identical(anyDuplicated(top), 0L)
  lt <- geoscale_leaftable(gs)
  w <- stats::setNames(seq_len(nrow(lt)), lt[[geoscale_leaf_column(gs)]])
  expect_identical(
    geoscale_id(geoscale_add_weight(gs, extra = w)), id
  )
  lab <- attach_labels_geoscale(gs, data.frame(
    geoframe = "country", region = geoscale_regions(gs, "country")[[1L]],
    label = "First"
  ))
  expect_identical(geoscale_id(lab), id)
})

test_that("geoscale_tree() refuses anything but a GeoScale", {
  expect_error(geoscale_tree(data.frame()))
})
