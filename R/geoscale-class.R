# =============================================================================
# Geoscale (S7 class) — slim core type
# =============================================================================
# A `Geoscale` is a nested spatial partition:
#
#   * `leaftable`   — flat enumeration of leaf regions ("atoms"), with one column
#                  per geoframe in the hierarchy plus `region` (the unique atom
#                  key) and one or more named weight columns (km2, pop, ...)
#   * `geoframes`   — ordered character vector naming the hierarchy, COARSEST
#                  first (e.g. `c("reg1", "reg7", "reg32", "reg46")`)
#   * `members`  — named list giving the full ordered code vocabulary at each
#                  geoframe (e.g. `members$reg7 = c("EAST", "WEST", ...)`)
#   * `geometry` — optional `sfc` in `leaftable` row order, or NULL
#   * `meta`     — small named list of model-geoframe attributes:
#                    * `name`, `desc`      character
#                    * `weights`           character, which columns are weights
#                    * `default_weight`    single string
#                    * `crs`, `source`, `labels`
#
# Anything that can be derived from these (parent/child tables, ancestry,
# shares, geoframe ranks, ...) is computed on demand by separate functions.
# Nothing is cached on the object.
#
# Two deliberate divergences from `timescales::Calendar`:
#
#   1. No stored `share` column. Space needs several weights (km2, pop, gdp)
#      and share is weight-specific, so it is derived by `geoscale_share()`.
#   2. `geoframes` names the hierarchy (Calendar calls that `timeframes`) and
#      `members` holds the per-geoframe vocabulary (Calendar calls that `geoframes`).
#      In the spatial domain "geoframe" is the natural word for the hierarchy.
# =============================================================================

#' Geoscale (S7 class)
#'
#' A nested spatial partition: a flat table of weighted leaf regions ("atoms")
#' plus the ordered hierarchy of geoframes that groups them.
#'
#' Construct with [`geoscale_from_leaftable()`] (the general escape hatch),
#' [`geoscale_build()`] (from a parent-child mapping), or
#' [`geoscale_from_provider()`] (from a data source such as Natural Earth).
#'
#' @param leaftable `data.frame` with a unique `region` key column, one column per
#'   geoframe in `geoframes`, and one or more numeric weight columns.
#' @param geoframes Ordered character vector of geoframe names (coarsest first); each
#'   name must appear as a column in `leaftable`.
#' @param members Named list; `members[[lvl]]` is the full ordered set of codes
#'   present at geoframe `lvl`. Must equal the non-`NA` values of `leaftable[[lvl]]`
#'   as a set.
#' @param geometry Optional `sfc` (or `NULL`) with one geometry per row of
#'   `leaftable`, in the same order.
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
    leaftable  = S7::new_property(S7::class_data.frame),
    geoframes  = S7::new_property(S7::class_character),
    members    = S7::new_property(S7::class_list),
    geometry   = S7::new_property(S7::class_any, default = NULL),
    meta       = S7::new_property(S7::class_list, default = list())
  ),
  constructor = function(leaftable, geoframes, members, geometry = NULL,
                         meta = list()) {
    S7::new_object(
      S7::S7_object(),
      leaftable  = leaftable,
      geoframes  = geoframes,
      members    = members,
      geometry   = geometry,
      meta       = meta
    )
  },
  validator = function(self) {
    errs <- character()

    leaftable <- S7::prop(self, "leaftable")
    geoframes <- S7::prop(self, "geoframes")
    members  <- S7::prop(self, "members")
    geometry <- S7::prop(self, "geometry")
    meta     <- S7::prop(self, "meta")

    # leaftable ------------------------------------------------------------------
    if (!is.data.frame(leaftable)) {
      return("`leaftable` must be a data.frame")
    }
    if (nrow(leaftable) == 0L) {
      errs <- c(errs, "`leaftable` must have at least one row")
    }
    if (!"region" %in% names(leaftable)) {
      errs <- c(errs, "`leaftable` must have a `region` column (the atom key)")
    }

    # geoframes ------------------------------------------------------------------
    if (!is.character(geoframes) || length(geoframes) == 0L) {
      errs <- c(errs, "`geoframes` must be a non-empty character vector")
    } else if (anyDuplicated(geoframes)) {
      errs <- c(errs, "`geoframes` must be unique")
    } else {
      bad <- geoframes[!is_valid_geoframe(geoframes)]
      if (length(bad) > 0L) {
        errs <- c(errs, sprintf(
          "`geoframes` contains invalid names: %s", .preview(bad)))
      }
      # `region` is allowed as the name of the FINEST geoframe: there the geoframe
      # column *is* the atom key column, so nothing collides. (Downstream
      # models often call their finest spatial unit "region" -- energyRt does.)
      # As a coarser geoframe it would clash with the key column, so it stays
      # reserved there.
      clash <- intersect(geoframes, setdiff(.RESERVED_COLS, "region"))
      if ("region" %in% geoframes &&
          !identical(geoframes[length(geoframes)], "region")) {
        clash <- c(clash, "region")
      }
      if (length(clash) > 0L) {
        errs <- c(errs, sprintf(
          "`geoframes` may not use reserved names: %s", .preview(clash)))
      }
      missing_cols <- setdiff(geoframes, names(leaftable))
      if (length(missing_cols) > 0L) {
        errs <- c(errs, sprintf(
          "`leaftable` missing geoframe columns: %s", .preview(missing_cols)))
      }
    }

    # region key --------------------------------------------------------------
    if ("region" %in% names(leaftable)) {
      rid <- leaftable$region
      if (!is.character(rid) || anyNA(rid) || any(!nzchar(rid))) {
        errs <- c(errs,
                  "`leaftable$region` must be a non-empty character vector")
      } else if (anyDuplicated(rid)) {
        dup <- unique(rid[duplicated(rid)])
        errs <- c(errs, sprintf(
          paste0("`leaftable$region` must be unique; duplicated: %s. ",
                 "Parallel dimensions (e.g. onshore/offshore) belong in ",
                 "separate Geoscale objects."),
          .preview(dup)))
      }
    }

    # members -----------------------------------------------------------------
    if (!is.list(members)) {
      errs <- c(errs, "`members` must be a list")
    } else if (length(errs) == 0L) {
      missing_mb <- setdiff(geoframes, names(members))
      if (length(missing_mb) > 0L) {
        errs <- c(errs, sprintf(
          "`members` missing entries for: %s", .preview(missing_mb)))
      }
      for (lvl in intersect(geoframes, names(members))) {
        mb <- members[[lvl]]
        if (!is.character(mb) || length(mb) == 0L || anyNA(mb) ||
            any(!nzchar(mb)) || anyDuplicated(mb)) {
          errs <- c(errs, sprintf(
            "`members[[\"%s\"]]` must be a unique non-empty character vector",
            lvl))
          next
        }
        seen <- unique(stats::na.omit(as.character(leaftable[[lvl]])))
        if (!setequal(seen, mb)) {
          errs <- c(errs, sprintf(
            paste0("`members[[\"%s\"]]` must contain exactly the non-NA ",
                   "values present in `leaftable$%s`"), lvl, lvl))
        }
      }
    }

    # NOTE: geoframes are *partitions of the atoms*, not necessarily a strict
    # tree. Real hierarchies cross-cut: IDEEA's `reg32` code "APY" merges
    # Andhra Pradesh with part of Puducherry, so the `reg35` code "PY" has two
    # parents. That is precisely why the atom layer exists and why
    # `recast_geoscale()` always routes through it. Use `geoscale_nests()` to test
    # whether a given pair of geoframes happens to nest cleanly.

    # weights -----------------------------------------------------------------
    wts <- meta$weights
    if (!is.null(wts)) {
      if (!is.character(wts) || anyNA(wts)) {
        errs <- c(errs, "`meta$weights` must be a character vector")
      } else {
        for (w in wts) {
          if (!w %in% names(leaftable)) {
            errs <- c(errs, sprintf("weight column `%s` not found in `leaftable`",
                                    w))
            next
          }
          v <- leaftable[[w]]
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
    if (!is.null(geometry) && length(geometry) != nrow(leaftable)) {
      errs <- c(errs, sprintf(
        "`geometry` has %d element(s) but `leaftable` has %d row(s)",
        length(geometry), nrow(leaftable)))
    }

    # meta --------------------------------------------------------------------
    if (!is.list(meta)) {
      errs <- c(errs, "`meta` must be a list")
    }

    # sample bookkeeping: coverage must be verifiable from the object
    # (the spatial mirror of `sum(share) == year_fraction`)
    if (is.list(meta) && !is.null(meta$coverage)) {
      cov <- meta$coverage
      wts <- meta$weights %||% character()
      if (!is.numeric(cov) || is.null(names(cov)) ||
          !all(names(cov) %in% wts)) {
        errs <- c(errs, paste0("`meta$coverage` must be a named numeric ",
                               "over declared weights"))
      } else if (!all(is.finite(cov)) || any(cov <= 0) || any(cov > 1)) {
        errs <- c(errs, "`meta$coverage` values must lie in (0, 1]")
      } else if (!is.null(meta$parent_totals)) {
        pt <- meta$parent_totals
        for (w in intersect(names(cov), names(pt))) {
          got <- sum(leaftable[[w]], na.rm = TRUE) / pt[[w]]
          if (abs(got - cov[[w]]) > 1e-8) {
            errs <- c(errs, sprintf(
              "`meta$coverage[\"%s\"]` (%.6g) does not match the leaftable (%.6g)",
              w, cov[[w]], got))
          }
        }
      }
      if (!is.null(meta$parent_name) &&
          !(is.character(meta$parent_name) &&
            length(meta$parent_name) == 1L && nzchar(meta$parent_name))) {
        errs <- c(errs, "`meta$parent_name` must be a single non-empty string")
      }
    }

    if (length(errs) == 0L) NULL else errs
  }
)

# Accessors --------------------------------------------------------------------

#' Geoframe rank
#'
#' Position of a geoframe in the hierarchy: 1 is the coarsest.
#'
#' @param x A [`Geoscale`].
#' @param geoframe Character vector of geoframe names.
#'
#' @return An integer vector of ranks; `NA` for names that are not geoframes of
#'   `x`.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_rank(gs, c("zone", "atom"))
#' @export
geoscale_rank <- function(x, geoframe) {
  .check_geoscale(x)
  match(geoframe, S7::prop(x, "geoframes"))
}

#' Geoframes of a Geoscale
#'
#' The hierarchy names, ordered coarsest first. The last entry is the atom
#' geoframe — the finest regions, which every other geoframe groups.
#'
#' @param x A [`Geoscale`].
#' @param finest Return only the finest (atom) geoframe.
#'
#' @return A character vector of geoframe names, or a single name when
#'   `finest = TRUE`.
#'
#' @examples
#' gs <- geoscale_example()
#' geoscale_geoframes(gs)
#' geoscale_geoframes(gs, finest = TRUE)
#' @export
geoscale_geoframes <- function(x, finest = FALSE) {
  .check_geoscale(x)
  lv <- S7::prop(x, "geoframes")
  if (isTRUE(finest)) lv[length(lv)] else lv
}

#' The leaftable of a Geoscale
#'
#' The one-row-per-atom table the geoscale is built on, as a plain
#' `data.frame` — the exported accessor to prefer over reaching for
#' `x@leaftable` (the twin of `timescales::calendar_leaftable()`).
#'
#' @param x A [`Geoscale`].
#' @return A `data.frame`: one row per atom, with the geoframe columns
#'   plus any weight columns.
#' @examples
#' head(geoscale_leaftable(geoscale_example()))
#' @export
geoscale_leaftable <- function(x) {
  .check_geoscale(x)
  S7::prop(x, "leaftable")
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

#' Resolve a geoframe name against a Geoscale
#'
#' @param x A [`Geoscale`].
#' @param geoframe A single geoframe name.
#' @param arg Argument name used in the error message.
#' @noRd
.check_geoframe <- function(x, geoframe, arg = "geoframe") {
  lv <- S7::prop(x, "geoframes")
  if (is.null(geoframe) || length(geoframe) != 1L || is.na(geoframe)) {
    .stop("`%s` must be a single geoframe name; one of: %s",
          arg, paste(lv, collapse = ", "))
  }
  if (!geoframe %in% lv) {
    .stop("`%s` = \"%s\" is not a geoframe of this Geoscale; one of: %s",
          arg, geoframe, paste(lv, collapse = ", "))
  }
  invisible(geoframe)
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
          paste(S7::prop(x, "geoframes"), collapse = "/"),
          nrow(S7::prop(x, "leaftable")))
}

#' Plot a Geoscale
#'
#' Dispatches to [`geoscale_autoplot()`] — the geometry-free structure
#' icicle (parity with `plot()` on a `timescales::Calendar`). For maps,
#' see [`geoscale_plot()`] and [`geom_geoscale()`].
#'
#' @param x A [`Geoscale`].
#' @param ... Passed to [`geoscale_autoplot()`].
#' @return A ggplot object.
#' @export
#' @method plot Geoscale
plot.Geoscale <- function(x, ...) {
  geoscale_autoplot(x, ...)
}

# Alias on the fully-qualified S7 class name: `class()` reports
# `geoscales::Geoscale` first (see the `[.Geoscale` note in R/filter.R),
# and that is the registration that actually dispatches when installed.
#' @rdname plot.Geoscale
#' @export
`plot.geoscales::Geoscale` <- plot.Geoscale

#' @export
#' @method print Geoscale
print.Geoscale <- function(x, ...) {
  meta <- S7::prop(x, "meta")
  lv   <- S7::prop(x, "geoframes")
  mb   <- S7::prop(x, "members")
  lf   <- S7::prop(x, "leaftable")

  name <- meta$name %||% ""
  cat("Geoscale:", if (nzchar(name)) name else "<unnamed>", "\n")
  if (!is.null(meta$desc) && nzchar(meta$desc)) {
    cat("Description:", meta$desc, "\n")
  }

  cat("Geoframes (", length(lv), ", coarsest first):\n", sep = "")
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
