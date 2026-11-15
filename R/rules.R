# =============================================================================
# Aggregation rule registry
# =============================================================================
# Mirrors the token registry in `timescales/R/tokens.R`: a package-level
# environment mapping a parameter name to the rule used when recasting it,
# plus an optional weight column. `recast_geoscale()` consults the registry
# when the caller does not pass `rule=`; an explicit argument always wins.
# A column with neither an explicit rule nor a registry entry is an ERROR --
# there is deliberately no fallback (user ruling 2026-08-13).
# =============================================================================

#' Supported aggregation rules
#'
#' Each rule defines behaviour in **both** directions. Direction is taken from
#' the geoframe ranks, so aggregation and disaggregation are one operation:
#'
#' \describe{
#'   \item{`sum`}{Up: sum. Down: split proportionally to the weight.
#'     For extensive quantities (capacity, demand, area, population).}
#'   \item{`weighted_mean`}{Up: weight-weighted mean. Down: copy unchanged.
#'     For intensive quantities (efficiency, price, capacity factor).}
#'   \item{`mean`}{Up: unweighted mean. Down: copy unchanged.}
#'   \item{`copy`}{Up: the common value, erroring if it is not constant.
#'     Down: copy unchanged. For region-invariant scalars.}
#'   \item{`sd`}{Up: standard deviation over the atoms (aggregation only;
#'     going down it degenerates to `NA` for single-atom groups).}
#'   \item{`share`}{Share within parent: each source region's value divided
#'     by the total over its parent group. Unlike every other rule the
#'     result stays keyed at the **source** geoframe -- the recast target
#'     (or `parent=`) names the parent -- so it cannot be mixed with other
#'     rules in one call (the two share rules mix freely, being one
#'     computation). For building distribution keys and normalised
#'     profiles; requires `source` to nest within the parent.}
#'   \item{`logshare`}{The same computation as `share` -- the values ARE
#'     shares -- but figures draw it on a fixed log10 percent scale
#'     (0.01%..100%), where `share` gets a fixed linear 0..1 scale. Use it
#'     when sibling counts differ by orders of magnitude and the linear
#'     scale flattens the crowded groups.}
#' }
#'
#' @format A character vector of length 7.
#' @returns A character vector of the seven rule names accepted by the `rule`
#'   argument of [recast_geoscale()] and [register_geoscale_rule()].
#' @examples
#' GEOSCALE_RULES
#' @export
GEOSCALE_RULES <- c("sum", "weighted_mean", "mean", "copy", "sd", "share",
                    "logshare")

#' What a rule does in each direction
#'
#' Every rule in [`GEOSCALE_RULES`] defines behaviour in both directions, and
#' the direction follows the geoframe ranks. This reports, per rule, what
#' going **up** and going **down** mean, and whether a parent's value is
#' therefore divisible between its children: only `sum` is, because only `sum`
#' splits a quantity. A rate, a price or a region-invariant scalar is
#' replicated instead -- the same value holds for every child -- while `sd`
#' and the two share rules have no downward meaning and are reported as `NA`
#' rather than guessed at.
#'
#' A downstream package uses this to decide, column by column, what a partial
#' selection of children does to a parent's value, without asking its caller.
#'
#' @param rule Character vector of rule names; defaults to every rule.
#'
#' @returns A `data.frame` with one row per `rule`, in the order given, and
#'   columns `rule`, `up`, `down`, `divisible` (`NA` where the rule has no
#'   downward meaning) and `action`, one of `"split"`, `"replicate"` or
#'   `"none"`.
#'
#' @examples
#' geoscale_rule_action()
#' geoscale_rule_action("sum")$divisible
#' @export
geoscale_rule_action <- function(rule = GEOSCALE_RULES) {
  if (!is.character(rule) || length(rule) == 0L || anyNA(rule)) {
    .stop("`rule` must be a character vector of rule names")
  }
  bad <- setdiff(rule, GEOSCALE_RULES)
  if (length(bad) > 0L) {
    .stop("not a recast rule: %s. The rules are: %s",
          paste(bad, collapse = ", "),
          paste(GEOSCALE_RULES, collapse = ", "))
  }
  tbl <- data.frame(
    rule = GEOSCALE_RULES,
    up = c("sum", "weighted mean", "mean", "the common value",
           "standard deviation", "share within parent",
           "share within parent"),
    down = c("split proportionally to the weight", "copy", "copy", "copy",
             NA_character_, NA_character_, NA_character_),
    divisible = c(TRUE, FALSE, FALSE, FALSE, NA, NA, NA),
    action = c("split", "replicate", "replicate", "replicate", "none",
               "none", "none"),
    stringsAsFactors = FALSE
  )
  out <- tbl[match(rule, tbl$rule), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Register how a parameter should be recast
#'
#' Records the rule (and optionally the weight) to use for a named value
#' column, so callers of [`recast_geoscale()`] need not repeat it. Downstream
#' packages can register their own parameter maps at load time.
#'
#' @param param Name of the value column.
#' @param rule One of [`GEOSCALE_RULES`].
#' @param weight Optional weight column name used by `sum` (down) and
#'   `weighted_mean` (up). `NULL` means the GeoScale's default weight.
#'
#' @return Invisibly, the registered entry.
#'
#' @examples
#' register_geoscale_rule("capacity", "sum")
#' register_geoscale_rule("eff", "weighted_mean", weight = "pop")
#' get_geoscale_rule("eff")
#' @export
register_geoscale_rule <- function(param, rule, weight = NULL) {
  if (!is.character(param) || length(param) != 1L || is.na(param) ||
      !nzchar(param)) {
    .stop("`param` must be a single non-empty string")
  }
  rule <- match.arg(rule, GEOSCALE_RULES)
  if (!is.null(weight) &&
      (!is.character(weight) || length(weight) != 1L)) {
    .stop("`weight` must be a single string or NULL")
  }
  # Stored in nestedscales' registry under this dimension's scope, which is
  # where recast_scale() looks for a GeoScale's rules.
  entry <- nestedscales::register_scale_rule(param, rule, weight,
                                            scope = "geoscale")
  invisible(entry[c("rule", "weight")])
}

#' Look up a registered rule
#'
#' @param param Name of the value column.
#'
#' @return A list with elements `rule` and `weight`, or `NULL` if `param` has
#'   not been registered.
#'
#' @examples
#' register_geoscale_rule("demand", "sum")
#' get_geoscale_rule("demand")
#' get_geoscale_rule("not_registered")
#' @export
get_geoscale_rule <- function(param) {
  e <- nestedscales::get_scale_rule(param, scope = "geoscale")
  if (is.null(e)) NULL else e[c("rule", "weight")]
}

#' List registered rules
#'
#' @return A `data.frame` with columns `param`, `rule` and `weight`.
#'
#' @examples
#' register_geoscale_rule("invcost", "weighted_mean", weight = "km2")
#' list_geoscale_rules()
#' @export
list_geoscale_rules <- function() {
  nestedscales::list_scale_rules(scope = "geoscale")[c("param", "rule",
                                                       "weight")]
}

#' Clear the rule registry
#'
#' Mainly useful in tests.
#'
#' @param param Optional character vector of names to remove. `NULL` (default)
#'   clears everything.
#'
#' @return Invisibly `NULL`.
#'
#' @examples
#' register_geoscale_rule("tmp_param", "sum")
#' clear_geoscale_rules("tmp_param")
#' @export
clear_geoscale_rules <- function(param = NULL) {
  nestedscales::clear_scale_rules(param, scope = "geoscale")
}
