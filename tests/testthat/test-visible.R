# Geoframes hidden from plots.

test_that("hiding and showing geoframes round-trips", {
  gs <- geoscale_example()
  expect_identical(geoscale_geoframes(gs, visible = FALSE), character())
  h <- hide_geoframes_geoscale(gs, c("atom", "zone"))
  expect_identical(geoscale_geoframes(h, visible = FALSE), c("zone", "atom"))
  expect_identical(geoscale_geoframes(h, visible = TRUE),
                   c("country", "state"))
  expect_identical(geoscale_geoframes(h, finest = TRUE, visible = TRUE),
                   "state")
  # the plain call still lists every geoframe
  expect_identical(geoscale_geoframes(h), geoscale_geoframes(gs))
  expect_identical(geoscale_geoframes(h, finest = TRUE), "atom")

  s <- show_geoframes_geoscale(h, "zone")
  expect_identical(geoscale_geoframes(s, visible = FALSE), "atom")
  expect_identical(
    geoscale_geoframes(show_geoframes_geoscale(h), visible = FALSE),
    character())
  expect_output(print(h), "Hidden in plots: zone, atom")
  expect_identical(summary(h)$hidden, c("zone", "atom"))
})

test_that("the hidden set is validated", {
  gs <- geoscale_example()
  expect_error(hide_geoframes_geoscale(gs, "nope"), "not a geoframe")
  expect_error(hide_geoframes_geoscale(gs, geoscale_geoframes(gs)),
               "may not cover every geoframe")
  lt <- data.frame(top = "T", atom = c("a", "b"))
  expect_error(
    geoscale_from_leaftable(lt, geoframes = c("top", "atom"),
                            hidden = "nope"),
    "not in the object")
  g <- geoscale_from_leaftable(lt, geoframes = c("top", "atom"),
                               hidden = "atom")
  expect_identical(geoscale_geoframes(g, visible = TRUE), "top")
})

test_that("hiding changes nothing but the plots", {
  gs <- geoscale_example()
  h <- hide_geoframes_geoscale(gs, "atom")
  expect_identical(geoscale_regions(h, "atom"), geoscale_regions(gs, "atom"))
  x <- data.frame(atom = c("A1", "A2", "A3"), v = c(1, 2, 3))
  expect_equal(recast_geoscale(x, h, source = "atom", target = "country",
                               rule = "sum"),
               recast_geoscale(x, gs, source = "atom", target = "country",
                               rule = "sum"))
  skip_if(is.null(get0("scale_id", envir = asNamespace("nestedscales"))),
          "the installed nestedscales has no scale identity")
  expect_identical(geoscale_id(h), geoscale_id(gs))
})

test_that("subsets keep the hidden set of the geoframes that remain", {
  gs <- hide_geoframes_geoscale(geoscale_example(), c("zone", "atom"))
  f <- filter_geoscale(gs, "country", "N")
  expect_identical(geoscale_geoframes(f, visible = FALSE), c("zone", "atom"))
  # pruning away every hidden geoframe leaves nothing hidden
  p <- prune_geoscale(gs, "state")
  expect_identical(geoscale_geoframes(p, visible = FALSE), character())
  # a hidden geoframe that survives the prune stays hidden
  p2 <- prune_geoscale(hide_geoframes_geoscale(geoscale_example(), "state"),
                       "state")
  expect_identical(geoscale_geoframes(p2, visible = FALSE), "state")
})

test_that("an object saved without the property reads as nothing hidden", {
  gs <- geoscale_example()
  attr(gs, "hidden") <- NULL
  expect_identical(geoscale_geoframes(gs, visible = FALSE), character())
  expect_identical(geoscale_geoframes(gs, visible = TRUE),
                   geoscale_geoframes(gs))
  expect_no_error(S7::validate(gs))
})

test_that("the icicle leaves hidden geoframes out unless asked", {
  skip_if_not_installed("ggplot2")
  gs <- geoscale_example()
  h <- hide_geoframes_geoscale(gs, "atom")
  expect_setequal(unique(gg_geoscale(h)$data$geoframe),
                  c("country", "state", "zone"))
  expect_setequal(unique(gg_geoscale(h, geoframes = TRUE)$data$geoframe),
                  geoscale_geoframes(gs))
  expect_setequal(
    unique(gg_geoscale(h, geoframes = c("country", "atom"))$data$geoframe),
    c("country", "atom"))
  expect_error(gg_geoscale(h, geoframes = "nope"), "unknown")
  # widths of the bands still come from the atoms
  full <- geoscale_layout(gs, geoframes = TRUE)
  part <- geoscale_layout(h)
  one <- function(d) d[d$geoframe == "state", c("region", "xmin", "xmax")]
  expect_equal(one(part), one(full), ignore_attr = TRUE)
})

test_that("values reach a hidden geoframe's parents through it", {
  skip_if_not_installed("ggplot2")
  gs <- geoscale_example()
  h <- hide_geoframes_geoscale(gs, "atom")
  x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                  v = c(1, 2, 3, 4, 5, 6))
  d <- gg_geoscale(h, data = x, z = "v", rule = "sum")$data
  by_hand <- recast_geoscale(x, gs, source = "atom", target = "country",
                             rule = "sum")
  got <- d[d$geoframe == "country", ]
  expect_equal(got$.fill[match(by_hand$country, got$region)], by_hand$v)
  expect_false("atom" %in% d$geoframe)
})

test_that("data keyed above the atoms is recast from its own geoframe", {
  skip_if_not_installed("ggplot2")
  gs <- geoscale_example()
  x <- data.frame(state = c("N1", "N2", "S1"), v = c(10, 20, 30))
  d <- gg_geoscale(gs, data = x, z = "v", rule = "sum")$data
  by_hand <- recast_geoscale(x, gs, source = "state", target = "country",
                             rule = "sum")
  got <- d[d$geoframe == "country", ]
  expect_equal(got$.fill[match(by_hand$country, got$region)], by_hand$v)
  st <- d[d$geoframe == "state", ]
  expect_equal(st$.fill[match(x$state, st$region)], x$v)
  # finer, and cross-cutting, geoframes carry no value
  expect_false(any(d$.valued[d$geoframe %in% c("zone", "atom")]))
  # `key` states the geoframe when the column could be read otherwise
  y <- data.frame(state = c("N1", "N2", "S1"), country = c("N", "N", "S"),
                  v = c(10, 20, 30))
  dk <- gg_geoscale(gs, data = y, z = "v", rule = "sum", key = "state")$data
  expect_equal(dk$.fill, d$.fill)
  expect_error(gg_geoscale(gs, data = y, z = "v", key = "zone"),
               "no column")
})
