# =============================================================================
# recast_geoscale() -- the central conversion verb
# =============================================================================
# The bare pipeline verb `recast()` is an S7 generic OWNED BY timescales;
# this package registers the Geoscale method on it (end of this file), so
# `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")` chains across
# both dimensions. `recast_geoscale()` is the explicit worker.
#
# Aggregation and disaggregation are ONE operation. Every conversion routes
# through the atom layer, which is already materialised in `@leaftable` (so,
# unlike `timescales`, there is no `expand_calendar()` step). The route is
# collapsed into a small crosswalk table by geoscale_map() (R/map.R), so the
# converters are single dplyr pipelines that run unchanged over data.frame /
# tibble / data.table / arrow inputs (see R/backend.R for the format
# contract). The public halves of the route are recast_to_geoatoms() /
# recast_from_geoatoms(); their composition equals recast_geoscale(), and
# recasting to ANOTHER Geoscale's atoms (matched on shared `region` keys) is
# `recast_from_geoatoms(recast_to_geoatoms(x, gs_a), gs_b, to)`.
#
# Direction falls out of the crosswalk automatically: coarse -> fine is the
# weight-share split doing the work, fine -> coarse is the aggregation.
# Geoframes that cross-cut (IDEEA's reg35/reg32) work for free, because
# neither step assumes the geoframes nest.
# =============================================================================

# Internal working columns; user columns may not collide with these
.GS_COLS <- c(".gs_parent", ".gs_tot",
              ".gs_to", ".gs_f", ".gs_n_from", ".gs_n_overlap", ".gs_w",
              ".gs_w_from")

# -----------------------------------------------------------------------------
# shared internals of the converters
# -----------------------------------------------------------------------------

#' Resolve per-column aggregation rules and weights: explicit > registry >
#' ERROR. There is deliberately NO fallback (user ruling 2026-08-13): a
#' silently guessed rule is a silent unit error waiting to happen.
#' @noRd
.geo_rules_for <- function(values, rule, weight) {
  # `rule` and `weight` are either one value for every column or a named
  # vector selecting per column -- one slot of a model can hold an extensive
  # and an intensive quantity side by side.
  pick <- function(spec, v, arg) {
    if (is.null(spec)) return(NULL)
    if (is.null(names(spec))) {
      if (length(spec) != 1L) {
        .stop("`%s` must be one value or a NAMED vector, one per column", arg)
      }
      return(spec[[1L]])
    }
    if (!v %in% names(spec)) return(NULL)
    spec[[v]]
  }
  out <- lapply(values, function(v) {
    r <- pick(rule, v, "rule")
    w <- pick(weight, v, "weight")
    if (!is.null(r)) {
      return(list(rule = match.arg(r, GEOSCALE_RULES), weight = w))
    }
    reg <- get_geoscale_rule(v)
    if (is.null(reg)) {
      .stop(paste0("no aggregation rule for value column `%s`; pass `rule=` ",
                   "or register one with register_geoscale_rule(\"%s\", ...)"),
            v, v)
    }
    list(rule = reg$rule, weight = w %||% reg$weight)
  })
  names(out) <- values
  out
}

#' Auto-detect numeric value columns of `x` (given its zero-row schema)
#' @noRd
.geo_values_for <- function(schema, key, drop_cols, values) {
  if (is.null(values)) {
    candidates <- setdiff(names(schema), c(key, drop_cols))
    values <- candidates[vapply(schema[candidates], is.numeric, logical(1))]
    if (length(values) == 0L) {
      .stop("no numeric value columns found in `x`; specify `values=`")
    }
    return(values)
  }
  if (!all(values %in% names(schema))) {
    .stop("value column(s) not in `x`: %s",
          .preview(setdiff(values, names(schema))))
  }
  values
}

#' Guard against user columns colliding with internal working columns
#' @noRd
.check_gs_cols <- function(schema) {
  clash <- intersect(names(schema), .GS_COLS)
  if (length(clash) > 0L) {
    .stop("`x` uses reserved column name(s): %s", .preview(clash))
  }
}

#' Build the per-value-column summarise expressions for one rule set.
#' Bare symbols (never `.data[[...]]`) so the expressions translate on
#' every backend -- dtplyr and arrow both mistranslate pronoun subsetting
#' in places where plain symbols work.
#' @noRd
.geo_rule_exprs <- function(values, rules) {
  out <- list()
  f  <- rlang::sym(".gs_f")
  nn <- rlang::sym(".gs_n_overlap")
  ww <- rlang::sym(".gs_w")
  for (v in values) {
    sym <- rlang::sym(v)
    out[[v]] <- switch(
      rules[[v]]$rule,
      sum = rlang::expr(sum(!!sym * !!f)),
      mean = rlang::expr(sum(!!sym * !!nn) / sum(!!nn)),
      weighted_mean = rlang::expr(
        dplyr::if_else(sum(!!ww) > 0,
                       sum(!!sym * !!ww) / sum(!!ww),
                       sum(!!sym * !!nn) / sum(!!nn))),
      copy = rlang::expr(mean(!!sym)),   # constancy pre-checked eagerly
      sd = rlang::expr(
        dplyr::if_else(
          sum(!!nn) > 1,
          sqrt((sum(!!nn * (!!sym)^2) -
                  (sum(!!nn * (!!sym)))^2 / sum(!!nn)) /
                 (sum(!!nn) - 1)),
          NA_real_)),
      .stop("Unknown rule: %s", rules[[v]]$rule)
    )
  }
  out
}

#' Eager constancy guard for `copy`-rule columns
#' @noRd
.geo_check_copy_rule <- function(joined, grp_cols, copy_cols) {
  if (length(copy_cols) == 0L) return(invisible(NULL))
  chk <- joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(copy_cols),
                    list(mx = ~ max(.x), mn = ~ min(.x))),
      .groups = "drop")
  chk <- .gs_pull(chk)
  for (v in copy_cols) {
    rng <- chk[[paste0(v, "_mx")]] - chk[[paste0(v, "_mn")]]
    if (any(!is.na(rng) & rng > 1e-9)) {
      stop(sprintf(
        paste0("rule \"copy\" for `%s`: values are not constant within ",
               "a target region"), v), call. = FALSE)
    }
  }
  invisible(NULL)
}

#' Complete a materialised result to the full target vocabulary, in the
#' contract order: identifier groups in first-appearance order, target
#' codes in member order, the NA row (if any) last.
#' @noRd
#' Aggregation expressions for one group of rows
#'
#' `weighted_mean` falls back to a plain mean when the weights sum to zero,
#' which keeps a group of zero-weight members at their common value instead
#' of `NaN`.
#'
#' With `na_rm = TRUE` an `NA` is read as "this member says nothing" rather
#' than as an unknown that poisons the group: the other members decide the
#' result, and only an all-`NA` group stays `NA`. A weighted mean also drops
#' the weight of each `NA` member, so the remaining weights still sum to the
#' divisor.
#' @noRd
.geo_group_exprs <- function(values, rules, wt_col, na_rm = FALSE) {
  exprs <- list()
  ww <- rlang::sym(wt_col)
  for (v in values) {
    sym <- rlang::sym(v)
    if (!na_rm) {
      exprs[[v]] <- switch(
        rules[[v]]$rule,
        sum = rlang::expr(sum(!!sym)),
        mean = rlang::expr(mean(!!sym)),
        weighted_mean = rlang::expr(dplyr::if_else(
          sum(!!ww) > 0,
          sum(!!sym * !!ww) / sum(!!ww),
          mean(!!sym))),
        copy = rlang::expr(mean(!!sym)),
        sd = rlang::expr(stats::sd(!!sym)),
        .stop("Unknown rule: %s", rules[[v]]$rule)
      )
      next
    }
    # n_ok counts the members that said something; 0 means the whole group
    # was silent and the result stays NA.
    n_ok <- rlang::expr(sum(as.integer(!is.na(!!sym))))
    w_ok <- rlang::expr(sum(dplyr::if_else(is.na(!!sym), 0, !!ww)))
    exprs[[v]] <- switch(
      rules[[v]]$rule,
      sum = rlang::expr(dplyr::if_else(
        !!n_ok > 0, sum(!!sym, na.rm = TRUE), NA_real_)),
      mean = rlang::expr(dplyr::if_else(
        !!n_ok > 0, mean(!!sym, na.rm = TRUE), NA_real_)),
      weighted_mean = rlang::expr(dplyr::if_else(
        !!n_ok == 0, NA_real_,
        dplyr::if_else(
          !!w_ok > 0,
          sum(dplyr::if_else(is.na(!!sym), 0, !!sym * !!ww),
              na.rm = TRUE) / !!w_ok,
          mean(!!sym, na.rm = TRUE)))),
      copy = rlang::expr(dplyr::if_else(
        !!n_ok > 0, mean(!!sym, na.rm = TRUE), NA_real_)),
      sd = rlang::expr(stats::sd(!!sym, na.rm = TRUE)),
      .stop("Unknown rule: %s", rules[[v]]$rule)
    )
  }
  exprs
}

.geo_recast_complete <- function(res, idc, out_keys, key, id_cols, values) {
  full <- data.frame(x = out_keys, stringsAsFactors = FALSE)
  names(full) <- key
  if (nrow(idc) > 0L && length(id_cols) > 0L) {
    full <- dplyr::cross_join(idc, full)
  }
  out <- dplyr::left_join(full, res, by = c(id_cols, key),
                          na_matches = "na")
  as.data.frame(out)[, c(key, id_cols, values), drop = FALSE]
}

#' Infer the source geoframe from `x`'s columns
#' @noRd
.geo_infer_from <- function(gs, schema, key) {
  gf <- S7::prop(gs, "geoframes")
  if (!is.null(key) && key %in% gf) return(key)
  hit <- intersect(gf, names(schema))
  if (length(hit) != 1L) {
    .stop(paste0("cannot infer the source geoframe from `x`'s columns ",
                 "(found: %s); pass `from=`"),
          if (length(hit) == 0L) "none" else .preview(hit))
  }
  hit
}

# -----------------------------------------------------------------------------
# recast_geoscale()
# -----------------------------------------------------------------------------

#' Recast values from one spatial resolution to another
#'
#' The central conversion verb: takes a table keyed by region code at
#' geoframe `from` and returns one keyed at `to` -- a geoframe name of the
#' same [`Geoscale`], or ANOTHER Geoscale (whose atom layer is the target,
#' matched on shared atom `region` keys). Handles both aggregation (fine to
#' coarse) and disaggregation (coarse to fine) with a single rule per value
#' column; geoframes that cross-cut work too, because the route always goes
#' through the atom layer. The route is evaluated as one dplyr pipeline
#' against the [`geoscale_map()`] crosswalk, so `x` may live in any
#' supported backend (see below). A crosswalk registered with
#' [`register_geoscale_map()`] short-circuits the derivation.
#'
#' Columns of `x` that are neither the key nor a value column are treated
#' as identifiers (panel columns -- a year, a technology) and preserved as
#' grouping columns, so panel data recasts correctly in one call; this is
#' what makes mixed pipelines like
#' `x |> recast_calendar(...) |> recast_geoscale(...)` work. Columns named
#' like `gs`'s geoframes are treated as region attributes and dropped.
#'
#' The public halves of the route are [`recast_to_geoatoms()`] and
#' [`recast_from_geoatoms()`]; `recast_geoscale(x, gs, from, to)` is
#' equivalent to
#' `recast_from_geoatoms(recast_to_geoatoms(x, gs, from), gs, to)`.
#'
#' @section Backends:
#' `x` may be a `data.frame`, tibble, `data.table`, `dtplyr` lazy table,
#' or an arrow Dataset/Table/query. The result comes back in the input's
#' class; lazy inputs (arrow, dtplyr) return the uncollected query unless
#' `collect = TRUE`. Lazy results contain the observed target regions
#' only -- the full-vocabulary completion (and its `NA` rows) applies when
#' the result is materialised.
#'
#' @param x The data to recast, in any supported backend, with a column
#'   named by `key` plus one or more numeric value columns; other columns
#'   are preserved as identifiers.
#' @param gs The [`Geoscale`] the codes in `x` belong to.
#' @param from Geoframe name the codes belong to. `NULL` (default) is
#'   inferred: `key` when it is a geoframe name, else the single geoframe
#'   name appearing among `x`'s columns.
#' @param to Target geoframe name of `gs`, or another (named) [`Geoscale`]
#'   -- then the target is that object's atom layer, matched on the atom
#'   `region` keys the two objects share.
#' @param key Name of the region-code column in `x`. Defaults to `from`
#'   when that column exists, otherwise `"region"`.
#' @param values Character vector of value columns to convert. Default: all
#'   numeric columns other than the key and `gs`'s geoframe columns.
#'   Numeric identifiers (e.g. `year`) must be excluded explicitly.
#' @param rule One of [`GEOSCALE_RULES`], applied to every value column; or
#'   `NULL` (default) to look each column up with [`get_geoscale_rule()`]. A
#'   column with neither an explicit `rule=` nor a registry entry is an
#'   ERROR -- there is deliberately no fallback (a silently guessed rule is
#'   a silent unit error).
#' @param weight Weight column used by `sum` (splitting), `weighted_mean`
#'   and the attached shares. `NULL` uses each column's registered weight,
#'   falling back to the object's default weight; when the object declares
#'   no weights at all, atoms weigh 1 (an equal split, with a warning when
#'   that choice is material, i.e. when disaggregating).
#' @param na_action What to do with atoms that have no code at `from` or
#'   `to`: `"drop"` (default, with a warning -- the affected source share
#'   is genuinely lost), `"error"`, or `"keep"` (retain an explicit `NA`
#'   region row so totals conserve).
#' @param parent `rule = "share"` only: the geoframe defining the groups
#'   the shares are taken within. `NULL` (default) uses `to` when it
#'   differs from `from`, else the geoframe immediately above `from`.
#' @param collect For lazy inputs (arrow, dtplyr): materialise the result
#'   (`TRUE`) or return the uncollected query (default).
#'
#' @return The recast table in the input's class, with columns
#'   `c(to, identifiers, values)`: per identifier combination, one row per
#'   member of `to` (the full target vocabulary, `NA` where uncovered),
#'   plus an `NA` region row under `na_action = "keep"`. Identifier column
#'   types are preserved.
#'
#' @details
#' Rules (see [`GEOSCALE_RULES`]): `"sum"` splits each source value across its
#' region's atoms proportionally to the weight before summing up, so totals
#' are conserved. `"weighted_mean"` weights by the atom weights;  `"mean"`
#' is the plain atom-count mean -- the two differ exactly when atom weights
#' differ. `"copy"` requires a constant value per target region; `"sd"` is
#' aggregation-only.
#'
#' `na_action = "keep"` emits `NA` in the output key column. Note that
#' downstream, `energyRt` reads `NA` in a region column as a *wildcard
#' meaning all regions*, so `"keep"` output should not be passed there
#' unfiltered.
#'
#' `"share"` inverts the output contract: the result stays keyed at `from`,
#' and each value becomes that region's share of the total over its parent
#' group (so the shares sum to 1 per parent, per identifier combination).
#' The parent is `parent=`, defaulting to `to` (the reading of
#' `recast_geoscale(x, gs, from = "nuts3", to = "nuts0", rule = "share")`:
#' each nuts3's share within its nuts0); `from` must nest within it. A
#' parent group whose total is zero yields `NA` shares, and an `NA` value
#' poisons its group like everywhere else in the package. `"share"` cannot
#' be combined with other rules in one call, and `weight=` is ignored --
#' the observed values themselves are the weights.
#'
#' @examples
#' gs <- geoscale_example()
#'
#' # Extensive quantity, fine -> coarse: totals are preserved
#' x <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
#'                 capacity = c(1, 2, 3, 4, 5, 6))
#' recast_geoscale(x, gs, from = "atom", to = "country", rule = "sum")
#'
#' # Coarse -> fine: split proportionally to area
#' y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
#' recast_geoscale(y, gs, from = "country", to = "state",
#'                 rule = "sum", weight = "km2")
#'
#' # Intensive quantity: weighted mean going up, copied going down
#' z <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
#'                 eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6))
#' recast_geoscale(z, gs, from = "atom", to = "state",
#'                 rule = "weighted_mean")
#'
#' # Share within parent: result stays at the atoms, sums to 1 per country
#' recast_geoscale(x, gs, from = "atom", to = "country", rule = "share")
#' @export
recast_geoscale <- function(x, gs, from = NULL, to,
                            key = NULL,
                            values = NULL,
                            rule = NULL,
                            weight = NULL,
                            na_action = c("drop", "error", "keep"),
                            parent = NULL,
                            collect = NULL) {
  na_action <- match.arg(na_action)
  .check_geoscale(gs, "gs")

  backend <- .gs_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  schema <- .gs_schema(x)
  .check_gs_cols(schema)

  if (is.null(from)) from <- .geo_infer_from(gs, schema, key)
  .check_geoframe(gs, from, "from")
  if (is.null(key)) key <- if (from %in% names(schema)) from else "region"
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }

  # -- cross-object route: `to` is another Geoscale ---------------------------
  if (S7::S7_inherits(to, Geoscale)) {
    if (any(rule %in% c("share", "logshare"))) {
      .stop(paste0("rule \"share\" needs a parent geoframe of the same ",
                   "Geoscale; it cannot recast across objects"))
    }
    g <- recast_to_geoatoms(x, gs, from = from, key = key, values = values,
                            rule = rule, weight = weight, collect = collect)
    return(recast_from_geoatoms(g, to,
                                to = geoscale_geoframes(to, finest = TRUE),
                                values = values, rule = rule,
                                na_action = na_action, collect = collect))
  }
  .check_geoframe(gs, to, "to")

  geoframes_all <- S7::prop(gs, "geoframes")
  values <- .geo_values_for(schema, key, geoframes_all, values)
  id_cols <- setdiff(names(schema), c(key, values, geoframes_all))
  rules <- .geo_rules_for(values, rule, weight)

  # Warn about source codes the Geoscale does not know (eager, small)
  leaves <- S7::prop(gs, "leaftable")
  src_keys <- .gs_pull(
    dplyr::distinct(dplyr::select(.gs_lazy(x, backend),
                                  dplyr::all_of(key))))[[key]]
  src_keys <- unique(stats::na.omit(as.character(src_keys)))
  known <- unique(stats::na.omit(as.character(leaves[[from]])))
  unknown <- setdiff(src_keys, known)
  if (length(unknown) > 0L) {
    .warn(paste0("%d code(s) in `x$%s` are not present at geoframe `%s` ",
                 "and were dropped: %s"),
          length(unknown), key, from, .preview(unknown))
  }
  if (length(intersect(src_keys, known)) == 0L) {
    .stop(paste0("no rows of `x` matched geoframe `%s`; check `from=` and ",
                 "the `%s` column"), from, key)
  }

  # -- share within parent: result keyed at `from`, one rule for all ----------
  is_share <- vapply(rules, function(r)
    r$rule %in% c("share", "logshare"), logical(1))
  if (any(is_share)) {
    if (!all(is_share)) {
      .stop(paste0("rule \"share\" changes the output key to `from` and ",
                   "cannot be mixed with other rules in one call; recast ",
                   "the columns separately"))
    }
    if (!is.null(weight)) {
      .warn("`weight` is ignored by rule \"share\": the values are the weights")
    }
    return(.geo_recast_share(x, backend, gs, from, to, key, values,
                             id_cols, parent, na_action, collect))
  }
  if (!is.null(parent)) {
    .stop("`parent` applies to rule \"share\" only")
  }

  if (na_action == "error") {
    n_bad <- sum(is.na(leaves[[from]]) | is.na(leaves[[to]]))
    if (n_bad > 0L) {
      .stop(paste0("%d atom(s) have no code at geoframe `%s` or `%s`; ",
                   "use na_action = \"drop\" or \"keep\""), n_bad, from, to)
    }
  }

  # One crosswalk per distinct weight (per-column weights may differ --
  # never the silent equal-split fallback of old versions)
  wt_of <- vapply(rules, function(r) r$weight %||% "", character(1))
  no_declared <- length(geoscale_weights(gs)) == 0L
  need_split <- vapply(rules, function(r)
    r$rule %in% c("sum", "weighted_mean"), logical(1))
  if (no_declared && is.null(weight) && any(need_split) &&
      geoscale_rank(gs, to) > geoscale_rank(gs, from)) {
    .warn(paste0("no weight column declared; splitting `%s` equally across ",
                 "the atoms of each `%s`. Declare a weight for an ",
                 "area- or population-proportional split."), to, from)
  }

  res_parts <- list()
  uncovered_any <- FALSE
  retained_from <- character(0)
  for (wt in unique(wt_of)) {
    vv <- values[wt_of == wt]
    map <- geoscale_map(from, to, gs = gs,
                        weight = if (nzchar(wt)) wt else NULL)

    uncovered <- is.na(map[[to]])
    uncovered_any <- uncovered_any || any(uncovered)
    if (any(uncovered) && na_action == "drop") {
      affected <- intersect(unique(map[[from]][uncovered]), src_keys)
      if (length(affected) > 0L) {
        .warn(paste0("%d atom(s) have no code at geoframe `%s`; the share ",
                     "of %d source region(s) falling in them is dropped ",
                     "(%s). Use na_action = \"keep\" to conserve totals."),
              sum(map$n_overlap[uncovered]), to, length(affected),
              .preview(affected))
      }
      map <- map[!uncovered, , drop = FALSE]
    }
    # na_action == "keep": the NA target stays as an explicit group
    retained_from <- union(retained_from, unique(map[[from]]))

    res_parts[[length(res_parts) + 1L]] <-
      .geo_recast_pipeline(x, backend, map, from, to, key, vv, rules[vv],
                           id_cols)
  }

  # Missing-source warning: crosswalk regions absent from an identifier group
  idc <- if (length(id_cols) > 0L) {
    .gs_pull(dplyr::distinct(dplyr::select(.gs_lazy(x, backend),
                                           dplyr::all_of(id_cols))))
  } else {
    data.frame()
  }
  if (length(id_cols) > 0L) {
    keysets <- .gs_pull(dplyr::distinct(
      dplyr::select(.gs_lazy(x, backend), dplyr::all_of(c(id_cols, key)))))
    gk <- do.call(paste, c(lapply(keysets[id_cols], as.character),
                           sep = "\r"))
    all_missing <- unique(unlist(lapply(split(keysets[[key]], gk),
                                        function(kk)
      setdiff(retained_from, as.character(kk)))))
  } else {
    all_missing <- setdiff(retained_from, src_keys)
  }
  if (length(all_missing) > 0L) {
    .warn(paste0("%d source region(s) present in the Geoscale but missing ",
                 "from `x` (e.g. %s); produced NAs"),
          length(all_missing), .preview(all_missing))
  }

  # Combine the per-weight parts (each carries its own value columns)
  res <- res_parts[[1L]]
  if (length(res_parts) > 1L) {
    for (p in res_parts[-1L]) {
      res <- dplyr::full_join(res, p, by = c(id_cols, key),
                              na_matches = "na")
    }
  }
  if (!identical(key, to)) {
    res <- dplyr::rename(res, !!rlang::sym(to) := !!rlang::sym(key))
  }

  # Lazy return: observed groups, uncollected
  if (.gs_is_lazy(backend) && !isTRUE(collect)) {
    return(dplyr::select(res, dplyr::all_of(c(to, id_cols, values))))
  }

  # Materialised return: complete to the full target vocabulary, in the
  # contract order
  res <- as.data.frame(dplyr::collect(res))
  target_keys <- S7::prop(gs, "members")[[to]]
  keep_na_row <- na_action == "keep" && uncovered_any
  out_keys <- c(target_keys, if (keep_na_row) NA_character_)
  out <- .geo_recast_complete(res, idc, out_keys, to, id_cols, values)
  .gs_restore(out, backend, collect = collect)
}

#' Resolve the parent geoframe for rule "share": explicit `parent=` wins,
#' then `to` when it differs from `from`, then the geoframe immediately
#' above `from` (geoframes are ordered coarsest first).
#' @noRd
.geo_share_parent <- function(gs, from, to, parent) {
  if (!is.null(parent)) {
    .check_geoframe(gs, parent, "parent")
    if (!identical(to, from) && !identical(to, parent)) {
      .stop(paste0("conflicting parents: `to = \"%s\"` vs `parent = \"%s\"`; ",
                   "for rule \"share\" pass the parent once"), to, parent)
    }
  } else if (!identical(to, from)) {
    parent <- to
  } else {
    gf <- S7::prop(gs, "geoframes")
    i <- match(from, gf)
    if (is.na(i) || i <= 1L) {
      .stop("`%s` has no coarser geoframe; pass `parent=`", from)
    }
    parent <- gf[[i - 1L]]
  }
  if (geoscale_rank(gs, parent) >= geoscale_rank(gs, from)) {
    .stop(paste0("rule \"share\": parent `%s` must be coarser than ",
                 "`from = \"%s\"`"), parent, from)
  }
  parent
}

#' rule = "share": each source region's value over its parent-group total.
#' Output is keyed at `from` -- the one rule that does not change the key.
#' @noRd
.geo_recast_share <- function(x, backend, gs, from, to, key, values,
                              id_cols, parent, na_action, collect) {
  parent <- .geo_share_parent(gs, from, to, parent)

  map <- geoscale_map(from, parent, gs = gs)
  mem <- unique(map[, c(from, parent)])

  # shares within a parent are only well-defined when `from` nests in it
  n_par <- table(mem[[from]][!is.na(mem[[parent]])])
  split_codes <- names(n_par)[n_par > 1L]
  if (length(split_codes) > 0L) {
    .stop(paste0("rule \"share\": %d region(s) of `%s` straddle more than ",
                 "one `%s` (%s); `from` must nest within the parent"),
          length(split_codes), from, parent, .preview(split_codes))
  }

  orphan <- is.na(mem[[parent]])
  if (any(orphan)) {
    if (na_action == "error") {
      .stop(paste0("%d region(s) of `%s` have no code at parent `%s`; ",
                   "use na_action = \"drop\" or \"keep\""),
            sum(orphan), from, parent)
    }
    if (na_action == "drop") {
      .warn(paste0("%d region(s) of `%s` have no code at parent `%s` and ",
                   "get NA shares (%s). Use na_action = \"keep\" to treat ",
                   "them as one group."),
            sum(orphan), from, parent, .preview(mem[[from]][orphan]))
      mem <- mem[!orphan, , drop = FALSE]
    }
    # "keep": the NA parent stays as an explicit group
  }

  jmem <- mem
  names(jmem) <- c(key, ".gs_parent")

  xq <- dplyr::select(.gs_lazy(x, backend),
                      dplyr::all_of(c(id_cols, key, values)))
  joined <- dplyr::inner_join(xq, jmem, by = key)

  tot_nms <- paste0(".gs_tot_", seq_along(values))
  tot_exprs <- lapply(values, function(v)
    rlang::expr(sum(!!rlang::sym(v))))
  names(tot_exprs) <- tot_nms
  tot <- joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(id_cols, ".gs_parent")))) |>
    dplyr::summarise(!!!tot_exprs, .groups = "drop")

  share_exprs <- lapply(seq_along(values), function(i) {
    v <- rlang::sym(values[[i]])
    t <- rlang::sym(tot_nms[[i]])
    rlang::expr(dplyr::if_else(!!t != 0, !!v / !!t, NA_real_))
  })
  names(share_exprs) <- values

  res <- joined |>
    dplyr::left_join(tot, by = c(id_cols, ".gs_parent"),
                     na_matches = "na") |>
    dplyr::mutate(!!!share_exprs) |>
    dplyr::select(dplyr::all_of(c(key, id_cols, values)))
  if (!identical(key, from)) {
    res <- dplyr::rename(res, !!rlang::sym(from) := !!rlang::sym(key))
  }

  if (.gs_is_lazy(backend) && !isTRUE(collect)) {
    return(dplyr::select(res, dplyr::all_of(c(from, id_cols, values))))
  }

  idc <- if (length(id_cols) > 0L) {
    .gs_pull(dplyr::distinct(dplyr::select(.gs_lazy(x, backend),
                                           dplyr::all_of(id_cols))))
  } else {
    data.frame()
  }
  res <- as.data.frame(dplyr::collect(res))
  out_keys <- S7::prop(gs, "members")[[from]]
  out <- .geo_recast_complete(res, idc, out_keys, from, id_cols, values)
  .gs_restore(out, backend, collect = collect)
}

#' rule "share" is only meaningful in recast_geoscale(), whose output key
#' it changes; the halves and pairwise converters keep the standard contract
#' @noRd
.geo_no_share <- function(rules, where) {
  if (any(vapply(rules, function(r)
    r$rule %in% c("share", "logshare"), logical(1)))) {
    .stop(paste0("rule \"share\" is not supported by %s(); use ",
                 "recast_geoscale() with a parent geoframe"), where)
  }
}

#' The crosswalk-join pipeline for one weight's value columns
#' @noRd
.geo_recast_pipeline <- function(x, backend, map, from, to, key, values,
                                 rules, id_cols) {
  jmap <- map
  names(jmap)[names(jmap) == from] <- key
  names(jmap)[names(jmap) == to]   <- ".gs_to"
  names(jmap)[names(jmap) == "n_from"]    <- ".gs_n_from"
  names(jmap)[names(jmap) == "n_overlap"] <- ".gs_n_overlap"
  names(jmap)[names(jmap) == "w"]         <- ".gs_w"
  names(jmap)[names(jmap) == "w_from"]    <- ".gs_w_from"
  jmap$.gs_f <- ifelse(jmap$.gs_w_from > 0,
                       jmap$.gs_w / jmap$.gs_w_from,
                       jmap$.gs_n_overlap / jmap$.gs_n_from)
  jmap$.gs_w_from <- NULL

  idc <- if (length(id_cols) > 0L) {
    .gs_pull(dplyr::distinct(dplyr::select(.gs_lazy(x, backend),
                                           dplyr::all_of(id_cols))))
  } else {
    data.frame()
  }
  base_grid <- if (length(id_cols) > 0L && nrow(idc) > 0L) {
    dplyr::cross_join(idc, jmap)
  } else {
    jmap
  }

  xq <- dplyr::select(.gs_lazy(x, backend),
                      dplyr::all_of(c(id_cols, key, values)))
  joined <- dplyr::right_join(xq, base_grid,
                              by = c(id_cols, key), na_matches = "na")

  grp_cols <- c(id_cols, ".gs_to")
  copy_cols <- values[vapply(rules, function(r) r$rule == "copy",
                             logical(1))]
  .geo_check_copy_rule(joined, grp_cols, copy_cols)

  joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
    dplyr::summarise(!!!.geo_rule_exprs(values, rules), .groups = "drop") |>
    dplyr::rename(!!rlang::sym(key) := !!rlang::sym(".gs_to"))
}

# -----------------------------------------------------------------------------
# recast_to_geoatoms() / recast_from_geoatoms()
# -----------------------------------------------------------------------------

#' Recast region data down to the atom layer, and back
#'
#' The two public halves of the `from -> atoms -> to` route:
#' `recast_to_geoatoms()` projects region-keyed data DOWN to the atom layer
#' (one row per atom), and `recast_from_geoatoms()` aggregates atom-keyed
#' data UP into a geoframe's regions. Their composition is
#' [`recast_geoscale()`], and because the atom rows are keyed by the atom
#' `region` IDs, `recast_from_geoatoms(recast_to_geoatoms(x, gs_a), gs_b,
#' to)` recasts across two different Geoscales that share atom keys.
#'
#' Going down, extensive columns (rule `"sum"`) are split across a region's
#' atoms proportionally to the chosen weight so totals conserve; intensive
#' columns are repeated. A `weight` column (the atom's weight) is attached
#' by default so that the return trip's `"weighted_mean"` reproduces the
#' source weighting exactly; pass `attach_weight = FALSE` to omit it.
#'
#' Going up, rules act on the atom rows directly: `"sum"` sums, `"mean"`
#' averages, `"weighted_mean"` uses the `weight` column when present (else
#' the target object's chosen weight), `"copy"` requires constancy, `"sd"`
#' is the standard deviation over the atoms.
#'
#' Both ends run as dplyr pipelines and accept any supported backend (see
#' [`recast_geoscale()`]'s Backends section); the geoscale side of every
#' join is a small in-memory frame.
#'
#' @param x The data: for `recast_to_geoatoms()` keyed by region code at
#'   geoframe `from`; for `recast_from_geoatoms()` keyed by atom `region`
#'   IDs.
#' @param gs The [`Geoscale`] the data is keyed in (`to_geoatoms`) or
#'   aggregated into (`from_geoatoms`).
#' @param from `to_geoatoms` only: geoframe name the codes belong to.
#'   `NULL` (default) is inferred as in [`recast_geoscale()`].
#' @param to `from_geoatoms` only: target geoframe name.
#' @param key The key column. `to_geoatoms`: defaults to `from` when that
#'   column exists, otherwise `"region"`. `from_geoatoms`: default
#'   `"region"`.
#' @param values,rule As in [`recast_geoscale()`].
#' @param weight `to_geoatoms`: a declared weight column of `gs`, as in
#'   [`recast_geoscale()`]. `from_geoatoms`: the name of a column of `x` to
#'   weight by, so the weight may vary by identifier -- a capacity-weighted
#'   efficiency differs by year and vintage. `NULL` (default) uses a `weight`
#'   column of `x` if present, else the Geoscale's declared weight.
#' @param attach_weight `to_geoatoms` only: attach the `weight` column
#'   (default `TRUE`).
#' @param na_rm `from_geoatoms` only: read an `NA` value as "this member says
#'   nothing" rather than as an unknown that makes the whole group `NA`
#'   (default `FALSE`). Only an all-`NA` group stays `NA`; a weighted mean
#'   drops the weight of each `NA` member so the divisor still matches.
#' @param na_action `from_geoatoms` only: what to do with atoms that have
#'   no code at `to` -- `"drop"` (default, warning), `"error"`, or
#'   `"keep"` (an `NA` region row).
#' @param collect For lazy inputs: materialise (`TRUE`) or return the
#'   query (default).
#'
#' @return `recast_to_geoatoms()`: one row per (atom x identifier
#'   combination) with columns `region`, identifiers, values (and
#'   `weight`). `recast_from_geoatoms()`: one row per (region x identifier
#'   combination) with columns `to`-named region, identifiers, values.
#'   Both in the input's class; lazy in, lazy out.
#'
#' @examples
#' gs <- geoscale_example()
#' y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
#' a <- recast_to_geoatoms(y, gs, from = "country", rule = "sum",
#'                         weight = "km2")
#' a
#' sum(a$capacity)  # 30 -- totals conserve
#'
#' recast_from_geoatoms(a, gs, to = "state", rule = "sum")
#' @export
recast_to_geoatoms <- function(x, gs, from = NULL,
                               key = NULL, values = NULL, rule = NULL,
                               weight = NULL, attach_weight = TRUE,
                               collect = NULL) {
  .check_geoscale(gs, "gs")
  backend <- .gs_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  schema <- .gs_schema(x)
  .check_gs_cols(schema)

  if (is.null(from)) from <- .geo_infer_from(gs, schema, key)
  .check_geoframe(gs, from, "from")
  if (is.null(key)) key <- if (from %in% names(schema)) from else "region"
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }
  if (isTRUE(attach_weight) && "weight" %in% names(schema)) {
    .stop("`x` already has a `weight` column; rename it first")
  }
  if (key != "region" && "region" %in% names(schema)) {
    .stop("`x` already has a `region` column; rename it first")
  }

  geoframes_all <- S7::prop(gs, "geoframes")
  values <- .geo_values_for(schema, key, geoframes_all, values)
  id_cols <- setdiff(names(schema), c(key, values, geoframes_all))
  rules <- .geo_rules_for(values, rule, weight)
  .geo_no_share(rules, "recast_to_geoatoms")

  leaves <- S7::prop(gs, "leaftable")
  wt <- unique(vapply(rules, function(r) r$weight %||% "", character(1)))
  if (length(wt) > 1L) {
    .stop(paste0("the value columns resolve to different weights (%s); ",
                 "recast them in separate calls or pass one `weight=`"),
          .preview(wt))
  }
  wcol <- .map_weight(gs, if (nzchar(wt)) wt else weight)

  # Unknown-key warning (eager, small)
  src_keys <- .gs_pull(
    dplyr::distinct(dplyr::select(.gs_lazy(x, backend),
                                  dplyr::all_of(key))))[[key]]
  src_keys <- unique(stats::na.omit(as.character(src_keys)))
  known <- unique(stats::na.omit(as.character(leaves[[from]])))
  unknown <- setdiff(src_keys, known)
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not present at geoframe `%s`: %s",
          length(unknown), key, from, .preview(unknown))
  }

  # The in-memory atom frame, with per-region weight shares
  atoms <- data.frame(
    k = as.character(leaves[[from]]),
    region = leaves$region,
    .gs_w = if (is.null(wcol)) 1 else as.numeric(leaves[[wcol]]),
    stringsAsFactors = FALSE
  )
  atoms <- atoms[!is.na(atoms$k), , drop = FALSE]
  atoms$.gs_w[is.na(atoms$.gs_w)] <- 0
  tot <- stats::ave(atoms$.gs_w, atoms$k, FUN = sum)
  cnt <- stats::ave(rep(1, nrow(atoms)), atoms$k, FUN = sum)
  atoms$.gs_f <- ifelse(tot > 0, atoms$.gs_w / tot, 1 / cnt)
  if (isTRUE(attach_weight)) atoms$weight <- atoms$.gs_w
  atoms$.gs_w <- NULL
  names(atoms)[names(atoms) == "k"] <- key

  xq <- .gs_lazy(x, backend)
  out <- dplyr::inner_join(xq, atoms, by = key, na_matches = "na")

  # Extensive columns split across the region's atoms
  sum_cols <- values[vapply(rules, function(r) r$rule == "sum", logical(1))]
  if (length(sum_cols) > 0L) {
    out <- dplyr::mutate(out, dplyr::across(
      dplyr::all_of(sum_cols), ~ .x * .gs_f))
  }

  keep <- c("region", id_cols, values, if (isTRUE(attach_weight)) "weight")
  out <- dplyr::select(out, dplyr::all_of(keep))
  .gs_restore(out, backend, collect = collect)
}

#' @rdname recast_to_geoatoms
#' @export
recast_from_geoatoms <- function(x, gs, to,
                                 key = NULL, values = NULL, rule = NULL,
                                 weight = NULL, na_rm = FALSE,
                                 na_action = c("drop", "error", "keep"),
                                 collect = NULL) {
  na_action <- match.arg(na_action)
  .check_geoscale(gs, "gs")
  backend <- .gs_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  .check_geoframe(gs, to, "to")
  schema <- .gs_schema(x)
  .check_gs_cols(schema)
  if (is.null(key)) key <- "region"
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }

  geoframes_all <- S7::prop(gs, "geoframes")

  # `weight` names a column of `x`, so the weight may vary by any id column --
  # a capacity-weighted efficiency differs by year and vintage. Without it the
  # conventional `weight` column is used, else the Geoscale's declared weight.
  wt_col <- "weight"
  if (!is.null(weight)) {
    if (!is.character(weight) || length(weight) != 1L) {
      .stop("`weight` must be a single column name of `x`")
    }
    if (!weight %in% names(schema)) {
      .stop("`x` has no column named `%s` to weight by", weight)
    }
    wt_col <- weight
  }
  values <- .geo_values_for(schema, key, c(geoframes_all, wt_col), values)
  id_cols <- setdiff(names(schema),
                     c(key, values, wt_col, geoframes_all))
  rules <- .geo_rules_for(values, rule, NULL)
  .geo_no_share(rules, "recast_from_geoatoms")
  has_weight <- wt_col %in% names(schema)

  leaves <- S7::prop(gs, "leaftable")
  atoms <- data.frame(
    k = leaves$region,
    .gs_to = as.character(leaves[[to]]),
    stringsAsFactors = FALSE
  )
  if (!has_weight) {
    wcol <- .map_weight(gs, NULL)
    atoms[[wt_col]] <- if (is.null(wcol)) 1 else as.numeric(leaves[[wcol]])
    atoms[[wt_col]][is.na(atoms[[wt_col]])] <- 0
  }
  names(atoms)[names(atoms) == "k"] <- key

  # Unknown-key warning (eager, small)
  src_keys <- .gs_pull(
    dplyr::distinct(dplyr::select(.gs_lazy(x, backend),
                                  dplyr::all_of(key))))[[key]]
  src_keys <- unique(stats::na.omit(as.character(src_keys)))
  unknown <- setdiff(src_keys, leaves$region)
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not atoms of the Geoscale: %s",
          length(unknown), key, .preview(unknown))
  }
  if (length(intersect(src_keys, leaves$region)) == 0L) {
    .stop("no rows of `x` matched the Geoscale's atoms; check `key=`")
  }

  xq <- .gs_lazy(x, backend)
  joined <- dplyr::left_join(xq, atoms, by = key, na_matches = "na")

  # Coverage accounting (eager, aggregate only)
  cover <- .gs_pull(
    joined |>
      dplyr::summarise(n = dplyr::n(),
                       n_na = sum(as.integer(is.na(.gs_to)))))
  if (cover$n_na[1] > 0L) {
    if (na_action == "error") {
      .stop(paste0("%d row(s) of `x` fall on atoms with no code at ",
                   "geoframe `%s`; use na_action = \"drop\" or \"keep\""),
            cover$n_na[1], to)
    }
    if (na_action == "drop") {
      .warn(paste0("%d row(s) of `x` fall on atoms with no code at ",
                   "geoframe `%s` and were dropped; use na_action = ",
                   "\"keep\" to conserve totals"), cover$n_na[1], to)
      joined <- dplyr::filter(joined, !is.na(.gs_to))
    }
  }

  grp_cols <- c(id_cols, ".gs_to")

  # Rule expressions on atom rows: n_overlap == 1 per row; weighted_mean
  # uses the carried (or attached) `weight`
  exprs <- .geo_group_exprs(values, rules, wt_col, na_rm)
  copy_cols <- values[vapply(rules, function(r) r$rule == "copy",
                             logical(1))]
  .geo_check_copy_rule(joined, grp_cols, copy_cols)

  res <- joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
    dplyr::summarise(!!!exprs, .groups = "drop") |>
    dplyr::rename(!!rlang::sym(to) := !!rlang::sym(".gs_to"))

  if (.gs_is_lazy(backend) && !isTRUE(collect)) {
    return(dplyr::select(res, dplyr::all_of(c(to, id_cols, values))))
  }

  res <- as.data.frame(dplyr::collect(res))
  res <- res[, c(to, id_cols, values), drop = FALSE]
  res <- res[order(match(res[[to]], S7::prop(gs, "members")[[to]]),
                   na.last = TRUE), , drop = FALSE]
  rownames(res) <- NULL
  .gs_restore(res, backend, collect = collect)
}

# -- the shared recast() generic ----------------------------------------------

# Geoscale method on timescales' `recast()` generic: `from` is the
# Geoscale, `to` the target geoframe (or another Geoscale); the SOURCE
# geoframe is `from_geoframe`, or is inferred when exactly one of the
# object's geoframes appears as a column of `x`. Everything else forwards
# to recast_geoscale(). Registered against the external generic (S7's
# cross-package mechanism; activated by S7::methods_register() in .onLoad).
.recast_generic <- S7::new_external_generic("timescales", "recast",
                                            c("x", "from"))
S7::method(.recast_generic, list(S7::class_any, Geoscale)) <-
  function(x, from, to, from_geoframe = NULL, key = NULL, values = NULL,
           rule = NULL, weight = NULL,
           na_action = c("drop", "error", "keep"), collect = NULL, ...) {
    recast_geoscale(x, gs = from, from = from_geoframe, to = to, key = key,
                    values = values, rule = rule, weight = weight,
                    na_action = na_action, collect = collect)
  }

# Re-export the generic: `library(geoscales)` alone provides the verb
# (and satisfies R CMD check that the Imports dependency is used).
#' @importFrom timescales recast
#' @export
timescales::recast
