# =========================================================================== #
# Canonical test fixtures, shared by every test file.
#
# geoscale_example() (exported) stays the base object: country/state/zone
# over atoms A1..A6 + the uncovered ROW row, weights km2 + pop, zone
# cross-cutting state (ZB straddles N2 and S1). The builders here wrap the
# other recurring shapes so test files stop re-deriving them.
# =========================================================================== #

# The cross-cutting second Geoscale sharing the A1..A6 atom keys (bands X/Y
# interleaved) -- the two-object join/map/crosswalk fixture.
.bands_gs <- function() {
  lf <- data.frame(band = rep(c("X", "Y"), 3),
                   atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                   km2 = c(100, 200, 300, 400, 500, 600))
  geoscale_from_leaftable(lf, geoframes = c("band", "atom"),
                          name = "bands")
}

# Unit squares with geometry: A1..A6 on a 3 x 2 grid under N/S countries and
# N1/N2/S1 states (the coords_to_region and dissolve fixture).
.squares_gs <- function() {
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

# A standard keyed value table on a Geoscale's atoms: `values` named numeric
# columns recycled over the atoms; optional `ids` replicates the block per id
# (panel shape). Uncovered atoms (NA at every geoframe, like ROW) are
# excluded so totals stay known.
fx_tbl <- function(gs = geoscale_example(), values = list(cap = NULL),
                   ids = NULL) {
  lt <- geoscale_leaftable(gs)
  atom_col <- geoscale_geoframes(gs, finest = TRUE)
  covered <- !Reduce(`&`, lapply(
    setdiff(geoscale_geoframes(gs), atom_col),
    function(gf) is.na(lt[[gf]])))
  atoms <- as.character(lt[[atom_col]][covered])
  base <- stats::setNames(data.frame(atoms, stringsAsFactors = FALSE),
                          atom_col)
  for (nm in names(values)) {
    v <- values[[nm]]
    base[[nm]] <- if (is.null(v)) as.numeric(seq_along(atoms)) else
      rep_len(as.numeric(v), length(atoms))
  }
  if (is.null(ids)) return(base)
  out <- do.call(rbind, lapply(ids, function(id) {
    b <- base
    b$id <- id
    b
  }))
  rownames(out) <- NULL
  out
}
