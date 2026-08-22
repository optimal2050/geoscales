# =============================================================================
# Natural Earth provider
# =============================================================================
# Natural Earth's country table is already a wide leaves table: one `sf`
# object carries the whole nest as columns —
#
#   continent (8) -> region_un -> subregion -> sovereignt
#                 -> admin/adm0_a3 (177) -> geounit -> subunit
#
# plus `pop_est` and `gdp_md` as ready-made weights. `ne_states()` adds
# admin-1 units carrying ISO 3166-2 codes.
#
# =============================================================================

#' Fetch a Natural Earth source table
#'
#' Thin wrapper over `rnaturalearth::ne_countries()` / `ne_states()` that
#' normalises the country-code column.
#'
#' @param scale Natural Earth scale: `110`, `50` or `10`. Note that `110` is
#'   unsuitable for area weights (see details).
#' @param geoframe `"country"` (admin-0) or `"states"` (admin-1). Admin-1
#'   requires `rnaturalearthhires`, which is **not on CRAN** — install it from
#'   <https://ropensci.r-universe.dev>.
#' @param country Optional country filter passed through to
#'   `rnaturalearth`.
#' @param ... Passed to the underlying `rnaturalearth` function.
#'
#' @return An `sf` object with two added columns: `feature`, the Natural Earth
#'   unit (`adm0_a3`, or `adm1_code` for states), and `country`, its admin-0
#'   code.
#'
#' @details
#' `feature` is the atom and `country` is a grouping of atoms on top of it. At
#' admin-0 the two are the same code; at admin-1 (`geoframe = "states"`) `feature`
#' is the state and `country` is the admin-0 unit it belongs to.
#'
#' Codes of `"-99"` mean *unassigned* and are returned as `NA`. That is why
#' `country` is a geoframe rather than the atom key: it may be missing, whereas an
#' atom key may not.
#'
#' @examples
#' \dontrun{
#' ne_source(scale = 110)
#' ne_source(scale = 10, geoframe = "states", country = "Iceland")
#' }
#' @export
ne_source <- function(scale = 110, geoframe = c("country", "states"),
                      country = NULL, ...) {
  geoframe <- match.arg(geoframe)
  if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
    .stop(paste0("the Natural Earth provider requires 'rnaturalearth'. ",
                 "Install it with install.packages(\"rnaturalearth\")."))
  }

  if (geoframe == "states") {
    if (!requireNamespace("rnaturalearthhires", quietly = TRUE)) {
      .stop(paste0("admin-1 data requires 'rnaturalearthhires', which is not ",
                   "on CRAN. Install it with:\n  install.packages(",
                   "\"rnaturalearthhires\", repos = ",
                   "\"https://ropensci.r-universe.dev\")"))
    }
    x <- rnaturalearth::ne_states(country = country, returnclass = "sf", ...)
    x$feature <- .ne_na99(x$adm1_code)
    x$country <- .ne_na99(x$adm0_a3)
    return(.ne_check_key(x, "adm1_code"))
  }

  x <- rnaturalearth::ne_countries(scale = scale, country = country,
                                   returnclass = "sf", ...)

  # Gotcha 1: adm0_a3 is the only code column with no "-99" holes, so it is
  # the atom key, and at admin-0 it is the country grouping as well.
  x$feature <- .ne_na99(x$adm0_a3)
  x$country <- .ne_na99(x$adm0_a3)
  .ne_check_key(x, "adm0_a3")
}

#' @noRd
.ne_check_key <- function(x, what) {
  f <- x$feature
  if (anyNA(f)) {
    .stop("Natural Earth returned %d feature(s) with no `%s`", sum(is.na(f)),
          what)
  }
  if (anyDuplicated(f)) {
    dup <- unique(f[duplicated(f)])
    .stop("Natural Earth returned duplicated `%s`: %s", what, .preview(dup))
  }
  x
}

#' Natural Earth uses "-99" for "no code / unassigned"
#' @noRd
.ne_na99 <- function(x) {
  x <- as.character(x)
  x[!is.na(x) & x == "-99"] <- NA_character_
  x
}

#' Natural Earth uses -99 as "unknown" in numeric attributes too
#'
#' At 1:10m the Vatican has `gdp_md = -99`. Left alone this trips the
#' Geoscale validator, which requires weights to be non-negative.
#' @noRd
.ne_na99_num <- function(x) {
  x <- as.numeric(x)
  x[!is.na(x) & x == -99] <- NA_real_
  x
}

#' Build a Geoscale from Natural Earth
#'
#' Convenience wrapper: fetches Natural Earth via [`ne_source()`] and builds a
#' [`Geoscale`] nested `continent -> subregion -> country -> feature`,
#' weighted by population and GDP.
#'
#' `feature` is the atom: the Natural Earth unit. `country` sits above it as a
#' grouping of atoms, so it can only ever be coarser than `feature`.
#'
#' @inheritParams ne_source
#' @param geoframes Geoframe columns, coarsest first.
#' @param weights Weight columns.
#' @param geometry Attach geometry.
#'
#' @return A [`Geoscale`], with `scale` and `source` recorded in `@meta` so the
#'   object is self-documenting and reproducible.
#'
#' @details
#' Do not derive area weights from `scale = 110`; see [`add_area_geoscale()`].
#'
#' @examples
#' \dontrun{
#' gs <- ne_geoscale(scale = 110)
#'
#' # roll population up from countries to sub-regions
#' lf <- S7::prop(gs, "leaftable")
#' pop <- data.frame(country = lf$country, pop = lf$pop_est)
#' recast_geoscale(pop[!is.na(pop$country), ], gs,
#'            from = "country", to = "subregion", rule = "sum")
#' }
#' @export
ne_geoscale <- function(scale = 110,
                        geoframes = c("continent", "subregion", "country",
                                   "feature"),
                        weights = c("pop_est", "gdp_md"),
                        geometry = TRUE,
                        ...) {
  src <- ne_source(scale = scale, ...)

  # Gotcha 4: -99 means "unknown" in numeric attributes as well as codes.
  for (w in intersect(weights, names(src))) {
    if (is.numeric(src[[w]])) src[[w]] <- .ne_na99_num(src[[w]])
  }

  if (scale == 110 && any(grepl("km2|area", weights, ignore.case = TRUE))) {
    .warn(paste0("scale = 110 is a cartographic generalisation and is not ",
                 "suitable for area weights (Chile is +10.6%%, Indonesia ",
                 "-3.2%% against 1:10m). Use scale = 10."))
  }

  gs <- geoscale_from_provider(
    src, geoframes = geoframes, weights = weights, geometry = geometry,
    name = sprintf("naturalearth-%s", scale),
    desc = "Natural Earth admin-0 hierarchy"
  )

  meta <- S7::prop(gs, "meta")
  meta$source <- "naturalearth"
  meta$scale  <- scale
  Geoscale(leaftable = S7::prop(gs, "leaftable"), geoframes = S7::prop(gs, "geoframes"),
           members = S7::prop(gs, "members"),
           geometry = S7::prop(gs, "geometry"), meta = meta)
}

# Register at load time --------------------------------------------------------

#' @noRd
.register_builtin_providers <- function() {
  register_geo_provider(
    "naturalearth",
    fetch   = function(...) ne_source(...),
    geoframes  = c("continent", "subregion", "country", "feature"),
    weights = c("pop_est", "gdp_md"),
    desc    = "Natural Earth admin-0/admin-1 (rnaturalearth)"
  )
  invisible()
}
