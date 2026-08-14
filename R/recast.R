# =============================================================================
# recast_geoscale() — the central conversion verb
# =============================================================================
# The bare pipeline verb `recast()` is an S7 generic OWNED BY timescales;
# this package registers the Geoscale method on it (end of this file), so
# `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")` chains across
# both dimensions. `recast_geoscale()` is the explicit worker.
#
# Aggregation and disaggregation are ONE operation. Every conversion routes
# through the atom layer, which is already materialised in `@leaves` (so,
# unlike `timescales`, there is no `expand_calendar()` step):
#
#   1. Project source-level values DOWN to atoms.
#        rule "sum"  -> split proportionally to the weight (conserves totals)
#        otherwise   -> copy unchanged (intensive quantities)
#   2. Aggregate atoms UP to the target level.
#        "sum"           -> sum
#        "weighted_mean" -> weight-weighted mean
#        "mean"          -> unweighted mean
#        "copy"          -> the common value, error if not constant
#
# Direction falls out of this automatically: coarse -> fine is step 1 doing the
# work, fine -> coarse is step 2. Levels that cross-cut (IDEEA's reg35/reg32)
# work for free, because neither step assumes the levels nest.
# =============================================================================

#' Recast values from one spatial level to another
#'
#' The central conversion verb: takes a `data.frame` keyed by region code at
#' level `from` and returns one keyed at level `to`. Handles both
#' aggregation (fine to coarse) and disaggregation (coarse to fine) with a
#' single rule per value column.
#'
#' Columns of `x` that are neither the key nor a value column are treated as
#' identifiers and are preserved as grouping columns, so panel data (by date,
#' technology, ...) recasts correctly in one call.
#'
#' @param x A `data.frame` with a region-code column plus one or more numeric
#'   value columns.
#' @param gs A [`Geoscale`].
#' @param from Level name that the codes in `x` belong to.
#' @param to Target level name.
#' @param key Name of the region-code column in `x`. Defaults to `from` when
#'   present, otherwise `"region"`.
#' @param values Character vector of value columns to convert. Defaults to all
#'   numeric columns other than the key and any level names of `gs`. Numeric
#'   identifiers (e.g. `year`) must be excluded explicitly.
#' @param rule One of [`GEO_RULES`], or `NULL` (default) to look each value
#'   column up with [`get_geo_rule()`], falling back to `"sum"`.
#' @param weight Weight column used by `sum` (splitting) and `weighted_mean`.
#'   `NULL` uses the registered or default weight.
#' @param na_action What to do with atoms that have no code at `from` or `to`:
#'   `"drop"` (default, with a warning), `"error"`, or `"keep"` (retain an
#'   explicit `NA` group so totals conserve).
#'
#' @return A `data.frame` keyed by a column named `to`, with the identifier
#'   columns of `x` and the same value columns.
#'
#' @details
#' `na_action = "keep"` emits `NA` in the output key column. Note that
#' downstream, `energyRt` reads `NA` in a region column as a *wildcard meaning
#' all regions*, so `"keep"` output should not be passed there unfiltered.
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
#'            rule = "sum", weight = "km2")
#'
#' # Intensive quantity: weighted mean going up, copied going down
#' z <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
#'                 eff = c(0.3, 0.4, 0.5, 0.5, 0.6, 0.6))
#' recast_geoscale(z, gs, from = "atom", to = "state", rule = "weighted_mean")
#' @export
recast_geoscale <- function(x, gs, from, to,
                       key = NULL,
                       values = NULL,
                       rule = NULL,
                       weight = NULL,
                       na_action = c("drop", "error", "keep")) {
  na_action <- match.arg(na_action)
  .check_geoscale(gs, "gs")
  .check_level(gs, from, "from")
  .check_level(gs, to, "to")

  if (!is.data.frame(x)) .stop("`x` must be a data.frame")
  x <- as.data.frame(x, stringsAsFactors = FALSE)

  if (is.null(key)) key <- if (from %in% names(x)) from else "region"
  if (!key %in% names(x)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }

  levels_all <- S7::prop(gs, "levels")
  if (is.null(values)) {
    cand <- setdiff(names(x), c(key, levels_all))
    values <- cand[vapply(x[cand], is.numeric, logical(1))]
    if (length(values) == 0L) {
      .stop("no numeric value columns found in `x`; specify `values=`")
    }
  }
  missing_v <- setdiff(values, names(x))
  if (length(missing_v) > 0L) {
    .stop("value column(s) not in `x`: %s", .preview(missing_v))
  }

  id_cols <- setdiff(names(x), c(key, values))

  # Per-column rules ----------------------------------------------------------
  rules <- lapply(values, function(v) .resolve_rule(v, rule, weight))
  names(rules) <- values

  # Atom map ------------------------------------------------------------------
  leaves <- S7::prop(gs, "leaves")
  need_w <- any(vapply(rules,
                       function(r) r$rule %in% c("sum", "weighted_mean"),
                       logical(1)))
  # A weight is only *material* when refining: going coarser, each source
  # region's atoms are simply summed, and going finer with no declared weight
  # the only sensible reading is an equal split. So fall back to equal weights
  # rather than refusing to work, and warn only when the choice changes the
  # answer (i.e. when actually disaggregating).
  wcol <- NULL
  if (need_w) {
    wcol <- tryCatch(
      .resolve_weight(gs, unique(unlist(lapply(rules, `[[`, "weight")))),
      error = function(e) NULL
    )
    if (is.null(wcol) && geoscale_rank(gs, to) > geoscale_rank(gs, from)) {
      .warn(paste0("no weight column declared; splitting `%s` equally across ",
                   "the atoms of each `%s`. Declare a weight for an ",
                   "area- or population-proportional split."), to, from)
    }
  }

  atoms <- data.frame(
    .from = as.character(leaves[[from]]),
    .to   = as.character(leaves[[to]]),
    stringsAsFactors = FALSE
  )
  atoms$.w <- if (is.null(wcol)) 1 else as.numeric(leaves[[wcol]])
  atoms$.w[is.na(atoms$.w)] <- 0

  src <- unique(stats::na.omit(as.character(x[[key]])))

  if (na_action == "error") {
    n <- sum(is.na(atoms$.from) | is.na(atoms$.to))
    if (n > 0L) {
      .stop(paste0("%d atom(s) have no code at level `%s` or `%s`; ",
                   "use na_action = \"drop\" or \"keep\""), n, from, to)
    }
  }

  # Atoms with no source code can never receive a value.
  atoms <- atoms[!is.na(atoms$.from), , drop = FALSE]

  # Warn about source codes the Geoscale does not know about ------------------
  unknown <- setdiff(src, unique(atoms$.from))
  if (length(unknown) > 0L) {
    .warn(paste0("%d code(s) in `x$%s` are not present at level `%s` and ",
                 "were dropped: %s"),
          length(unknown), key, from, .preview(unknown))
  }

  # Step 1: down-projection factor, computed over the FULL `from` group so
  # that the share belonging to uncovered atoms is genuinely lost under
  # na_action = "drop" (rather than silently reallocated to their siblings).
  atoms$.split <- .split_factor(atoms$.from, atoms$.w)

  if (na_action == "drop") {
    drop_i <- is.na(atoms$.to)
    if (any(drop_i)) {
      affected <- intersect(unique(atoms$.from[drop_i]), src)
      if (length(affected) > 0L) {
        .warn(paste0("%d atom(s) have no code at level `%s`; the share of ",
                     "%d source region(s) falling in them is dropped (%s). ",
                     "Use na_action = \"keep\" to conserve totals."),
              sum(drop_i), to, length(affected), .preview(affected))
      }
      atoms <- atoms[!drop_i, , drop = FALSE]
    }
  }

  # Join source values onto atoms --------------------------------------------
  xj <- x
  xj[[".join"]] <- as.character(xj[[key]])
  joined <- merge(xj, atoms, by.x = ".join", by.y = ".from",
                  all.x = FALSE, all.y = FALSE, sort = FALSE)
  if (nrow(joined) == 0L) {
    .stop(paste0("no rows of `x` matched level `%s`; check `from=` and the ",
                 "`%s` column"), from, key)
  }

  # Steps 1+2: project down, then aggregate up, per value column --------------
  grp_cols <- c(".to", id_cols)
  out <- NULL
  for (v in values) {
    r <- rules[[v]]
    vals <- joined[[v]]
    if (r$rule == "sum") vals <- vals * joined$.split
    agg <- .aggregate_by(vals, joined[grp_cols], joined$.w, r$rule, v)
    out <- if (is.null(out)) agg else merge(out, agg, by = grp_cols,
                                            all = TRUE, sort = FALSE)
  }

  names(out)[names(out) == ".to"] <- to
  out <- out[, c(to, id_cols, values), drop = FALSE]
  rownames(out) <- NULL
  out
}

# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------

#' Resolve the rule and weight for one value column
#' @noRd
.resolve_rule <- function(v, rule, weight) {
  if (!is.null(rule)) {
    return(list(rule = match.arg(rule, GEO_RULES), weight = weight))
  }
  reg <- get_geo_rule(v)
  if (is.null(reg)) return(list(rule = "sum", weight = weight))
  list(rule = reg$rule, weight = weight %||% reg$weight)
}

#' Within-group weight shares, falling back to an equal split
#' @noRd
.split_factor <- function(grp, w) {
  tot <- stats::ave(w, grp, FUN = sum)
  n   <- stats::ave(rep(1, length(w)), grp, FUN = sum)
  out <- ifelse(tot > 0, w / tot, 1 / n)
  out[!is.finite(out)] <- 0
  out
}

#' Aggregate one value column over group columns
#' @noRd
.aggregate_by <- function(vals, groups, w, rule, vname) {
  keys <- lapply(groups, function(g) addNA(factor(g), ifany = TRUE))
  fn <- switch(
    rule,
    sum           = function(i) sum(vals[i]),
    mean          = function(i) mean(vals[i]),
    weighted_mean = function(i) {
      sw <- sum(w[i])
      if (isTRUE(sw > 0)) sum(vals[i] * w[i]) / sw else mean(vals[i])
    },
    copy          = function(i) {
      u <- unique(vals[i])
      if (length(u) > 1L && diff(range(u, na.rm = TRUE)) > 1e-9) {
        .stop(paste0("rule \"copy\" for `%s`: values are not constant within ",
                     "a target region (found %s)"), vname, .preview(u))
      }
      u[[1L]]
    },
    .stop("unknown rule: %s", rule)
  )

  idx <- split(seq_along(vals), keys, drop = TRUE, sep = "\r")
  res <- vapply(idx, fn, numeric(1))

  parts <- strsplit(names(idx), "\r", fixed = TRUE)
  out <- as.data.frame(
    do.call(rbind, lapply(parts, function(p) {
      p[p == "NA"] <- NA_character_
      p
    })),
    stringsAsFactors = FALSE
  )
  names(out) <- names(groups)
  # Restore the original type of each grouping column
  for (g in names(groups)) {
    out[[g]] <- .restore_type(out[[g]], groups[[g]])
  }
  out[[vname]] <- unname(res)
  out
}

#' Coerce a character grouping key back to the class it came from
#' @noRd
.restore_type <- function(chr, orig) {
  if (is.factor(orig)) return(factor(chr, levels = levels(orig)))
  if (inherits(orig, "Date")) return(as.Date(chr))
  if (inherits(orig, "POSIXct")) return(as.POSIXct(chr, tz = "UTC"))
  if (is.integer(orig)) return(as.integer(chr))
  if (is.numeric(orig)) return(as.numeric(chr))
  if (is.logical(orig)) return(as.logical(chr))
  chr
}

# -- the shared recast() generic ----------------------------------------------

# Geoscale method on timescales' `recast()` generic: `from` is the
# Geoscale, `to` the target level; the SOURCE level is `from_level`, or is
# inferred when exactly one of the object's levels appears as a column of
# `x`. Everything else forwards to recast_geoscale(). Registered against
# the external generic (S7's cross-package mechanism; activated by
# S7::methods_register() in .onLoad).
.recast_generic <- S7::new_external_generic("timescales", "recast",
                                            c("x", "from"))
S7::method(.recast_generic, list(S7::class_any, Geoscale)) <-
  function(x, from, to, from_level = NULL, key = NULL, values = NULL,
           rule = NULL, weight = NULL,
           na_action = c("drop", "error", "keep"), ...) {
    if (is.null(from_level)) {
      hit <- intersect(S7::prop(from, "levels"), names(x))
      if (length(hit) != 1L) {
        .stop(paste0("cannot infer the source level from `x`'s columns ",
                     "(found: %s); pass `from_level=`"),
              if (length(hit) == 0L) "none" else .preview(hit))
      }
      from_level <- hit
    }
    recast_geoscale(x, gs = from, from = from_level, to = to, key = key,
                    values = values, rule = rule, weight = weight,
                    na_action = na_action)
  }

# Re-export the generic: `library(geoscales)` alone provides the verb
# (and satisfies R CMD check that the Imports dependency is used).
#' @importFrom timescales recast
#' @export
timescales::recast
