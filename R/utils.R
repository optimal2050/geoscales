# =============================================================================
# Internal utilities
# =============================================================================

#' Null-coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Blank-or-NA to NA
#'
#' Real-world region tables use `""` and `NA` interchangeably for "this atom
#' has no code at this geoframe" (e.g. IDEEA's rest-of-world row). Normalise both
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

#' Name of a Geoscale (meta$name), required for conversion and attach
#'
#' Mirrors timescales' .calendar_name(): the crosswalk's label columns and
#' join_geoscale()'s attached columns are named after the object, so those
#' operations need a non-empty name.
#' @noRd
.geoscale_name <- function(gs, require = TRUE, arg = "gs") {
  nm <- S7::prop(gs, "meta")$name %||% ""
  if (require && (!is.character(nm) || length(nm) != 1L || is.na(nm) ||
                  !nzchar(nm))) {
    .stop(paste0("`%s` has no name; conversion and attach need a named ",
                 "Geoscale -- set meta$name, or pass `name=` to ",
                 "geoscale_from_leaftable()/geoscale_build()"), arg)
  }
  nm
}

#' Truncated comma-separated preview of a vector
#' @noRd
.preview <- function(x, n = 3L) {
  x <- as.character(x)
  if (length(x) <= n) return(paste(x, collapse = ", "))
  sprintf("%s, ... (%d total)", paste(utils::head(x, n), collapse = ", "),
          length(x))
}
