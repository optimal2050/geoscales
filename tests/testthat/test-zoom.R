# zoom_geoscale: a telescoping cut. The properties that matter are that the cut
# is a COMPLETE PARTITION and that it NESTS -- everything else is labelling.

test_that("the cut telescopes outward from the focus", {
  gs <- geoscale_example()
  z <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"))
  lt <- z@leaftable
  cut <- stats::setNames(lt$zoom, lt$region)

  expect_equal(unname(cut["A1"]), "A1")        # focus kept whole
  expect_equal(unname(cut["A2"]), "N1_rest")   # rest of its state
  expect_equal(unname(cut["A3"]), "N_rest")    # rest of its country
  expect_equal(unname(cut["A5"]), "S")         # untouched country, coarsest
  expect_equal(unname(cut["A6"]), "S")
})

test_that("the geoframes are levels[1], the cut, and the atom layer", {
  gs <- geoscale_example()
  z <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"))
  expect_equal(geoscale_geoframes(z), c("country", "zoom", "atom"))
  # The level the cut was carved from must be GONE: "rest of N1" spans states,
  # so keeping `state` beside `zoom` would be a non-nesting hierarchy that
  # still validates.
  expect_false("state" %in% geoscale_geoframes(z))
})

test_that("the cut nests in both directions", {
  gs <- geoscale_example()
  z <- zoom_geoscale(gs, focus = c("A1", "A3"), levels = c("country", "state"))
  expect_true(isTRUE(geoscale_nests(z, "country", "zoom")))
  expect_true(isTRUE(geoscale_nests(z, "zoom", "atom")))
})

test_that("every atom survives and weights are preserved exactly", {
  gs <- geoscale_example()
  z <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"))
  expect_setequal(z@leaftable$region, gs@leaftable$region)
  for (w in gs@meta$weights) {
    expect_equal(sum(z@leaftable[[w]]), sum(gs@leaftable[[w]]))
  }
})

test_that("an atom with no code at the coarsest level keeps NA", {
  # Matches prune_geoscale(): such an atom has no place in the coarse
  # partition, the loss shows in coverage, and it is not invented.
  gs <- geoscale_example()
  z <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"))
  lt <- z@leaftable
  expect_true(is.na(lt$zoom[lt$region == "ROW"]))
  expect_true(is.na(lt$country[lt$region == "ROW"]))
})

test_that("a deeper focus produces a longer telescope", {
  gs <- geoscale_example()
  z1 <- zoom_geoscale(gs, focus = "A1", levels = "country")
  z2 <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"))
  # More ring levels can only split the cut further, never coarsen it.
  expect_lte(length(geoscale_regions(z1, "zoom")),
             length(geoscale_regions(z2, "zoom")))
})

test_that("focusing every atom is a no-op partition", {
  gs <- geoscale_example()
  atoms <- gs@leaftable$region
  z <- zoom_geoscale(gs, focus = atoms, levels = "country")
  expect_setequal(stats::na.omit(z@leaftable$zoom), atoms)
})

test_that("bad input is refused with a message that says what to do", {
  gs <- geoscale_example()
  expect_error(zoom_geoscale(gs, focus = "N", levels = "country"),
               "names atoms")
  expect_error(zoom_geoscale(gs, focus = character(0)), "prune_geoscale")
  expect_error(zoom_geoscale(gs, focus = "A1", levels = "nope"),
               "unknown geoframe")
  expect_error(zoom_geoscale(gs, focus = "A1", levels = c("country", "atom")),
               "atom geoframe")
  expect_error(zoom_geoscale(gs, focus = "A1", levels = "country",
                             name = "country"),
               "already a geoframe")
  expect_error(zoom_geoscale(gs@leaftable, focus = "A1"), "must be a Geoscale")
})

test_that("the label format is honoured", {
  gs <- geoscale_example()
  z <- zoom_geoscale(gs, focus = "A1", levels = c("country", "state"),
                     label_rest = "other_%s", name = "cut")
  expect_true("cut" %in% geoscale_geoframes(z))
  expect_true(any(grepl("^other_", z@leaftable$cut)))
})
