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

test_that("deprecated geo_* aliases warn and delegate", {
  gs <- geoscale_example()
  expect_warning(lv <- geo_levels(gs), "deprecated|geoscale_geoframes")
  expect_identical(lv, geoscale_geoframes(gs))
  x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                  capacity = 1:6)
  expect_warning(
    old <- geo_recast(x, gs, from = "atom", to = "country", rule = "sum"),
    "deprecated|recast_geoscale")
  expect_identical(old, recast_geoscale(x, gs, from = "atom",
                                        to = "country", rule = "sum"))
  expect_warning(f <- geo_filter(gs, "country", "N"),
                 "deprecated|filter_geoscale")
  expect_identical(S7::prop(f, "leaftable"),
                   S7::prop(filter_geoscale(gs, "country", "N"), "leaftable"))
  expect_warning(r <- geo_rank(gs, "state"), "deprecated|geoscale_rank")
  expect_identical(r, geoscale_rank(gs, "state"))
})

test_that("2026-08 lattice aliases warn and delegate", {
  gs <- geoscale_example()
  expect_warning(lv <- geoscale_levels(gs), "geoscale_geoframes")
  expect_identical(lv, geoscale_geoframes(gs))
  expect_warning(ok <- is_valid_level("COUNTRY"), "is_valid_geoframe")
  expect_identical(ok, is_valid_geoframe("COUNTRY"))
  expect_identical(CORE_LEVELS, CORE_GEOFRAMES)

  lt <- S7::prop(gs, "leaftable")
  expect_warning(
    g2 <- geoscale_from_leaves(lt, levels = geoscale_geoframes(gs)),
    "geoscale_from_leaftable")
  expect_identical(S7::prop(g2, "leaftable")$region, lt$region)
  # the renamed constructor rejects the old argument names outright
  expect_error(geoscale_from_leaftable(lt, geoframes = geoscale_geoframes(gs),
                                       levels = "x"),
               "renamed")
})
