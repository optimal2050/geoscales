# =============================================================================
# join_geoscale() — attach hierarchy metadata to region-keyed data
# =============================================================================
# The spatial mirror of timescales::join_calendar(): given data keyed by
# region codes at one level, attach the coarser-level membership columns
# (each code's country, continent, ...) plus the level's weight and share,
# so the data can be grouped, faceted and plotted without manual joins.
#
# Levels may cross-cut: a code whose atoms sit under MORE THAN ONE parent
# at a coarser level gets NA there (with a warning) — membership is only
# well-defined where the levels nest.
# =============================================================================

#' Attach Geoscale metadata to region-keyed data
#'
#' Joins hierarchy columns onto `x`: one column per coarser level (the
#' membership of each keyed code), plus `weight` (summed atom weights)
#' and `share` (weights normalised over the level). The spatial mirror
#' of `timescales::join_calendar()`.
#'
#' @param x A `data.frame` keyed by region code.
#' @param gs A [`Geoscale`].
#' @param key Name of the code column in `x`. Defaults to `level` when
#'   that column exists, otherwise `"region"`.
#' @param level Level the codes belong to. Inferred when exactly one of
#'   the object's level names is a column of `x`.
#' @param levels Coarser levels to attach. Default: all levels coarser
#'   than `level`.
#' @param weight Weight column for `weight`/`share`; `NULL` uses the
#'   default weight (when the object has none, the columns are skipped).
#' @param as_factor Attach the level columns as factors ordered by the
#'   object's member vocabulary (default `TRUE`).
#' @return `x` with the requested columns appended.
#' @examples
#' gs <- geoscale_example()
#' x <- data.frame(state = c("N1", "N2", "S1"), v = 1:3)
#' join_geoscale(x, gs)
#' @export
join_geoscale <- function(x, gs, key = NULL, level = NULL, levels = NULL,
                          weight = NULL, as_factor = TRUE) {
  .check_geoscale(gs, "gs")
  if (!is.data.frame(x)) .stop("`x` must be a data.frame")
  x <- as.data.frame(x, stringsAsFactors = FALSE)

  lv_all <- S7::prop(gs, "levels")
  if (is.null(level)) {
    hit <- intersect(lv_all, names(x))
    if (length(hit) != 1L) {
      .stop(paste0("cannot infer the code level from `x`'s columns ",
                   "(found: %s); pass `level=`"),
            if (length(hit) == 0L) "none" else .preview(hit))
    }
    level <- hit
  }
  .check_level(gs, level, "level")
  if (is.null(key)) key <- if (level %in% names(x)) level else "region"
  if (!key %in% names(x)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }

  coarser <- lv_all[seq_len(match(level, lv_all) - 1L)]
  if (is.null(levels)) {
    levels <- coarser
  } else {
    bad <- setdiff(levels, coarser)
    if (length(bad) > 0L) {
      .stop("`levels` must be coarser than '%s'; not: %s", level,
            .preview(bad))
    }
  }

  leaves <- S7::prop(gs, "leaves")
  members <- S7::prop(gs, "members")
  codes <- as.character(x[[key]])
  known <- unique(stats::na.omit(as.character(leaves[[level]])))
  unknown <- setdiff(unique(stats::na.omit(codes)), known)
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not regions at level '%s': %s",
          length(unknown), key, level, .preview(unknown))
  }
  if (length(intersect(unique(codes), known)) == 0L) {
    .stop("no rows of `x$%s` match regions at level '%s'", key, level)
  }

  # membership columns: unique (level, coarser) pairs; codes under more
  # than one parent are ambiguous -> NA + warning
  for (cl in levels) {
    pairs <- unique(leaves[!is.na(leaves[[level]]), c(level, cl)])
    n_par <- table(pairs[[level]])
    multi <- names(n_par)[n_par > 1L]
    if (length(multi) > 0L) {
      .warn(paste0("level '%s' does not nest in '%s'; %d code(s) have ",
                   "multiple parents and get NA (e.g. %s)"),
            level, cl, length(multi), .preview(multi))
      pairs <- pairs[!pairs[[level]] %in% multi, , drop = FALSE]
    }
    val <- as.character(pairs[[cl]])[match(codes, pairs[[level]])]
    x[[cl]] <- if (isTRUE(as_factor)) {
      factor(val, levels = members[[cl]])
    } else {
      val
    }
  }

  # weight / share at the keyed level (skipped when no weight exists)
  wcol <- tryCatch(.resolve_weight(gs, weight), error = function(e) NULL)
  if (!is.null(wcol)) {
    w <- stats::aggregate(as.numeric(leaves[[wcol]]),
                          by = list(code = as.character(leaves[[level]])),
                          FUN = sum, na.rm = TRUE)
    x$weight <- w$x[match(codes, w$code)]
    x$share <- x$weight / sum(w$x)
  }
  x
}
