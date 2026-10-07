# =============================================================================
# join_geoscale() -- attach a Geoscale to region-keyed data
# =============================================================================
# The spatial mirror of timescales::join_calendar(): adds a region-label
# column NAMED AFTER THE GEOSCALE (meta$name), so several Geoscales can live
# side by side on one dataset -- and the pair of label columns is itself a
# direct conversion route between those objects. Optional coarser-geoframe
# membership columns plus share/weight come prefixed "<name>." so a second
# Geoscale never collides with the first. Existing columns are never
# overwritten; the join errors instead. Runs as a dplyr join against a small
# in-memory frame, so any supported backend works (see R/backend.R).
#
# Geoframes may cross-cut: a code whose atoms sit under MORE THAN ONE parent
# at a coarser geoframe gets NA there (with a warning) -- membership is only
# well-defined where the geoframes nest.
# =============================================================================

#' Attach a Geoscale to region-keyed data
#'
#' Adds a region-label column named after the Geoscale (its `meta$name`),
#' plus optionally coarser-geoframe membership columns (each code's
#' country, continent, ...) and share/weight, all prefixed `"<name>."`.
#' Because every Geoscale attaches under its own name, several can be
#' joined to the same dataset -- and a dataset carrying two label columns
#' is a direct crosswalk between those objects. The spatial mirror of
#' `timescales::join_calendar()`.
#'
#' The key is auto-detected: an existing column named like the Geoscale is
#' used as-is; else a column named like the keyed geoframe; else `region`.
#' Codes are validated against the geoframe (unknown codes warn).
#' Existing columns are never overwritten; the join errors instead.
#'
#' @param x The dataset, in any supported backend (see
#'   [`recast_geoscale()`]'s Backends section).
#' @param gs A named [`Geoscale`].
#' @param key Name of the code column in `x`. `NULL` (default)
#'   auto-detects as described above.
#' @param geoframe Geoframe the codes belong to. Inferred when exactly one
#'   of the object's geoframe names is a column of `x`.
#' @param geoframes Coarser geoframes to attach as `"<name>.<geoframe>"`
#'   membership columns (default: none). `TRUE` attaches all geoframes
#'   coarser than `geoframe`.
#' @param meta Attach `"<name>.share"` and `"<name>.weight"` columns
#'   (summed atom weights of each keyed code, shares normalised over the
#'   geoframe; default `FALSE`). Skipped with a warning when the object
#'   declares no weights.
#' @param weight Weight column for the meta columns; `NULL` uses the
#'   default weight.
#' @param as_factor Attach membership columns as vocabulary-ordered
#'   factors (default `TRUE`) or plain character. (Lazy backends store
#'   them as dictionary/character columns.)
#' @param collect For lazy inputs: materialise (`TRUE`) or return the
#'   query (default).
#'
#' @return `x` with the new column(s) appended, in the input's class
#'   (lazy in, lazy out).
#'
#' @examples
#' gs <- geoscale_example()
#' x <- data.frame(state = c("N1", "N2", "S1"), v = 1:3)
#' join_geoscale(x, gs, geoframes = TRUE)
#' join_geoscale(x, gs, meta = TRUE)
#' @export
join_geoscale <- function(x, gs, key = NULL, geoframe = NULL,
                          geoframes = NULL, meta = FALSE, weight = NULL,
                          as_factor = TRUE, collect = NULL) {
  .check_geoscale(gs, "gs")
  if (is.null(geoframe)) {
    hit <- intersect(geoscale_geoframes(gs), names(.gs_schema(x)))
    if (length(hit) != 1L) {
      .stop(paste0("cannot infer the code geoframe from `x`'s columns ",
                   "(found: %s); pass `geoframe=`"),
            if (length(hit) == 0L) "none" else .preview(hit))
    }
    geoframe <- hit
  }
  .check_geoframe(gs, geoframe, "geoframe")
  discretescales::join_scale(x, gs, key = key, frame = geoframe,
                          attach = geoframes, meta = meta, weight = weight,
                          as_factor = as_factor, collect = collect)
}
