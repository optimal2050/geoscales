# The data link: a table bound to a GeoScale.

skip_if(is.null(get0("bind_scale", envir = asNamespace("nestedscales"))),
        "the installed nestedscales has no data link")

test_that("binding records the GeoScale and the geoframe", {
  gs <- geoscale_example()
  d <- data.frame(state = c("N1", "N2", "S1"), cap = c(1, 2, 3))
  b <- bind_geoscale(d, gs)
  ln <- geoscale_link(b)
  expect_equal(ln$column, "state")
  expect_equal(ln$frame, "state")
  expect_equal(ln$id, geoscale_id(gs))
  expect_equal(nrow(geoscale_link(d)), 0L)
  expect_error(bind_geoscale(data.frame(state = "nope", cap = 1), gs), "not")
  # weights, labels and geometry are not part of the identity
  gs2 <- geoscale_add_weight(gs, gdp = 1)
  gs2 <- attach_labels_geoscale(
    gs2, data.frame(frame = "country", unit = "N", label = "North"))
  expect_identical(geoscale_id(gs2), geoscale_id(gs))
  expect_false(identical(geoscale_id(filter_geoscale(gs, "country", "N")),
                         geoscale_id(gs)))
})

test_that("verbs take the geoframe from the link and bind the result", {
  gs <- geoscale_example()
  d <- data.frame(origin = c("N1", "N2", "S1"), cap = c(1, 2, 3))
  plain <- recast_geoscale(data.frame(state = d$origin, cap = d$cap), gs,
                           source = "state", target = "country", rule = "sum")
  b <- bind_geoscale(d, gs, c(origin = "state"))
  out <- recast_geoscale(b, gs, target = "country", rule = "sum")
  expect_equal(out$cap, plain$cap)
  expect_equal(geoscale_link(out)$frame, "country")
  expect_equal(nrow(geoscale_link(plain)), 0L)

  a <- recast_to_geoatoms(b, gs, rule = "sum", weight = "km2")
  expect_equal(geoscale_link(a)$column, "atom")
  back <- recast_from_geoatoms(a, gs, target = "state", rule = "sum",
                               values = "cap")
  expect_equal(geoscale_link(back)$frame, "state")
  expect_equal(back$cap[match(c("N1", "N2", "S1"), back$state)], c(1, 2, 3))

  j <- join_geoscale(b, gs, geoframes = "country", as_factor = FALSE)
  expect_true("example.country" %in% geoscale_link(j)$column)
})

test_that("data bound to another geography is refused", {
  gs <- geoscale_example()
  lt <- geoscale_leaftable(gs)
  lt$state[lt$atom == "A3"] <- "N1"       # same names and codes, regrouped
  twin <- geoscale_from_leaftable(lt, geoframes = geoscale_geoframes(gs),
                                  name = "twin")
  b <- bind_geoscale(data.frame(state = c("N1", "N2"), cap = c(1, 2)), gs)
  expect_error(recast_geoscale(b, twin, target = "country", rule = "sum"),
               "is bound to .* not to 'twin'")
  expect_error(recast_to_geoatoms(b, twin, rule = "sum"), "is bound to")
  expect_error(join_geoscale(b, twin, geoframes = TRUE), "is bound to")
})
