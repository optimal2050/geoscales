# =============================================================================
# Level vocabulary
# =============================================================================
# A *level* is an abstract spatial resolution (the analogue of a timeframe in
# `timescales`). `CORE_LEVELS` is recommended vocabulary, not enforcement: any
# syntactically valid name is accepted so that existing region tables — e.g.
# IDEEA's `reg46`/`reg32`/`reg7` — load unchanged.
# =============================================================================

#' Core spatial levels
#'
#' Recommended level names, ordered coarsest first. Analogue of
#' `timescales::CORE_TIMEFRAMES`.
#'
#' These are guidance only. [`geoscale_from_leaves()`] accepts any
#' syntactically valid level name; see [`is_valid_level()`].
#'
#' @format A character vector of length 6.
#' @examples
#' CORE_LEVELS
#' @export
CORE_LEVELS <- c("GLOBE", "CONTINENT", "COUNTRY", "STATE", "ZONE", "CELL")

#' Validate level names
#'
#' A level name must be a non-empty, non-`NA` string that is a syntactically
#' valid R name (so it can be used as a data.frame column without quoting).
#'
#' @param x Character vector of candidate level names.
#'
#' @return A logical vector the same length as `x`.
#'
#' @examples
#' is_valid_level(c("COUNTRY", "reg32", "", "2bad"))
#' @export
is_valid_level <- function(x) {
  if (!is.character(x)) return(rep(FALSE, length(x)))
  ok <- !is.na(x) & nzchar(x)
  ok[ok] <- make.names(x[ok]) == x[ok]
  ok
}

#' Reserved column names in a leaves table
#'
#' Column names that carry a fixed meaning and therefore cannot be used as
#' level names.
#'
#' @noRd
.RESERVED_COLS <- c("region", "share", ".weight", ".order")
