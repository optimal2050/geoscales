# The harmonized naming layer: recast() generic, join_geoscale() ----------------------------------------------------------

test_that("the recast() generic dispatches the Geoscale method", {
  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                  capacity = c(1, 2, 3, 4, 5, 6))
  wrk <- recast_geoscale(x, gs, from = "atom", to = "country",
                         rule = "sum")
  gen <- timescales::recast(x, gs, to = "country", rule = "sum")
  expect_identical(gen, wrk)
  # pipe + explicit from_geoframe
  gen2 <- x |> timescales::recast(gs, to = "country",
                                  from_geoframe = "atom", rule = "sum")
  expect_identical(gen2, wrk)
  # ambiguous / absent source geoframe errors clearly
  expect_error(timescales::recast(data.frame(v = 1), gs, to = "country"),
               "cannot infer the source geoframe")
})

test_that("join_geoscale attaches prefixed membership + weight/share", {
  gs <- geoscale_example()
  states <- geoscale_regions(gs, "state")
  x <- data.frame(state = states, v = seq_along(states))
  j <- join_geoscale(x, gs, geoframes = TRUE, meta = TRUE)
  # label column named after the Geoscale; everything else "<name>."-prefixed
  expect_true(all(c("example", "example.country", "example.weight",
                    "example.share", "v") %in% names(j)))
  expect_true(is.factor(j$example.country))
  expect_equal(levels(j$example.country), S7::prop(gs, "members")$country)
  expect_true(all(j$example.share <= 1, na.rm = TRUE))
  # never overwrites: attaching again clashes on the derived columns
  expect_error(join_geoscale(j, gs, geoframes = TRUE, key = "state"),
               "overwrite")
  # unknown codes warn; zero matches error
  expect_warning(join_geoscale(data.frame(state = c(states[1], "zz"),
                                          v = 1:2), gs),
                 "not regions")
  expect_error(
    suppressWarnings(join_geoscale(data.frame(state = "zz", v = 1), gs)),
    "no rows")
})

test_that("the constructor rejects the pre-lattice argument names", {
  gs <- geoscale_example()
  lt <- S7::prop(gs, "leaftable")
  expect_error(geoscale_from_leaftable(lt, geoframes = geoscale_geoframes(gs),
                                       levels = "x"),
               "renamed")
})
