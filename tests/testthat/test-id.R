# geoscale_id(): the identity of a GeoScale, and data matched by codes alone.

test_that("the identity follows the structure, not weights or labels", {
  gs <- geoscale_example()
  id <- geoscale_id(gs)
  expect_match(id, "^example@[0-9a-f]{8}$")
  gs2 <- geoscale_add_weight(gs, gdp = 1)
  gs2 <- attach_labels_geoscale(
    gs2, data.frame(geoframe = "country", region = "N", label = "North"))
  expect_identical(geoscale_id(gs2), id)
  expect_false(identical(geoscale_id(filter_geoscale(gs, "country", "N")),
                         id))
  expect_error(geoscale_id(data.frame()))
})

test_that("a column bound in nestedscales is read as plain codes", {
  bind <- get0("bind_scale", envir = asNamespace("nestedscales"))
  skip_if(is.null(bind), "the installed nestedscales has no data link")
  gs <- geoscale_example()
  lt <- geoscale_leaftable(gs)
  lt$state[lt$cell == "A3"] <- "N1"       # same names and codes, regrouped
  twin <- geoscale_from_leaftable(lt, geoframes = geoscale_geoframes(gs),
                                  name = "twin")
  d <- data.frame(state = c("N1", "N2", "S1"), cap = c(1, 2, 3))
  b <- bind(d, twin)
  expect_s3_class(b$state, "scale_member")

  plain <- recast_geoscale(d, gs, source = "state", target = "country",
                           rule = "sum")
  out <- recast_geoscale(b, gs, source = "state", target = "country",
                         rule = "sum")
  expect_equal(out$cap, plain$cap)
  expect_type(out$country, "character")
  expect_false(inherits(out$country, "scale_member"))

  a <- recast_to_geoleaves(b, gs, source = "state", rule = "sum",
                           weight = "km2")
  ap <- recast_to_geoleaves(d, gs, source = "state", rule = "sum",
                            weight = "km2")
  expect_equal(a$cap, ap$cap)
  expect_false(inherits(a$cell, "scale_member"))
  back <- recast_from_geoleaves(a, gs, target = "state", rule = "sum",
                                values = "cap")
  expect_equal(back$cap[match(c("N1", "N2", "S1"), back$state)], c(1, 2, 3))

  j <- join_geoscale(b, gs, geoframes = "country", as_factor = FALSE)
  jp <- join_geoscale(d, gs, geoframes = "country", as_factor = FALSE)
  expect_equal(j$example.country, jp$example.country)
  expect_false(inherits(j$state, "scale_member"))
})
