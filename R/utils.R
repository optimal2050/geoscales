# =============================================================================
# Internal utilities
# =============================================================================

#' Null-coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Blank-or-NA to NA
#'
#' Real-world region tables use `""` and `NA` interchangeably for "this atom
#' has no code at this level" (e.g. IDEEA's rest-of-world row). Normalise both
#' to `NA_character_` on the way in.
#' @noRd
.blank_to_na <- function(x) {
  x <- as.character(x)
  x[!is.na(x) & trimws(x) == ""] <- NA_character_
  x
}

#' Stop with a formatted message and no call context
#' @noRd
.stop <- function(...) stop(sprintf(...), call. = FALSE)

#' Warn with a formatted message and no call context
#' @noRd
.warn <- function(...) warning(sprintf(...), call. = FALSE)

#' Truncated comma-separated preview of a vector
#' @noRd
.preview <- function(x, n = 3L) {
  x <- as.character(x)
  if (length(x) <= n) return(paste(x, collapse = ", "))
  sprintf("%s, ... (%d total)", paste(utils::head(x, n), collapse = ", "),
          length(x))
}
