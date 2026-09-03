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
#'     profiles; requires `from` to nest within the parent.}
#'   \item{`logshare`}{The same computation as `share` -- the values ARE
#'     shares -- but figures draw it on a fixed log10 percent scale
#'     (0.01%..100%), where `share` gets a fixed linear 0..1 scale. Use it
#'     when sibling counts differ by orders of magnitude and the linear
#'     scale flattens the crowded groups.}
#' }
#'
#' @format A character vector of length 7.
#' @examples
#' GEOSCALE_RULES
#' @export
GEOSCALE_RULES <- c("sum", "weighted_mean", "mean", "copy", "sd", "share",
                    "logshare")

#' @noRd
.RULE_REGISTRY <- new.env(parent = emptyenv())

#' Register how a parameter should be recast
#'
#' Records the rule (and optionally the weight) to use for a named value
#' column, so callers of [`recast_geoscale()`] need not repeat it. Downstream
#' packages can register their own parameter maps at load time.
#'
#' @param param Name of the value column.
#' @param rule One of [`GEOSCALE_RULES`].
#' @param weight Optional weight column name used by `sum` (down) and
#'   `weighted_mean` (up). `NULL` means the Geoscale's default weight.
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
  entry <- list(rule = rule, weight = weight)
  assign(param, entry, envir = .RULE_REGISTRY)
  invisible(entry)
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
  if (!is.character(param) || length(param) != 1L) return(NULL)
  if (!exists(param, envir = .RULE_REGISTRY, inherits = FALSE)) return(NULL)
  get(param, envir = .RULE_REGISTRY, inherits = FALSE)
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
  nms <- sort(ls(envir = .RULE_REGISTRY, all.names = FALSE))
  if (length(nms) == 0L) {
    return(data.frame(param = character(), rule = character(),
                      weight = character(), stringsAsFactors = FALSE))
  }
  entries <- lapply(nms, get_geoscale_rule)
  data.frame(
    param  = nms,
    rule   = vapply(entries, function(e) e$rule, character(1)),
    weight = vapply(entries,
                    function(e) e$weight %||% NA_character_, character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
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
  if (is.null(param)) {
    rm(list = ls(envir = .RULE_REGISTRY, all.names = TRUE),
       envir = .RULE_REGISTRY)
  } else {
    present <- intersect(param, ls(envir = .RULE_REGISTRY, all.names = TRUE))
    if (length(present) > 0L) rm(list = present, envir = .RULE_REGISTRY)
  }
  invisible(NULL)
}
