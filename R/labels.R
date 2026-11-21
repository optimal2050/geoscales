# =============================================================================
# Labels -- display names for regions and geoframes, in named variants
# =============================================================================
# A long table keyed by (frame, member, variant): one row per display name.
# It is sparse -- a geoframe, or a region, without a row is shown by its code
# -- and a row with `member = NA` names the geoframe itself.
#
# The object stores the table under the column names of `nestedscales`
# (`frame`, `member`), whose validator reads it too. The functions here take
# and return it under the spatial names (`geoframe`, `region`).
# =============================================================================

.LABEL_COLS <- c("frame", "member", "variant", "label")
.LABEL_PUBLIC <- c(frame = "geoframe", member = "region")
.DEFAULT_VARIANT <- "label"

#' @noRd
.empty_labels <- function() {
  data.frame(frame = character(), member = character(),
             variant = character(), label = character(),
             stringsAsFactors = FALSE)
}

#' A member table with its code column under the current name
#'
#' Up to `nestedscales` 0.2.0 the code column of the label, alias and
#' attribute tables was `unit`. A table that has `unit` and no `member` gets
#' the column renamed; anything else is returned unchanged.
#' @noRd
.legacy_member_col <- function(tab) {
  if (is.data.frame(tab) && "unit" %in% names(tab) &&
      !"member" %in% names(tab)) {
    names(tab)[names(tab) == "unit"] <- "member"
  }
  tab
}

#' The stored label table, under the current column names
#'
#' Read with `attr()`, not `S7::prop()`: an object saved under an earlier
#' class definition may lack the property, or hold the table with `unit`.
#' @noRd
.label_table <- function(x) {
  .legacy_member_col(attr(x, "labels", exact = TRUE) %||% .empty_labels())
}

#' The label table under the spatial column names
#' @noRd
.public_labels <- function(lb) {
  hit <- match(names(.LABEL_PUBLIC), names(lb))
  names(lb)[hit[!is.na(hit)]] <- .LABEL_PUBLIC[!is.na(hit)]
  lb
}

#' @noRd
.as_labels <- function(labels, variant = NULL) {
  if (is.null(labels)) return(.empty_labels())
  if (!is.data.frame(labels)) {
    .stop(paste0("`labels` must be a data.frame with columns `geoframe`, ",
                 "`region` and `label`"))
  }
  labels <- as.data.frame(labels, stringsAsFactors = FALSE)
  # stored under the names of `nestedscales`, which are accepted as well
  names(labels)[names(labels) == "geoframe"] <- "frame"
  names(labels)[names(labels) == "region"] <- "member"
  if ("variant" %in% names(labels)) {
    if (!is.null(variant)) {
      .stop("`labels` already has a `variant` column; drop `variant=`")
    }
  } else {
    variant <- variant %||% .DEFAULT_VARIANT
    if (!is.character(variant) || length(variant) != 1L || is.na(variant) ||
        !nzchar(variant)) {
      .stop("`variant` must be a single string")
    }
    labels$variant <- rep(variant, nrow(labels))
  }
  missing_cols <- setdiff(.LABEL_COLS, names(labels))
  if (length(missing_cols) > 0L) {
    .stop("`labels` is missing column(s): %s",
          .preview(names(.public_labels(
            stats::setNames(missing_cols, missing_cols)))))
  }
  extra <- setdiff(names(labels), .LABEL_COLS)
  if (length(extra) > 0L) {
    .stop("`labels` has unknown column(s): %s", .preview(extra))
  }
  out <- labels[.LABEL_COLS]
  for (ch in .LABEL_COLS) out[[ch]] <- as.character(out[[ch]])
  rownames(out) <- NULL
  out
}

#' @noRd
.label_keys <- function(lb) {
  paste(lb$frame, ifelse(is.na(lb$member), "", lb$member), lb$variant,
        is.na(lb$member), sep = "\r")
}

#' @noRd
.check_labels_table <- function(lb, geoframes, members) {
  errs <- character()
  lb <- .legacy_member_col(lb)
  if (!identical(names(lb), .LABEL_COLS)) {
    return(sprintf("`labels` must have exactly the columns: %s",
                   paste(.LABEL_COLS, collapse = ", ")))
  }
  if (nrow(lb) == 0L) return(errs)
  bad_frame <- unique(lb$frame[!lb$frame %in% geoframes])
  if (length(bad_frame) > 0L) {
    errs <- c(errs, sprintf("`labels` names geoframe(s) not in the object: %s",
                            .preview(bad_frame)))
  }
  check <- lb$frame %in% geoframes & !is.na(lb$member)
  is_member <- rep(TRUE, nrow(lb))
  is_member[check] <- vapply(
    which(check), function(i) lb$member[[i]] %in% members[[lb$frame[[i]]]],
    logical(1))
  if (any(!is_member)) {
    errs <- c(errs, sprintf(
      "`labels` names (geoframe/region) pairs that are not members: %s",
      .preview(unique(paste0(lb$frame, "/", lb$member)[!is_member]))))
  }
  for (nm in c("variant", "label")) {
    val <- lb[[nm]]
    if (!is.character(val) || anyNA(val) || any(!nzchar(val))) {
      errs <- c(errs, sprintf("`labels$%s` must be non-empty strings", nm))
    }
  }
  k <- .label_keys(lb)
  if (anyDuplicated(k)) {
    dup <- lb[duplicated(k), , drop = FALSE]
    errs <- c(errs, sprintf(
      "`labels` has more than one label for: %s",
      .preview(unique(paste0(
        dup$frame, "/", ifelse(is.na(dup$member), "<geoframe>", dup$member),
        " [", dup$variant, "]")))))
  }
  errs
}

#' Keep the label rows of the geoframes and regions that still exist
#' @noRd
.trim_labels <- function(lb, geoframes, members) {
  if (is.null(lb) || nrow(lb) == 0L) return(.empty_labels())
  ok <- lb$frame %in% geoframes
  ok[ok] <- vapply(which(ok), function(i) {
    is.na(lb$member[[i]]) || lb$member[[i]] %in% members[[lb$frame[[i]]]]
  }, logical(1))
  lb <- lb[ok, , drop = FALSE]
  rownames(lb) <- NULL
  lb
}

#' @noRd
.label_variant <- function(x, variant = NULL) {
  lb <- .label_table(x)
  if (is.null(variant)) {
    variant <- S7::prop(x, "meta")[["default_label"]]
    if (is.null(variant) || !variant %in% lb$variant) {
      variant <- if (nrow(lb) > 0L) lb$variant[[1L]] else .DEFAULT_VARIANT
    }
    return(variant)
  }
  if (!is.character(variant) || length(variant) != 1L || is.na(variant)) {
    .stop("`variant` must be a single string")
  }
  if (nrow(lb) > 0L && !variant %in% lb$variant) {
    .stop("no labels of variant \"%s\"; available: %s", variant,
          .preview(unique(lb$variant)))
  }
  variant
}

#' Labels of regions and geoframes
#'
#' Display names for the members of a [`GeoScale`]. A label belongs to a
#' region at a geoframe and to a named `variant` -- a free name such as
#' `"name"`, `"short"` or a language code -- so a region may carry several
#' names. The table is sparse: a geoframe may label every region, some, or
#' none, and whatever has no label is shown by its code. A row with
#' `region = NA` names the geoframe itself.
#'
#' `attach_labels_geoscale()` adds rows (and may set the default variant),
#' `geoscale_labels()` returns the table, and `geoscale_label()` looks names
#' up for a vector of codes, returning the code where there is no label.
#' Subsetting and pruning keep the labels of what remains, and the plots use
#' the default variant.
#'
#' @param x A [`GeoScale`].
#' @param labels A `data.frame` with columns `geoframe`, `region`, `label`
#'   and optionally `variant`. The `nestedscales` names `frame` and `member`
#'   are accepted for the first two.
#' @param variant For `attach_labels_geoscale()`: the variant the rows belong
#'   to when `labels` has no `variant` column (default `"label"`). For the
#'   readers: the variant to return; `NULL` is every variant in
#'   `geoscale_labels()` and the default one in `geoscale_label()`.
#' @param default Name of the variant used when none is asked for. `NULL`
#'   keeps the current default (initially the first variant attached).
#' @param overwrite Replace a label already present for the same region and
#'   variant. `FALSE` (default) makes that an error.
#' @param geoframe The geoframe: for `geoscale_labels()` a filter (`NULL`
#'   for all), for `geoscale_label()` the geoframe the codes are at.
#' @param region Character vector of region codes at `geoframe`; `NA` stands
#'   for the geoframe itself.
#'
#' @return `attach_labels_geoscale()` the [`GeoScale`];
#'   `geoscale_labels()` a `data.frame` with columns `geoframe`, `region`,
#'   `variant`, `label`; `geoscale_label()` a character vector as long as
#'   `region`.
#'
#' @examples
#' gs <- attach_labels_geoscale(
#'   geoscale_example(),
#'   data.frame(geoframe = "country", region = c("N", "S"),
#'              label = c("Northland", "Southland")),
#'   variant = "name"
#' )
#' gs <- attach_labels_geoscale(
#'   gs,
#'   data.frame(geoframe = "country", region = "N", label = "Nordland"),
#'   variant = "de"
#' )
#' geoscale_labels(gs)
#' geoscale_label(gs, c("N", "S"), "country")
#' geoscale_label(gs, c("N", "S"), "country", variant = "de")
#' geoscale_label(gs, c("N1", "ZB"), "zone")     # no labels: the codes
#' @name geoscale_labels
NULL

#' @rdname geoscale_labels
#' @export
attach_labels_geoscale <- function(x, labels, variant = NULL, default = NULL,
                                   overwrite = FALSE) {
  .check_geoscale(x)
  x <- .upgrade_geoscale(x)
  new <- .as_labels(labels, variant = variant)
  old <- .label_table(x)
  clash <- .label_keys(old) %in% .label_keys(new)
  if (any(clash)) {
    if (!isTRUE(overwrite)) {
      .stop("label(s) already present: %s; pass overwrite = TRUE to replace",
            .preview(unique(paste0(old$frame, "/", old$member)[clash])))
    }
    old <- old[!clash, , drop = FALSE]
  }
  out <- rbind(old, new)
  rownames(out) <- NULL
  meta <- S7::prop(x, "meta")
  if (!is.null(default)) {
    if (!is.character(default) || length(default) != 1L ||
        !default %in% out$variant) {
      .stop("`default` must be a variant of the label table: %s",
            .preview(unique(out$variant)))
    }
    meta$default_label <- default
  }
  S7::set_props(x, labels = out, meta = meta)
}

#' @rdname geoscale_labels
#' @export
geoscale_labels <- function(x, geoframe = NULL, variant = NULL) {
  .check_geoscale(x)
  lb <- .label_table(x)
  if (!is.null(geoframe)) {
    .check_geoframe(x, geoframe)
    lb <- lb[lb$frame == geoframe, , drop = FALSE]
  }
  if (!is.null(variant)) lb <- lb[lb$variant %in% variant, , drop = FALSE]
  rownames(lb) <- NULL
  .public_labels(lb)
}

#' @rdname geoscale_labels
#' @export
geoscale_label <-function(x, region, geoframe, variant = NULL) {
  .check_geoscale(x)
  .check_geoframe(x, geoframe)
  region <- as.character(region)
  variant <- .label_variant(x, variant)
  lb <- .label_table(x)
  lb <- lb[lb$frame == geoframe & lb$variant == variant, , drop = FALSE]
  out <- lb$label[match(region, lb$member)]
  miss <- is.na(out)
  out[miss] <- ifelse(is.na(region[miss]), geoframe, region[miss])
  out
}

#' The leaf column of a GeoScale
#'
#' The name of the leaftable column that identifies the leaves. It is the
#' finest geoframe unless the scale was built with another `leaf`, and it is
#' the name the leaf column carries in the results of
#' [`recast_to_geoleaves()`].
#'
#' @details An object saved by an earlier version, which stored the name as
#' `key`, is read as well.
#'
#' @param x A [`GeoScale`].
#' @return A single string.
#' @examples
#' geoscale_leaf_column(geoscale_example())
#' @export
geoscale_leaf_column <- function(x) {
  .check_geoscale(x)
  .leaf_col(x)
}

#' The name of the leaf column, whichever class definition the object has
#'
#' `nestedscales::scale_leaf_column()` reads the `leaf` attribute and, for an
#' object saved while the property was `key`, that one.
#' @noRd
.leaf_col <- function(x) {
  nestedscales::scale_leaf_column(x)
}
