# =============================================================================
# Construction — Layer 1 (providers)
# =============================================================================
# geoscales ships integration code, NOT data. There is no `data/` directory,
# no bundled maps, and no baked-in boundaries: the package passes a point of
# view through, records it in `@meta`, and leaves the choice to the user.
#
# A provider turns an external source into a wide `sf`/data.frame that
# `geoscale_from_leaves()` can consume. `rnaturalearth` is the default;
# giscoR (NUTS), geodata/GADM and tigris slot into the same interface.
# =============================================================================

#' @noRd
.PROVIDER_REGISTRY <- new.env(parent = emptyenv())

#' Register a Geoscale data provider
#'
#' A provider is a function `function(...)` returning either an `sf` object or
#' a `data.frame`, wide enough that its columns can be used as levels and
#' weights.
#'
#' @param name Provider name.
#' @param fetch Function returning the source table.
#' @param levels Default level columns, coarsest first.
#' @param weights Default weight columns.
#' @param desc One-line description.
#'
#' @return Invisibly, the registered provider.
#'
#' @examples
#' register_geo_provider(
#'   "toy",
#'   fetch = function(...) data.frame(top = c("T", "T"),
#'                                    unit = c("a", "b"), km2 = c(1, 2)),
#'   levels = c("top", "unit"), weights = "km2"
#' )
#' list_geo_providers()
#' @export
register_geo_provider <- function(name, fetch, levels = NULL,
                                  weights = NULL, desc = "") {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    .stop("`name` must be a single non-empty string")
  }
  if (!is.function(fetch)) .stop("`fetch` must be a function")
  entry <- list(name = name, fetch = fetch, levels = levels,
                weights = weights, desc = desc)
  assign(name, entry, envir = .PROVIDER_REGISTRY)
  invisible(entry)
}

#' Look up a registered provider
#'
#' @param name Provider name.
#'
#' @return The provider entry, or an error if unknown.
#'
#' @examples
#' get_geo_provider("naturalearth")$desc
#' @export
get_geo_provider <- function(name) {
  if (!is.character(name) || length(name) != 1L ||
      !exists(name, envir = .PROVIDER_REGISTRY, inherits = FALSE)) {
    .stop("unknown provider \"%s\"; registered: %s",
          as.character(name)[1L],
          paste(ls(envir = .PROVIDER_REGISTRY), collapse = ", "))
  }
  get(name, envir = .PROVIDER_REGISTRY, inherits = FALSE)
}

#' List registered providers
#'
#' @return A `data.frame` with columns `name` and `desc`.
#'
#' @examples
#' list_geo_providers()
#' @export
list_geo_providers <- function() {
  nms <- sort(ls(envir = .PROVIDER_REGISTRY))
  data.frame(
    name = nms,
    desc = vapply(nms, function(n) get_geo_provider(n)$desc %||% "",
                  character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' Build a Geoscale from a provider
#'
#' Fetches a source table from a registered provider and turns it into a
#' [`Geoscale`]. Level and weight defaults come from the provider when not
#' given.
#'
#' @param provider Provider name, or a source `sf`/`data.frame` to use
#'   directly.
#' @param levels Level columns, coarsest first.
#' @param weights Weight columns.
#' @param geometry Attach geometry when the source is an `sf` object.
#' @param name,desc Short name and description for the result.
#' @param ... Passed to the provider's `fetch()`.
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' \dontrun{
#' # Countries nested in UN subregion and continent, weighted by population
#' gs <- geoscale_from_provider(
#'   "naturalearth",
#'   levels  = c("continent", "subregion", "adm0_a3"),
#'   weights = c("pop_est", "gdp_md"),
#'   scale   = 110
#' )
#' }
#' @export
geoscale_from_provider <- function(provider = "naturalearth",
                                   levels = NULL,
                                   weights = NULL,
                                   geometry = TRUE,
                                   name = "",
                                   desc = "",
                                   ...) {
  if (is.character(provider)) {
    p   <- get_geo_provider(provider)
    src <- p$fetch(...)
    levels  <- levels  %||% p$levels
    weights <- weights %||% p$weights
    src_name <- provider
  } else {
    src <- provider
    src_name <- "custom"
  }
  if (is.null(levels)) {
    .stop("`levels` must be given (the provider declares no default)")
  }

  geom <- NULL
  if (inherits(src, "sf")) {
    if (isTRUE(geometry) && requireNamespace("sf", quietly = TRUE)) {
      geom <- sf::st_geometry(src)
    }
    src <- as.data.frame(src)
    src[[attr(src, "sf_column") %||% "geometry"]] <- NULL
  }
  src <- as.data.frame(src, stringsAsFactors = FALSE)
  src$geometry <- NULL

  missing_lv <- setdiff(levels, names(src))
  if (length(missing_lv) > 0L) {
    .stop("source has no column(s): %s", .preview(missing_lv))
  }

  keep <- c(levels, intersect(weights, names(src)))
  out <- src[, keep, drop = FALSE]

  gs <- geoscale_from_leaves(
    out, levels = levels, weights = intersect(weights, names(src)),
    name = name, desc = desc, source = src_name
  )
  if (!is.null(geom)) {
    gs <- Geoscale(
      leaves = S7::prop(gs, "leaves"), levels = S7::prop(gs, "levels"),
      members = S7::prop(gs, "members"), geometry = geom,
      meta = S7::prop(gs, "meta")
    )
  }
  gs
}
