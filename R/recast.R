# =============================================================================
# recast_geoscale() -- the central conversion verb
# =============================================================================
# The bare pipeline verb `recast()` is an S7 generic owned by nestedscales;
# this package registers the GeoScale method on it (end of this file), so
# `x |> recast(cal_a, cal_b) |> recast(gs, target = "country")` chains across
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
# recasting to ANOTHER GeoScale's atoms (matched on shared `region` keys) is
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
#' geoframe `source` and returns one keyed at `target` -- a geoframe name of the
#' same [`GeoScale`], or ANOTHER GeoScale (whose atom layer is the target,
#' matched on shared atom `region` keys). Handles both aggregation (fine to
#' coarse) and disaggregation (coarse to fine) with a single rule per value
#' column; geoframes that cross-cut work too, because the route always goes
#' through the atom layer. The route is evaluated as one dplyr pipeline
#' against the [`geoscale_map()`] crosswalk, so `data` may live in any
#' supported backend (see below). A crosswalk registered with
#' [`register_geoscale_map()`] short-circuits the derivation.
#'
#' Columns of `data` that are neither the key nor a value column are treated
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
#' `data` may be a `data.frame`, tibble, `data.table`, `dtplyr` lazy table,
#' or an arrow Dataset/Table/query. The result comes back in the input's
#' class; lazy inputs (arrow, dtplyr) return the uncollected query unless
#' `collect = TRUE`. Lazy results contain the observed target regions
#' only -- the full-vocabulary completion (and its `NA` rows) applies when
#' the result is materialised.
#'
#' @param data The data to recast, in any supported backend, with a column
#'   named by `key` plus one or more numeric value columns; other columns
#'   are preserved as identifiers.
#' @param gs The [`GeoScale`] the codes in `data` belong to.
#' @param from,to Deprecated names of `source` and `target`.
#' @param source Geoframe name the codes belong to. `NULL` (default) is
#'   inferred: `key` when it is a geoframe name, else the single geoframe
#'   name appearing among `data`'s columns.
#' @param target Target geoframe name of `gs`, or another (named) [`GeoScale`]
#'   -- then the target is that object's atom layer, matched on the atom
#'   codes the two objects share.
#' @param key Name of the region-code column in `data`. Defaults to `source`
#'   when that column exists, otherwise the GeoScale's atom key.
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
#' @param na_action What to do with atoms that have no code at `source` or
#'   `target`: `"drop"` (default, with a warning -- the affected source share
#'   is genuinely lost), `"error"`, or `"keep"` (retain an explicit `NA`
#'   region row so totals conserve).
#' @param parent `rule = "share"` only: the geoframe defining the groups
#'   the shares are taken within. `NULL` (default) uses `target` when it
#'   differs from `source`, else the geoframe immediately above `source`.
#' @param collect For lazy inputs (arrow, dtplyr): materialise the result
#'   (`TRUE`) or return the uncollected query (default).
#'
#' @return The recast table in the input's class, with columns
#'   `c(target, identifiers, values)`: per identifier combination, one row per
#'   member of `target` (the full target vocabulary, `NA` where uncovered),
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
#' `"share"` inverts the output contract: the result stays keyed at `source`,
#' and each value becomes that region's share of the total over its parent
#' group (so the shares sum to 1 per parent, per identifier combination).
#' The parent is `parent=`, defaulting to `target` (the reading of
#' `recast_geoscale(x, gs, source = "nuts3", target = "nuts0", rule = "share")`:
#' each nuts3's share within its nuts0); `source` must nest within it. A
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
#' recast_geoscale(x, gs, source = "atom", target = "country", rule = "sum")
#'
#' # Coarse -> fine: split proportionally to area
#' y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
#' recast_geoscale(y, gs, source = "country", target = "state",
#'                 rule = "sum", weight = "km2")
#'
#' # Intensive quantity: weighted mean going up, copied going down
#' z <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
#'                 eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6))
#' recast_geoscale(z, gs, source = "atom", target = "state",
#'                 rule = "weighted_mean")
#'
#' # Share within parent: result stays at the atoms, sums to 1 per country
#' recast_geoscale(x, gs, source = "atom", target = "country", rule = "share")
#' @export
recast_geoscale <- function(data, gs, source = NULL, target,
                            key = NULL,
                            values = NULL,
                            rule = NULL,
                            weight = NULL,
                            na_action = c("drop", "error", "keep"),
                            parent = NULL,
                            collect = NULL,
                            from = lifecycle::deprecated(),
                            to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("recast_geoscale", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("recast_geoscale", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  na_action <- match.arg(na_action)
  .check_geoscale(gs, "gs")
  link <- .geo_link_enter(data, gs, key = key, source = from)
  data <- link$data
  key <- link$key
  from <- link$source
  # Across two GeoScales the route runs through this package's own halves,
  # whose result holds the observed target regions only.
  if (S7::S7_inherits(to, GeoScale)) {
    if (any(rule %in% c("share", "logshare"))) {
      .stop(paste0("rule \"share\" needs a parent geoframe of the same ",
                   "GeoScale; it cannot recast across objects"))
    }
    g <- recast_to_geoatoms(data, gs, source = from, key = key, values = values,
                            rule = rule, weight = weight, collect = collect)
    finest <- geoscale_geoframes(to, finest = TRUE)
    out <- recast_from_geoatoms(g, to,
                                target = finest,
                                key = S7::prop(gs, "key"),
                                values = values, rule = rule,
                                na_action = na_action, collect = collect)
    return(.geo_link_exit(out, link, .geo_bound(to, finest)))
  }
  out <- nestedscales::recast_scale(data, gs, source = from, target = to,
                                    key = key, values = values, rule = rule,
                                    weight = weight, na_action = na_action,
                                    parent = parent, collect = collect)
  .geo_link_exit(out, link, .geo_bound(gs, to))
}

#' rule "share" is only meaningful in recast_geoscale(), whose output key
#' it changes; the halves and pairwise converters keep the standard contract
#' @noRd
.geo_no_share <- function(rules, where) {
  is_share <- vapply(rules, function(r) {
    r$rule %in% c("share", "logshare")
  }, logical(1))
  if (any(is_share)) {
    .stop(paste0("rule \"share\" is not supported by %s(); use ",
                 "recast_geoscale() with a parent geoframe"), where)
  }
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
#' to)` recasts across two different GeoScales that share atom keys.
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
#' @param data The data: for `recast_to_geoatoms()` keyed by region code at
#'   geoframe `source`; for `recast_from_geoatoms()` keyed by atom codes.
#' @param gs The [`GeoScale`] the data is keyed in (`to_geoatoms`) or
#'   aggregated into (`from_geoatoms`).
#' @param from,to Deprecated names of `source` and `target`.
#' @param source `to_geoatoms` only: geoframe name the codes belong to.
#'   `NULL` (default) is inferred as in [`recast_geoscale()`].
#' @param target `from_geoatoms` only: target geoframe name.
#' @param key The key column. `to_geoatoms`: defaults to `source` when that
#'   column exists, otherwise the GeoScale's atom key. `from_geoatoms`: the
#'   GeoScale's atom key.
#' @param values,rule As in [`recast_geoscale()`].
#' @param weight A declared weight column of `gs`, as in
#'   [`recast_geoscale()`]. `from_geoatoms` uses it only when `data` carries
#'   no weight of its own.
#' @param data_weight `from_geoatoms` only: the name of a column of `data` to
#'   weight by, so the weight may vary by identifier -- a capacity-weighted
#'   efficiency differs by year and vintage. `NULL` (default) uses a `weight`
#'   column of `data` if present, else the scale weight `weight`.
#' @param attach_weight `to_geoatoms` only: attach the `weight` column
#'   (default `TRUE`).
#' @param na_rm `from_geoatoms` only: read an `NA` value as "this member says
#'   nothing" rather than as an unknown that makes the whole group `NA`
#'   (default `FALSE`). Only an all-`NA` group stays `NA`; a weighted mean
#'   drops the weight of each `NA` member so the divisor still matches.
#' @param na_action `from_geoatoms` only: what to do with atoms that have
#'   no code at `target` -- `"drop"` (default, warning), `"error"`, or
#'   `"keep"` (an `NA` region row).
#' @param collect For lazy inputs: materialise (`TRUE`) or return the
#'   query (default).
#'
#' @return `recast_to_geoatoms()`: one row per (atom x identifier
#'   combination) with the atom column (named after the GeoScale's atom
#'   key, see [`geoscale_key()`]), identifiers, values (and `weight`). `recast_from_geoatoms()`: one row per (region x identifier
#'   combination) with columns `target`-named region, identifiers, values.
#'   Both in the input's class; lazy in, lazy out.
#'
#' @examples
#' gs <- geoscale_example()
#' y <- data.frame(country = c("N", "S"), capacity = c(10, 20))
#' a <- recast_to_geoatoms(y, gs, source = "country", rule = "sum",
#'                         weight = "km2")
#' a
#' sum(a$capacity)  # 30 -- totals conserve
#'
#' recast_from_geoatoms(a, gs, target = "state", rule = "sum")
#' @export
recast_to_geoatoms <- function(data, gs, source = NULL,
                               key = NULL, values = NULL, rule = NULL,
                               weight = NULL, attach_weight = TRUE,
                               collect = NULL,
                               from = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("recast_to_geoatoms", "from", "source", !missing(source))
    source <- from
  }
  from <- source
  .check_geoscale(gs, "gs")
  link <- .geo_link_enter(data, gs, key = key, source = from)
  data <- link$data
  key <- link$key
  from <- link$source
  backend <- .gs_backend(data)
  if (is.na(backend)) {
    .stop(paste0("`data` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  schema <- .gs_schema(data)
  .check_gs_cols(schema)

  if (is.null(from)) from <- .geo_infer_from(gs, schema, key)
  .check_geoframe(gs, from, "source")
  akey <- S7::prop(gs, "key")
  if (is.null(key)) key <- if (from %in% names(schema)) from else akey
  if (!key %in% names(schema)) {
    .stop("`data` has no column named `%s`; pass `key=`", key)
  }
  if (isTRUE(attach_weight) && "weight" %in% names(schema)) {
    .stop("`data` already has a `weight` column; rename it first")
  }
  if (key != akey && akey %in% names(schema)) {
    .stop("`data` already has a `%s` column; rename it first", akey)
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
    dplyr::distinct(dplyr::select(.gs_lazy(data, backend),
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
    .gs_atom = leaves[[akey]],
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

  xq <- .gs_lazy(data, backend)
  out <- dplyr::inner_join(
    xq, atoms,
    by = key,
    na_matches = "na",
    relationship = "many-to-many"
  )

  # Extensive columns split across the region's atoms
  sum_cols <- values[vapply(rules, function(r) r$rule == "sum", logical(1))]
  if (length(sum_cols) > 0L) {
    out <- dplyr::mutate(out, dplyr::across(
      dplyr::all_of(sum_cols), ~ .x * .gs_f))
  }

  # The atom column takes the key's name; when the source IS the atom level
  # that is the name of the column it replaces.
  keep <- c(".gs_atom", id_cols, values, if (isTRUE(attach_weight)) "weight")
  out <- dplyr::select(out, dplyr::all_of(keep))
  out <- dplyr::rename(out, !!rlang::sym(akey) := !!rlang::sym(".gs_atom"))
  .geo_link_exit(.gs_restore(out, backend, collect = collect), link,
                 .geo_bound(gs, akey))
}

#' @rdname recast_to_geoatoms
#' @export
recast_from_geoatoms <- function(data, gs, target,
                                 key = NULL, values = NULL, rule = NULL,
                                 weight = NULL, data_weight = NULL,
                                 na_rm = FALSE,
                                 na_action = c("drop", "error", "keep"),
                                 collect = NULL,
                                 to = lifecycle::deprecated()) {
  if (lifecycle::is_present(to)) {
    .arg_renamed("recast_from_geoatoms", "to", "target", !missing(target))
    target <- to
  }
  to <- target
  na_action <- match.arg(na_action)
  .check_geoscale(gs, "gs")
  link <- .geo_link_enter(data, gs, key = key, infer = FALSE)
  data <- link$data
  backend <- .gs_backend(data)
  if (is.na(backend)) {
    .stop(paste0("`data` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  .check_geoframe(gs, to, "target")
  schema <- .gs_schema(data)
  .check_gs_cols(schema)
  akey <- S7::prop(gs, "key")
  if (is.null(key)) key <- akey
  if (!key %in% names(schema)) {
    .stop("`data` has no column named `%s`; pass `key=`", key)
  }

  # The key column holds atoms here, whatever geoframe shares its name.
  geoframes_all <- setdiff(S7::prop(gs, "geoframes"), key)

  # `data_weight` names a column of `data`, so the weight may vary by any id
  # column -- a capacity-weighted efficiency differs by year and vintage.
  # Without it the conventional `weight` column is used, else the scale
  # weight `weight` (the GeoScale's declared weight when `NULL`).
  wt_col <- "weight"
  if (!is.null(data_weight)) {
    if (!is.character(data_weight) || length(data_weight) != 1L) {
      .stop("`data_weight` must be a single column name of `data`")
    }
    if (!data_weight %in% names(schema)) {
      .stop("`data` has no column named `%s` to weight by", data_weight)
    }
    wt_col <- data_weight
  }
  values <- .geo_values_for(schema, key, c(geoframes_all, wt_col), values)
  id_cols <- setdiff(names(schema),
                     c(key, values, wt_col, geoframes_all))
  rules <- .geo_rules_for(values, rule, NULL)
  .geo_no_share(rules, "recast_from_geoatoms")
  has_weight <- wt_col %in% names(schema)

  leaves <- S7::prop(gs, "leaftable")
  atoms <- data.frame(
    k = leaves[[akey]],
    .gs_to = as.character(leaves[[to]]),
    stringsAsFactors = FALSE
  )
  if (!has_weight) {
    wcol <- .map_weight(gs, weight)
    atoms[[wt_col]] <- if (is.null(wcol)) 1 else as.numeric(leaves[[wcol]])
    atoms[[wt_col]][is.na(atoms[[wt_col]])] <- 0
  }
  names(atoms)[names(atoms) == "k"] <- key

  # Unknown-key warning (eager, small)
  src_keys <- .gs_pull(
    dplyr::distinct(dplyr::select(.gs_lazy(data, backend),
                                  dplyr::all_of(key))))[[key]]
  src_keys <- unique(stats::na.omit(as.character(src_keys)))
  unknown <- setdiff(src_keys, leaves[[akey]])
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not atoms of the GeoScale: %s",
          length(unknown), key, .preview(unknown))
  }
  if (length(intersect(src_keys, leaves[[akey]])) == 0L) {
    .stop("no rows of `data` matched the GeoScale's atoms; check `key=`")
  }

  xq <- .gs_lazy(data, backend)
  joined <- dplyr::left_join(xq, atoms, by = key, na_matches = "na")

  # Coverage accounting (eager, aggregate only)
  cover <- .gs_pull(
    joined |>
      dplyr::summarise(n = dplyr::n(),
                       n_na = sum(as.integer(is.na(.gs_to)))))
  if (cover$n_na[1] > 0L) {
    if (na_action == "error") {
      .stop(paste0("%d row(s) of `data` fall on atoms with no code at ",
                   "geoframe `%s`; use na_action = \"drop\" or \"keep\""),
            cover$n_na[1], to)
    }
    if (na_action == "drop") {
      .warn(paste0("%d row(s) of `data` fall on atoms with no code at ",
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
  .geo_link_exit(.gs_restore(res, backend, collect = collect), link,
                 .geo_bound(gs, to))
}

# -- the shared recast() generic ----------------------------------------------

# GeoScale method on nestedscales' `recast()` generic: `scale` is the
# GeoScale, `target` the target geoframe (or another GeoScale); the SOURCE
# geoframe is `source`, or is inferred when exactly one of the
# object's geoframes appears as a column of `x`. Everything else forwards
# to recast_geoscale(). Registered against the external generic (S7's
# cross-package mechanism; activated by S7::methods_register() in .onLoad).
.recast_generic <- S7::new_external_generic("nestedscales", "recast",
                                            c("x", "scale"))
S7::method(.recast_generic, list(S7::class_any, GeoScale)) <-
  function(x, scale, target, source = NULL, key = NULL, values = NULL,
           rule = NULL, weight = NULL,
           na_action = c("drop", "error", "keep"), collect = NULL, ...) {
    recast_geoscale(x, gs = scale, source = source, target = target, key = key,
                    values = values, rule = rule, weight = weight,
                    na_action = na_action, collect = collect)
  }

# Re-export the generic: `library(geoscales)` alone provides the verb
# (and satisfies R CMD check that the Imports dependency is used). The generic
# is owned by `nestedscales`, the dimension-agnostic core.
#' @importFrom nestedscales recast
#' @export
nestedscales::recast
