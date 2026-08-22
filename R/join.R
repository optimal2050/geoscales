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
  backend <- .gs_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  gs_nm  <- .geoscale_name(gs)
  schema <- .gs_schema(x)

  leaves  <- S7::prop(gs, "leaftable")
  gf_all  <- S7::prop(gs, "geoframes")
  members <- S7::prop(gs, "members")

  # -- resolve the keyed geoframe and the key ---------------------------------
  if (is.null(geoframe)) {
    hit <- intersect(gf_all, names(schema))
    if (length(hit) != 1L) {
      .stop(paste0("cannot infer the code geoframe from `x`'s columns ",
                   "(found: %s); pass `geoframe=`"),
            if (length(hit) == 0L) "none" else .preview(hit))
    }
    geoframe <- hit
  }
  .check_geoframe(gs, geoframe, "geoframe")
  if (is.null(key)) {
    key <- if (gs_nm %in% names(schema)) gs_nm
           else if (geoframe %in% names(schema)) geoframe
           else if ("region" %in% names(schema)) "region"
           else .stop(paste0("`x` has no `%s`, `%s`, or `region` column; ",
                             "pass `key=`"), gs_nm, geoframe)
  }
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }

  # -- what gets attached -----------------------------------------------------
  coarser <- gf_all[seq_len(match(geoframe, gf_all) - 1L)]
  if (isTRUE(geoframes)) geoframes <- coarser
  if (!is.null(geoframes) && !isFALSE(geoframes)) {
    bad <- setdiff(geoframes, coarser)
    if (length(bad) > 0L) {
      .stop("`geoframes` must be coarser than '%s'; not: %s", geoframe,
            .preview(bad))
    }
  } else {
    geoframes <- character(0)
  }
  new_cols <- c(if (key != gs_nm) gs_nm,
                paste0(gs_nm, ".", geoframes),
                if (isTRUE(meta)) paste0(gs_nm, c(".share", ".weight")))
  clash <- intersect(new_cols, names(schema))
  if (length(clash) > 0L) {
    .stop(paste0("attaching Geoscale \"%s\" would overwrite existing ",
                 "column(s): %s"), gs_nm, .preview(clash))
  }
  if (length(new_cols) == 0L) {
    return(x)   # label column already there, nothing else requested
  }

  # -- validate the keys (eager, small) ---------------------------------------
  known <- unique(stats::na.omit(as.character(leaves[[geoframe]])))
  keys <- .gs_pull(
    dplyr::distinct(dplyr::select(.gs_lazy(x, backend),
                                  dplyr::all_of(key))))[[key]]
  keys <- unique(stats::na.omit(as.character(keys)))
  if (length(intersect(keys, known)) == 0L) {
    .stop("no rows of `x$%s` match regions at geoframe '%s'", key, geoframe)
  }
  unknown <- setdiff(keys, known)
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not regions at geoframe '%s': %s",
          length(unknown), key, geoframe, .preview(unknown))
  }

  # -- the in-memory attach frame ---------------------------------------------
  attach_df <- data.frame(.gs_label = known, stringsAsFactors = FALSE)

  # membership columns: unique (geoframe, coarser) pairs; codes under more
  # than one parent are ambiguous -> NA + warning
  for (cl in geoframes) {
    pairs <- unique(leaves[!is.na(leaves[[geoframe]]),
                           c(geoframe, cl), drop = FALSE])
    n_par <- table(pairs[[geoframe]])
    multi <- names(n_par)[n_par > 1L]
    if (length(multi) > 0L) {
      .warn(paste0("geoframe '%s' does not nest in '%s'; %d code(s) have ",
                   "multiple parents and get NA (e.g. %s)"),
            geoframe, cl, length(multi), .preview(multi))
      pairs <- pairs[!pairs[[geoframe]] %in% multi, , drop = FALSE]
    }
    val <- as.character(pairs[[cl]])[match(known, pairs[[geoframe]])]
    attach_df[[paste0(gs_nm, ".", cl)]] <-
      if (isTRUE(as_factor)) factor(val, levels = members[[cl]]) else val
  }

  # share / weight at the keyed geoframe (skipped when no weight exists)
  if (isTRUE(meta)) {
    wcol <- tryCatch(.resolve_weight(gs, weight), error = function(e) NULL)
    if (is.null(wcol)) {
      .warn(paste0("Geoscale \"%s\" declares no weight columns; ",
                   "`meta = TRUE` share/weight skipped"), gs_nm)
    } else {
      w <- stats::aggregate(as.numeric(leaves[[wcol]]),
                            by = list(code = as.character(
                              leaves[[geoframe]])),
                            FUN = sum, na.rm = TRUE)
      ww <- w$x[match(known, w$code)]
      attach_df[[paste0(gs_nm, ".weight")]] <- ww
      attach_df[[paste0(gs_nm, ".share")]]  <- ww / sum(w$x)
    }
  }

  # -- the join ---------------------------------------------------------------
  lab_map <- attach_df
  names(lab_map)[names(lab_map) == ".gs_label"] <- key
  lab_map$.gs_label <- lab_map[[key]]

  out <- dplyr::left_join(.gs_lazy(x, backend), lab_map, by = key,
                          na_matches = "na")
  if (key != gs_nm) {
    out <- dplyr::rename(out, !!rlang::sym(gs_nm) := !!rlang::sym(".gs_label"))
  } else {
    out <- dplyr::select(out, -dplyr::all_of(".gs_label"))
  }
  .gs_restore(out, backend, collect = collect)
}
