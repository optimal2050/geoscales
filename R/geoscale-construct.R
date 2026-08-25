# =============================================================================
# Construction — Layer 3 (the escape hatch)
# =============================================================================
# Three layers, mirroring `timescales`:
#
#   Layer 1: `geoscale_from_provider(provider, ...)`  — from a data source
#   Layer 2: `geoscale_build(mapping, ...)`           — from parent-child pairs
#   Layer 3: `geoscale_from_leaftable(leaftable, geoframes)`   — full flexibility
#
# Layers 1 and 2 delegate to layer 3.
# =============================================================================

#' Build a Geoscale from a flat table of leaf regions
#'
#' The general constructor. Takes a wide `data.frame` with one row per atom
#' (the finest region) and one column per geoframe, and returns a [`Geoscale`].
#'
#' Blank strings (`""`) in geoframe columns are normalised to `NA`, meaning "this
#' atom has no code at this geoframe" — partial coverage is normal in real region
#' tables.
#'
#' @param leaftable `data.frame` with one row per atom, one column per name in
#'   `geoframes`, and optionally numeric weight columns.
#' @param geoframes Ordered character vector of geoframe names, **coarsest first**.
#'   Each must be a column of `leaftable`.
#' @param key Name of the column holding the unique atom key. Defaults to
#'   `"region"` if present, otherwise the finest geoframe (the last entry of
#'   `geoframes`), which is copied into a `region` column.
#' @param weights Character vector naming the weight columns. Defaults to all
#'   numeric columns that are neither geoframes nor reserved names.
#' @param default_weight The weight used when a caller does not name one.
#'   Defaults to the first entry of `weights`.
#' @param members Optional named list giving the ordered code vocabulary per
#'   geoframe. Derived from `leaftable` when `NULL` (first-appearance order).
#' @param geometry Optional `sfc` with one geometry per row of `leaftable`.
#' @param name,desc Short name and description.
#' @param ... Further named entries merged into `meta` (e.g. `crs`, `source`).
#'
#' @return A [`Geoscale`].
#'
#' @examples
#' df <- data.frame(
#'   country = c("C1", "C1", "C1", "C2"),
#'   zone    = c("Z1", "Z1", "Z2", "Z3"),
#'   atom    = c("A1", "A2", "A3", "A4"),
#'   km2     = c(100, 200, 300, 400)
#' )
#' geoscale_from_leaftable(df, geoframes = c("country", "zone", "atom"))
#' @export
geoscale_from_leaftable <- function(leaftable,
                                 geoframes,
                                 key = NULL,
                                 weights = NULL,
                                 default_weight = NULL,
                                 members = NULL,
                                 geometry = NULL,
                                 name = "",
                                 desc = "",
                                 ...) {
  extra_names <- names(list(...))
  if (any(c("leaves", "levels") %in% extra_names)) {
    .stop(paste0("arguments `leaves`/`levels` were renamed `leaftable`/",
                 "`geoframes` (2026-08 naming lattice); update the call"))
  }

  if (!is.data.frame(leaftable)) {
    .stop("`leaftable` must be a data.frame")
  }
  leaftable <- as.data.frame(leaftable, stringsAsFactors = FALSE)

  if (!is.character(geoframes) || length(geoframes) == 0L) {
    .stop("`geoframes` must be a non-empty character vector")
  }
  missing_cols <- setdiff(geoframes, names(leaftable))
  if (length(missing_cols) > 0L) {
    .stop("`leaftable` is missing geoframe column(s): %s", .preview(missing_cols))
  }

  # Normalise geoframe columns to character, blanks -> NA ------------------------
  for (lvl in geoframes) {
    leaftable[[lvl]] <- .blank_to_na(leaftable[[lvl]])
  }

  # Atom key ------------------------------------------------------------------
  if (is.null(key)) {
    key <- if ("region" %in% names(leaftable)) "region" else geoframes[length(geoframes)]
  }
  if (!key %in% names(leaftable)) {
    .stop("`key` column \"%s\" not found in `leaftable`", key)
  }
  if (key != "region") {
    leaftable$region <- as.character(leaftable[[key]])
  } else {
    leaftable$region <- as.character(leaftable$region)
  }
  if (anyNA(leaftable$region) || any(!nzchar(leaftable$region))) {
    .stop(paste0("the atom key column \"%s\" has missing or empty values; ",
                 "every atom needs an identifier"), key)
  }

  # Weights -------------------------------------------------------------------
  if (is.null(weights)) {
    cand <- setdiff(names(leaftable), c(geoframes, .RESERVED_COLS, "region"))
    weights <- cand[vapply(leaftable[cand], is.numeric, logical(1))]
  }
  weights <- as.character(weights)
  bad_w <- setdiff(weights, names(leaftable))
  if (length(bad_w) > 0L) {
    .stop("weight column(s) not found in `leaftable`: %s", .preview(bad_w))
  }
  if (is.null(default_weight) && length(weights) > 0L) {
    default_weight <- weights[[1L]]
  }

  # Members -------------------------------------------------------------------
  if (is.null(members)) {
    members <- lapply(geoframes, function(lvl) {
      unique(stats::na.omit(as.character(leaftable[[lvl]])))
    })
    names(members) <- geoframes
  }

  empty <- geoframes[vapply(members[geoframes], length, integer(1)) == 0L]
  if (length(empty) > 0L) {
    .stop("geoframe(s) with no codes at all: %s", .preview(empty))
  }

  # Coarse-to-fine ordering sanity check --------------------------------------
  n_codes <- vapply(members[geoframes], length, integer(1))
  if (length(geoframes) > 1L && is.unsorted(n_codes)) {
    inverted <- geoframes[c(FALSE, diff(n_codes) < 0)]
    .warn(paste0("`geoframes` should be ordered coarsest first, but %s has ",
                 "fewer codes than the geoframe before it. Aggregation ",
                 "direction is taken from this order."),
          .preview(inverted))
  }

  meta <- c(
    list(
      name           = name,
      desc           = desc,
      weights        = weights,
      default_weight = default_weight
    ),
    list(...)
  )

  Geoscale(
    leaftable = leaftable,
    geoframes = geoframes,
    members   = members,
    geometry  = geometry,
    meta      = meta
  )
}

#' A small example Geoscale
#'
#' A synthetic 3-geoframe hierarchy used in examples and tests. It deliberately
#' reproduces three awkward features of real region tables:
#'
#' * a code (`"N1"`) reused at more than one geoframe, so bare codes are
#'   ambiguous and every lookup must name its geoframe;
#' * a non-nesting pair of geoframes — zone `"ZB"` draws atoms from two different
#'   states (and two different countries), so `state` and `zone` do not form a
#'   tree;
#' * an atom (`"ROW"`) with no code at any coarser geoframe (partial coverage).
#'
#' @return A [`Geoscale`] with 7 atoms and geoframes
#'   `country`/`state`/`zone`/`atom`.
#'
#' @examples
#' gs <- geoscale_example()
#' gs
#' geoscale_nests(gs, "state", "zone")   # FALSE - they cross-cut
#' @export
geoscale_example <- function() {
  df <- data.frame(
    country = c("N",  "N",  "N",  "N",  "S",  "S",  NA),
    state   = c("N1", "N1", "N2", "N2", "S1", "S1", NA),
    zone    = c("N1", "N1", "ZB", "ZB", "ZB", "ZC", NA),
    atom    = c("A1", "A2", "A3", "A4", "A5", "A6", "ROW"),
    km2     = c(100,  200,  300,  400,  500,  600,  1000),
    pop     = c(10,   90,   30,   70,   50,   50,   0),
    stringsAsFactors = FALSE
  )
  geoscale_from_leaftable(
    df,
    geoframes = c("country", "state", "zone", "atom"),
    name   = "example",
    desc   = paste("Synthetic example: reused code, non-nesting geoframe pair,",
                   "and an unassigned atom")
  )
}
