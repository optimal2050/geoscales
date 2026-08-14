# =============================================================================
# Geoscale (S7 class) — slim core type
# =============================================================================
# A `Geoscale` is a nested spatial partition:
#
#   * `leaves`   — flat enumeration of leaf regions ("atoms"), with one column
#                  per level in the hierarchy plus `region` (the unique atom
#                  key) and one or more named weight columns (km2, pop, ...)
#   * `levels`   — ordered character vector naming the hierarchy, COARSEST
#                  first (e.g. `c("reg1", "reg7", "reg32", "reg46")`)
#   * `members`  — named list giving the full ordered code vocabulary at each
#                  level (e.g. `members$reg7 = c("EAST", "WEST", ...)`)
#   * `geometry` — optional `sfc` in `leaves` row order, or NULL
#   * `meta`     — small named list of model-level attributes:
#                    * `name`, `desc`      character
#                    * `weights`           character, which columns are weights
#                    * `default_weight`    single string
#                    * `crs`, `source`, `labels`
#
# Anything that can be derived from these (parent/child tables, ancestry,
# shares, level ranks, ...) is computed on demand by separate functions.
# Nothing is cached on the object.
#
# Two deliberate divergences from `timescales::Calendar`:
#
#   1. No stored `share` column. Space needs several weights (km2, pop, gdp)
#      and share is weight-specific, so it is derived by `geoscale_share()`.
#   2. `levels` names the hierarchy (Calendar calls that `timeframes`) and
#      `members` holds the per-level vocabulary (Calendar calls that `levels`).
#      In the spatial domain "level" is the natural word for the hierarchy.
# =============================================================================

#' Geoscale (S7 class)
#'
#' A nested spatial partition: a flat table of weighted leaf regions ("atoms")
#' plus the ordered hierarchy of levels that groups them.
#'
#' Construct with [`geoscale_from_leaves()`] (the general escape hatch),
#' [`geoscale_build()`] (from a parent-child mapping), or
#' [`geoscale_from_provider()`] (from a data source such as Natural Earth).
#'
#' @param leaves `data.frame` with a unique `region` key column, one column per
#'   level in `levels`, and one or more numeric weight columns.
#' @param levels Ordered character vector of level names (coarsest first); each
#'   name must appear as a column in `leaves`.
#' @param members Named list; `members[[lvl]]` is the full ordered set of codes
#'   present at level `lvl`. Must equal the non-`NA` values of `leaves[[lvl]]`
#'   as a set.
#' @param geometry Optional `sfc` (or `NULL`) with one geometry per row of
#'   `leaves`, in the same order.
#' @param meta Named list of attributes (`name`, `desc`, `weights`,
#'   `default_weight`, `crs`, `source`, `labels`).
#'
#' @return A `Geoscale` object.
#'
#' @seealso [`recast_geoscale()`], [`filter_geoscale()`], [`geoscale_share()`]
#' @export
Geoscale <- S7::new_class(
  "Geoscale",
  properties = list(
    leaves   = S7::new_property(S7::class_data.frame),
    levels   = S7::new_property(S7::class_character),
    members  = S7::new_property(S7::class_list),
    geometry = S7::new_property(S7::class_any, default = NULL),
    meta     = S7::new_property(S7::class_list, default = list())
  ),
  constructor = function(leaves, levels, members, geometry = NULL,
                         meta = list()) {
    S7::new_object(
      S7::S7_object(),
      leaves   = leaves,
      levels   = levels,
      members  = members,
      geometry = geometry,
      meta     = meta
    )
  },
  validator = function(self) {
    errs <- character()

    leaves   <- S7::prop(self, "leaves")
    levels   <- S7::prop(self, "levels")
    members  <- S7::prop(self, "members")
    geometry <- S7::prop(self, "geometry")
    meta     <- S7::prop(self, "meta")

    # leaves ------------------------------------------------------------------
    if (!is.data.frame(leaves)) {
      return("`leaves` must be a data.frame")
    }
    if (nrow(leaves) == 0L) {
      errs <- c(errs, "`leaves` must have at least one row")
    }
    if (!"region" %in% names(leaves)) {
      errs <- c(errs, "`leaves` must have a `region` column (the atom key)")
    }

    # levels ------------------------------------------------------------------
    if (!is.character(levels) || length(levels) == 0L) {
      errs <- c(errs, "`levels` must be a non-empty character vector")
    } else if (anyDuplicated(levels)) {
      errs <- c(errs, "`levels` must be unique")
    } else {
      bad <- levels[!is_valid_level(levels)]
      if (length(bad) > 0L) {
        errs <- c(errs, sprintf(
          "`levels` contains invalid names: %s", .preview(bad)))
      }
      # `region` is allowed as the name of the FINEST level: there the level
      # column *is* the atom key column, so nothing collides. (Downstream
      # models often call their finest spatial unit "region" -- energyRt does.)
      # As a coarser level it would clash with the key column, so it stays
      # reserved there.
      clash <- intersect(levels, setdiff(.RESERVED_COLS, "region"))
      if ("region" %in% levels &&
          !identical(levels[length(levels)], "region")) {
        clash <- c(clash, "region")
      }
      if (length(clash) > 0L) {
        errs <- c(errs, sprintf(
          "`levels` may not use reserved names: %s", .preview(clash)))
      }
      missing_cols <- setdiff(levels, names(leaves))
      if (length(missing_cols) > 0L) {
        errs <- c(errs, sprintf(
          "`leaves` missing level columns: %s", .preview(missing_cols)))
      }
    }

    # region key --------------------------------------------------------------
    if ("region" %in% names(leaves)) {
      rid <- leaves$region
      if (!is.character(rid) || anyNA(rid) || any(!nzchar(rid))) {
        errs <- c(errs,
                  "`leaves$region` must be a non-empty character vector")
      } else if (anyDuplicated(rid)) {
        dup <- unique(rid[duplicated(rid)])
        errs <- c(errs, sprintf(
          paste0("`leaves$region` must be unique; duplicated: %s. ",
                 "Parallel dimensions (e.g. onshore/offshore) belong in ",
                 "separate Geoscale objects."),
          .preview(dup)))
      }
    }

    # members -----------------------------------------------------------------
    if (!is.list(members)) {
      errs <- c(errs, "`members` must be a list")
    } else if (length(errs) == 0L) {
      missing_mb <- setdiff(levels, names(members))
      if (length(missing_mb) > 0L) {
        errs <- c(errs, sprintf(
          "`members` missing entries for: %s", .preview(missing_mb)))
      }
      for (lvl in intersect(levels, names(members))) {
        mb <- members[[lvl]]
        if (!is.character(mb) || length(mb) == 0L || anyNA(mb) ||
            any(!nzchar(mb)) || anyDuplicated(mb)) {
          errs <- c(errs, sprintf(
            "`members[[\"%s\"]]` must be a unique non-empty character vector",
            lvl))
          next
        }
        seen <- unique(stats::na.omit(as.character(leaves[[lvl]])))
        if (!setequal(seen, mb)) {
          errs <- c(errs, sprintf(
            paste0("`members[[\"%s\"]]` must contain exactly the non-NA ",
                   "values present in `leaves$%s`"), lvl, lvl))
        }
      }
    }

    # NOTE: levels are *partitions of the atoms*, not necessarily a strict
    # tree. Real hierarchies cross-cut: IDEEA's `reg32` code "APY" merges
    # Andhra Pradesh with part of Puducherry, so the `reg35` code "PY" has two
    # parents. That is precisely why the atom layer exists and why
    # `recast_geoscale()` always routes through it. Use `geoscale_nests()` to test
    # whether a given pair of levels happens to nest cleanly.

    # weights -----------------------------------------------------------------
    wts <- meta$weights
    if (!is.null(wts)) {
      if (!is.character(wts) || anyNA(wts)) {
        errs <- c(errs, "`meta$weights` must be a character vector")
      } else {
        for (w in wts) {
          if (!w %in% names(leaves)) {
            errs <- c(errs, sprintf("weight column `%s` not found in `leaves`",
                                    w))
            next
          }
          v <- leaves[[w]]
          if (!is.numeric(v)) {
            errs <- c(errs, sprintf("weight column `%s` must be numeric", w))
          } else if (any(!is.finite(v) & !is.na(v))) {
            errs <- c(errs, sprintf("weight column `%s` must be finite", w))
          } else if (any(v < 0, na.rm = TRUE)) {
            errs <- c(errs, sprintf("weight column `%s` must be >= 0", w))
          } else if (isTRUE(sum(v, na.rm = TRUE) <= 0)) {
            errs <- c(errs, sprintf("weight column `%s` sums to zero", w))
          }
        }
        dw <- meta$default_weight
        if (!is.null(dw) && !(length(dw) == 1L && dw %in% wts)) {
          errs <- c(errs,
                    "`meta$default_weight` must be one of `meta$weights`")
        }
      }
    }

    # geometry ----------------------------------------------------------------
    if (!is.null(geometry) && length(geometry) != nrow(leaves)) {
      errs <- c(errs, sprintf(
        "`geometry` has %d element(s) but `leaves` has %d row(s)",
        length(geometry), nrow(leaves)))
    }

    # meta --------------------------------------------------------------------
    if (!is.list(meta)) {
      errs <- c(errs, "`meta` must be a list")
    }

    if (length(errs) == 0L) NULL else errs
  }
)

# Accessors --------------------------------------------------------------------

#' Level rank
#'
#' Position of a level in the hierarchy: 1 is the coarsest.
#'
#' @param x A [`Geoscale`].
#' @param level Character vector of level names.
#'
#' @return An integer vector of ranks; `NA` for names that are not levels of
#'   `x`.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_rank(gs, c("zone", "atom"))
#' @export
geoscale_rank <- function(x, level) {
  .check_geoscale(x)
  match(level, S7::prop(x, "levels"))
}

#' Levels of a Geoscale
#'
#' The hierarchy names, ordered coarsest first. The last entry is the atom
#' level — the finest regions, which every other level groups.
#'
#' @param x A [`Geoscale`].
#' @param finest Return only the finest (atom) level.
#'
#' @return A character vector of level names, or a single name when
#'   `finest = TRUE`.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_levels(gs)
#' geoscale_levels(gs, finest = TRUE)
#' @export
geoscale_levels <- function(x, finest = FALSE) {
  .check_geoscale(x)
  lv <- S7::prop(x, "levels")
  if (isTRUE(finest)) lv[length(lv)] else lv
}

#' Weight columns of a Geoscale
#'
#' @param x A [`Geoscale`].
#'
#' @return A character vector of weight column names (possibly empty).
#'
#' @examples
#' geoscale_weights(geoscale_example())
#' @export
geoscale_weights <- function(x) {
  .check_geoscale(x)
  S7::prop(x, "meta")$weights %||% character()
}

#' @noRd
.check_geoscale <- function(x, arg = "x") {
  if (!S7::S7_inherits(x, Geoscale)) {
    .stop("`%s` must be a Geoscale object", arg)
  }
  invisible(TRUE)
}

#' Resolve a level name against a Geoscale
#'
#' @param x A [`Geoscale`].
#' @param level A single level name.
#' @param arg Argument name used in the error message.
#' @noRd
.check_level <- function(x, level, arg = "level") {
  lv <- S7::prop(x, "levels")
  if (is.null(level) || length(level) != 1L || is.na(level)) {
    .stop("`%s` must be a single level name; one of: %s",
          arg, paste(lv, collapse = ", "))
  }
  if (!level %in% lv) {
    .stop("`%s` = \"%s\" is not a level of this Geoscale; one of: %s",
          arg, level, paste(lv, collapse = ", "))
  }
  invisible(level)
}

#' Resolve the weight column to use
#' @noRd
.resolve_weight <- function(x, weight = NULL) {
  wts <- geoscale_weights(x)
  if (is.null(weight)) {
    weight <- S7::prop(x, "meta")$default_weight %||%
      (if (length(wts) > 0L) wts[[1L]] else NULL)
  }
  if (is.null(weight)) {
    .stop(paste0("no weight column available; declare one via ",
                 "`meta$weights` or pass `weight=`"))
  }
  if (!weight %in% wts) {
    .stop("`weight` = \"%s\" is not a weight column; one of: %s",
          weight, if (length(wts)) paste(wts, collapse = ", ") else "<none>")
  }
  weight
}

# Format / print ---------------------------------------------------------------

S7::method(format, Geoscale) <- function(x, ...) {
  sprintf("<Geoscale[%s] atoms=%d>",
          paste(S7::prop(x, "levels"), collapse = "/"),
          nrow(S7::prop(x, "leaves")))
}

#' @export
#' @method print Geoscale
print.Geoscale <- function(x, ...) {
  meta <- S7::prop(x, "meta")
  lv   <- S7::prop(x, "levels")
  mb   <- S7::prop(x, "members")
  lf   <- S7::prop(x, "leaves")

  name <- meta$name %||% ""
  cat("Geoscale:", if (nzchar(name)) name else "<unnamed>", "\n")
  if (!is.null(meta$desc) && nzchar(meta$desc)) {
    cat("Description:", meta$desc, "\n")
  }

  cat("Levels (", length(lv), ", coarsest first):\n", sep = "")
  for (i in seq_along(lv)) {
    l <- lv[i]
    n_code <- length(mb[[l]])
    n_na <- sum(is.na(lf[[l]]))
    cat("  ", strrep("  ", i - 1L), "- ", l, " (", n_code, ")",
        if (n_na > 0L) sprintf("  [%d atom(s) unassigned]", n_na) else "",
        "\n", sep = "")
  }
  cat("Atoms: ", nrow(lf), "\n", sep = "")

  wts <- geoscale_weights(x)
  if (length(wts) > 0L) {
    dw <- meta$default_weight %||% wts[[1L]]
    cat("Weights: ", paste(wts, collapse = ", "),
        " (default: ", dw, ")\n", sep = "")
  }
  if (!is.null(meta$source)) cat("Source: ", meta$source, "\n", sep = "")
  if (!is.null(meta$crs)) cat("CRS: ", format(meta$crs), "\n", sep = "")
  if (!is.null(S7::prop(x, "geometry"))) {
    cat("Geometry: attached (", length(S7::prop(x, "geometry")),
        " features)\n", sep = "")
  }
  invisible(x)
}

S7::method(print, Geoscale) <- print.Geoscale

# Backward-compat alias: dispatch on the fully-qualified S7 class name so
# base-R `print()` finds it before falling through to `print.S7_object`.
#' @export
`print.geoscales::Geoscale` <- print.Geoscale
