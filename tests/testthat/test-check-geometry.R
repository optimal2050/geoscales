# check_geometry_geoscale(): is each shape on the row of its code?

.sq <- function(x, y, s = 1) {
  sf::st_polygon(list(rbind(c(x, y), c(x + s, y), c(x + s, y + s),
                            c(x, y + s), c(x, y))))
}

# four unit squares in a row, two per group, with distinct widths so that
# areas tell the atoms apart
.grid_gs <- function() {
  skip_if_not_installed("sf")
  lt <- data.frame(top = c("L", "L", "R", "R"), atom = c("a", "b", "c", "d"))
  g <- sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
    sf::st_polygon(list(rbind(c(1, 0), c(3, 0), c(3, 1), c(1, 1), c(1, 0)))),
    sf::st_polygon(list(rbind(c(3, 0), c(6, 0), c(6, 1), c(3, 1), c(3, 0)))),
    sf::st_polygon(list(rbind(c(6, 0), c(10, 0), c(10, 1), c(6, 1), c(6, 0)))))
  gs <- geoscale_from_leaftable(lt, geoframes = c("top", "atom"))
  list(gs = attach_geometry_geoscale(gs, g),
       ref = sf::st_sf(atom = lt$atom, geometry = g))
}

test_that("a sound object passes, with and without a reference", {
  k <- .grid_gs()
  r <- check_geometry_geoscale(k$gs)
  expect_s3_class(r, "geoscale_geometry_check")
  expect_named(r, c("check", "geoframe", "region", "status", "detail"))
  expect_false(any(r$status %in% c("fail", "warn")))
  expect_false("reference" %in% r$check)
  expect_output(print(r), "evidence, not proof")

  p <- check_geometry_geoscale(k$gs, reference = k$ref)
  expect_true(all(p$status[p$check == "reference"] == "ok"))
  expect_match(p$detail[p$check == "reference"], "4 of 4")
  expect_output(print(p), "passed")
})

test_that("shapes on the wrong rows are found against a reference", {
  k <- .grid_gs()
  bad <- S7::set_props(k$gs, geometry = S7::prop(k$gs, "geometry")[c(2, 1, 3, 4)])
  expect_warning(r <- check_geometry_geoscale(bad, reference = k$ref),
                 "failed 2 check")
  f <- r[r$check == "reference" & !is.na(r$region), ]
  expect_setequal(f$region, c("a", "b"))
  expect_match(f$detail[f$region == "a"], "reference shape of `b`")
  expect_match(f$detail[f$region == "b"], "reference shape of `a`")
  expect_output(print(r), "FAILED")
  # the reference may be in any row order, and under another column name
  ref2 <- k$ref[c(4, 2, 1, 3), ]
  names(ref2)[names(ref2) == "atom"] <- "code"
  sf::st_geometry(ref2) <- "geometry"
  ok <- check_geometry_geoscale(k$gs, reference = ref2, by = "code")
  expect_true(all(ok$status[ok$check == "reference"] == "ok"))
  expect_error(check_geometry_geoscale(k$gs, reference = ref2), "`by`")
})

test_that("an area weight in another row order gives the misplacement away", {
  k <- .grid_gs()
  gs <- suppressWarnings(add_area_geoscale(k$gs, name = "area"))
  r <- check_geometry_geoscale(gs)
  expect_equal(r$status[r$check == "area"], "ok")
  moved <- S7::set_props(gs, geometry = S7::prop(gs, "geometry")[c(4, 3, 2, 1)])
  expect_warning(r2 <- check_geometry_geoscale(moved), "failed")
  expect_equal(r2$status[r2$check == "area"], "fail")
  expect_silent(check_geometry_geoscale(moved, quiet = TRUE))
})

test_that("a region in several pieces is a warning, not a failure", {
  k <- .grid_gs()
  # a and c grouped together: they do not touch
  split <- S7::set_props(k$gs, geometry = S7::prop(k$gs, "geometry")[c(1, 3, 2, 4)])
  r <- check_geometry_geoscale(split, quiet = TRUE)
  p <- r[r$check == "pieces", ]
  expect_true(all(p$status == "warn"))
  expect_setequal(p$region, c("L", "R"))
  expect_false(any(r$status == "fail"))
  expect_output(print(r), "passed with warnings")
})

test_that("empty and repeated shapes are reported", {
  k <- .grid_gs()
  g <- S7::prop(k$gs, "geometry")
  g[2] <- g[1]
  r <- check_geometry_geoscale(S7::set_props(k$gs, geometry = g), quiet = TRUE)
  d <- r[r$check == "duplicate", ]
  expect_equal(d$region, "a")
  expect_match(d$detail, "held by b")
})

test_that("a coarser geoframe is compared on its dissolved shapes", {
  k <- .grid_gs()
  g <- sf::st_geometry(k$ref)
  top <- sf::st_sf(top = c("L", "R"),
                   geometry = c(sf::st_union(g[1:2]), sf::st_union(g[3:4])))
  r <- check_geometry_geoscale(k$gs, reference = top, geoframe = "top")
  expect_match(r$detail[r$check == "reference"], "2 of 2 shapes at `top`")
  # several reference features per code are dissolved first
  parts <- sf::st_sf(top = c("L", "L", "R", "R"), geometry = g)
  r2 <- check_geometry_geoscale(k$gs, reference = parts, geoframe = "top")
  expect_equal(r2$status[r2$check == "reference"], "ok")
})

test_that("the object must carry geometry", {
  expect_error(check_geometry_geoscale(geoscale_example()), "no geometry")
})
