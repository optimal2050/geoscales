# The harmonized naming layer: recast() generic, join_geoscale(),
# deprecated aliases ----------------------------------------------------------

test_that("the recast() generic dispatches the Geoscale method", {
  gs <- geoscale_example()
  x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                  capacity = c(1, 2, 3, 4, 5, 6))
  wrk <- recast_geoscale(x, gs, from = "atom", to = "country",
                         rule = "sum")
  gen <- timescales::recast(x, gs, to = "country", rule = "sum")
  expect_identical(gen, wrk)
  # pipe + explicit from_level
  gen2 <- x |> timescales::recast(gs, to = "country",
                                  from_level = "atom", rule = "sum")
  expect_identical(gen2, wrk)
  # ambiguous / absent source level errors clearly
  expect_error(timescales::recast(data.frame(v = 1), gs, to = "country"),
               "from_level")
})

test_that("join_geoscale attaches membership + weight/share", {
  gs <- geoscale_example()
  states <- geoscale_regions(gs, "state")
  x <- data.frame(state = states, v = seq_along(states))
  j <- join_geoscale(x, gs)
  expect_true(all(c("country", "v") %in% names(j)))
  expect_true(is.factor(j$country))
  expect_equal(levels(j$country), S7::prop(gs, "members")$country)
  if ("weight" %in% names(j)) {
    expect_true(all(j$share <= 1, na.rm = TRUE))
  }
  # unknown codes warn; zero matches error
  expect_warning(join_geoscale(data.frame(state = c(states[1], "zz"),
                                          v = 1:2), gs),
                 "not regions")
  expect_error(
    suppressWarnings(join_geoscale(data.frame(state = "zz", v = 1), gs)),
    "no rows")
})

test_that("deprecated geo_* aliases warn and delegate", {
  gs <- geoscale_example()
  expect_warning(lv <- geo_levels(gs), "deprecated|geoscale_levels")
  expect_identical(lv, geoscale_levels(gs))
  x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                  capacity = 1:6)
  expect_warning(
    old <- geo_recast(x, gs, from = "atom", to = "country", rule = "sum"),
    "deprecated|recast_geoscale")
  expect_identical(old, recast_geoscale(x, gs, from = "atom",
                                        to = "country", rule = "sum"))
  expect_warning(f <- geo_filter(gs, "country", "N"),
                 "deprecated|filter_geoscale")
  expect_identical(S7::prop(f, "leaves"),
                   S7::prop(filter_geoscale(gs, "country", "N"), "leaves"))
  expect_warning(r <- geo_rank(gs, "state"), "deprecated|geoscale_rank")
  expect_identical(r, geoscale_rank(gs, "state"))
})
