# =========================================================================== #
# coords_to_region(): the spatial twin of timescales::datetime_to_timeslice()
# -- raw point observations enter the structure here.
# =========================================================================== #

skip_if_not_installed("sf")

# unit squares: A1..A6 on a 3 x 2 grid (same fixture as the README demo)
.sq_gs <- function() {
  sq <- function(x, y) sf::st_polygon(list(cbind(
    c(x, x + 1, x + 1, x, x), c(y, y, y + 1, y + 1, y))))
  gs <- geoscale_from_leaftable(
    data.frame(
      country = c("N", "N", "N", "N", "S", "S"),
      state   = c("N1", "N1", "N2", "N2", "S1", "S1"),
      atom    = paste0("A", 1:6),
      km2     = 1
    ),
    geoframes = c("country", "state", "atom"), name = "sq")
  attach_geometry_geoscale(gs, sf::st_sfc(
    sq(0, 1), sq(0, 0), sq(1, 1), sq(1, 0), sq(2, 1), sq(2, 0),
    crs = 4326))
}

test_that("points resolve to atoms by default; outside points are NA", {
  gs <- .sq_gs()
  pts <- data.frame(lon = c(0.5, 1.5, 2.5, 9.0), lat = c(1.5, 0.5, 0.5, 9.0))
  expect_equal(coords_to_region(pts, gs), c("A1", "A4", "A6", NA))
  # length always matches the input rows
  expect_length(coords_to_region(pts, gs), nrow(pts))
})

test_that("geoframe= resolves at a coarser level; sf input works", {
  gs <- .sq_gs()
  pts <- data.frame(lon = c(0.5, 2.5), lat = c(1.5, 0.5))
  expect_equal(coords_to_region(pts, gs, geoframe = "state"), c("N1", "S1"))
  expect_equal(coords_to_region(pts, gs, geoframe = "country"), c("N", "S"))

  sfp <- sf::st_as_sf(pts, coords = c("lon", "lat"), crs = 4326)
  expect_equal(coords_to_region(sfp, gs, geoframe = "country"), c("N", "S"))
})

test_that("missing coordinate columns and no geometry error clearly", {
  gs <- .sq_gs()
  expect_error(coords_to_region(data.frame(x = 1, y = 2), gs),
               "coordinate column")
  bare <- geoscale_from_leaftable(
    data.frame(zone = "Z", atom = "A", km2 = 1),
    geoframes = c("zone", "atom"), name = "bare")
  expect_error(coords_to_region(data.frame(lon = 0, lat = 0), bare),
               "no geometry")
})

# --------------------------------------------------------------------------- #
# The new query twins

test_that("geoscale_leaftable is the exported table accessor", {
  gs <- geoscale_example()
  expect_identical(geoscale_leaftable(gs), S7::prop(gs, "leaftable"))
})

test_that("geoscale_regions defaults to the finest geoframe", {
  gs <- geoscale_example()
  expect_equal(geoscale_regions(gs),
               geoscale_regions(gs, geoscale_geoframes(gs, finest = TRUE)))
})
