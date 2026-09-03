#' Recast data keyed by a pair of regions
#'
#' Aggregate a table whose rows are region *pairs* -- transmission corridors,
#' trade flows, commuting matrices -- to a coarser geoframe. Both endpoints are
#' mapped through the hierarchy, pairs that land inside a single target region
#' become internal and are dropped, and the rest are aggregated by rule.
#'
#' A pair table cannot be recast with [`recast_geoscale()`], which maps one key
#' column. Mapping the two endpoints separately would leave the internal pairs
#' in place, where they would be read as a region trading with itself.
#'
#' Aggregation only: the target must be coarser than the source. Splitting one
#' corridor across the pairs of its members has no unique answer.
#'
#' The result is not completed to a target vocabulary. Completing pairs would
#' cross-join every target region with every other, which is quadratic in the
#' region count and almost entirely empty.
#'
#' @param x The data: a data.frame, tibble, data.table, or arrow
#'   table/dataset/query with two endpoint columns.
#' @param gs The [`Geoscale`] the endpoints are keyed in.
#' @param to Target geoframe name, coarser than `from`.
#' @param from Geoframe the endpoint codes belong to. `NULL` (default) is the
#'   finest (atom) geoframe.
#' @param src,dst The endpoint columns. Default `"src"` and `"dst"`.
#' @param values Value columns to aggregate. `NULL` (default) is every numeric
#'   column that is not an endpoint, the weight, or a geoframe.
#' @param rule Aggregation rule, as in [`recast_geoscale()`]: one name for all
#'   value columns, or a named vector per column.
#' @param weight Name of a column of `x` to weight by, for `weighted_mean`.
#'   `NULL` (default) uses a `weight` column if present; without one the
#'   weights are equal and `weighted_mean` is a plain mean.
#' @param na_rm Read an `NA` value as "this pair says nothing" rather than as
#'   an unknown that makes the whole group `NA` (default `FALSE`). Only an
#'   all-`NA` group stays `NA`.
#' @param directed Keep the orientation of each pair (default `TRUE`). `FALSE`
#'   sorts the endpoints, so `A->B` and `B->A` aggregate together.
#' @param drop_internal Drop pairs whose endpoints land in the same target
#'   region (default `TRUE`). `FALSE` keeps them as self-pairs.
#' @param collect For lazy inputs: materialise (`TRUE`) or return the query
#'   (default).
#'
#' @return One row per (endpoint pair x identifier combination), the endpoint
#'   columns keeping their input names and holding `to`-level codes. In the
#'   input's class; lazy in, lazy out.
#'
#' @seealso [`recast_geoscale()`], [`recast_from_geoatoms()`]
#'
#' @examples
#' gs <- geoscale_example()
#' lines <- data.frame(
#'   src = c("A1", "A3", "A1"),
#'   dst = c("A2", "A5", "A5"),
#'   capacity = c(100, 200, 300)
#' )
#' # A1-A2 is internal to state N1 and is dropped; the other two survive
#' recast_pairs(lines, gs, to = "state", rule = "sum")
#' @export
recast_pairs <- function(x, gs, to, from = NULL,
                         src = "src", dst = "dst",
                         values = NULL, rule = NULL, weight = NULL,
                         na_rm = FALSE, directed = TRUE,
                         drop_internal = TRUE, collect = NULL) {
  .check_geoscale(gs, "gs")
  backend <- .gs_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  schema <- .gs_schema(x)
  .check_gs_cols(schema)
  .check_geoframe(gs, to, "to")
  if (is.null(from)) from <- geoscale_geoframes(gs, finest = TRUE)
  .check_geoframe(gs, from, "from")

  if (geoscale_rank(gs, to) > geoscale_rank(gs, from)) {
    .stop(paste0("`to` = \"%s\" is finer than `from` = \"%s\"; pairs ",
                 "aggregate only"), to, from)
  }
  if (identical(src, dst)) .stop("`src` and `dst` must differ")
  for (nm in c(src, dst)) {
    if (!nm %in% names(schema)) {
      .stop("`x` has no column named `%s`; pass `src=` / `dst=`", nm)
    }
  }

  geoframes_all <- S7::prop(gs, "geoframes")
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
  drop_cols <- c(src, dst, wt_col, geoframes_all)
  values <- .geo_values_for(schema, src, drop_cols, values)
  values <- setdiff(values, dst)
  id_cols <- setdiff(names(schema), c(src, dst, values, wt_col, geoframes_all))
  rules <- .geo_rules_for(values, rule, NULL)
  .geo_no_share(rules, "recast_pairs")
  has_weight <- wt_col %in% names(schema)

  # One lookup, applied to each endpoint. Codes nest, so this is a plain
  # hierarchy read rather than a weighted crosswalk.
  leaves <- S7::prop(gs, "leaftable")
  look <- unique(data.frame(
    .gs_from = as.character(leaves[[from]]),
    .gs_to   = as.character(leaves[[to]]),
    stringsAsFactors = FALSE
  ))
  look <- look[!is.na(look$.gs_from), , drop = FALSE]

  ends <- .gs_pull(dplyr::distinct(dplyr::select(
    .gs_lazy(x, backend), dplyr::all_of(c(src, dst)))))
  ends <- unique(stats::na.omit(c(as.character(ends[[src]]),
                                  as.character(ends[[dst]]))))
  unknown <- setdiff(ends, look$.gs_from)
  if (length(unknown) > 0L) {
    .warn(paste0("%d endpoint code(s) are not present at geoframe `%s` ",
                 "and their pairs were dropped: %s"),
          length(unknown), from, .preview(unknown))
  }
  if (length(intersect(ends, look$.gs_from)) == 0L) {
    .stop(paste0("no endpoint of `x` matched geoframe `%s`; check `from=`, ",
                 "`src=` and `dst=`"), from)
  }

  ls <- stats::setNames(look, c(src, ".gs_src"))
  ld <- stats::setNames(look, c(dst, ".gs_dst"))
  out <- .gs_lazy(x, backend) |>
    dplyr::inner_join(ls, by = src, na_matches = "na") |>
    dplyr::inner_join(ld, by = dst, na_matches = "na")

  if (drop_internal) {
    n_int <- .gs_pull(dplyr::summarise(
      out, n = sum(as.integer(.data$.gs_src == .data$.gs_dst))))$n[1]
    if (isTRUE(n_int > 0L)) {
      .warn(paste0("%d pair(s) fall inside a single `%s` region and were ",
                   "dropped as internal"), n_int, to)
    }
    out <- dplyr::filter(out, .data$.gs_src != .data$.gs_dst)
  }

  if (!directed) {
    out <- dplyr::mutate(
      out,
      .gs_a = dplyr::if_else(.data$.gs_src <= .data$.gs_dst,
                             .data$.gs_src, .data$.gs_dst),
      .gs_b = dplyr::if_else(.data$.gs_src <= .data$.gs_dst,
                             .data$.gs_dst, .data$.gs_src)) |>
      dplyr::mutate(.gs_src = .data$.gs_a, .gs_dst = .data$.gs_b) |>
      dplyr::select(-".gs_a", -".gs_b")
  }

  if (!has_weight) out <- dplyr::mutate(out, !!rlang::sym(wt_col) := 1)

  grp_cols <- c(".gs_src", ".gs_dst", id_cols)
  exprs <- .geo_group_exprs(values, rules, wt_col, na_rm)
  copy_cols <- values[vapply(rules, function(r) r$rule == "copy",
                             logical(1))]
  .geo_check_copy_rule(out, grp_cols, copy_cols)

  res <- out |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
    dplyr::summarise(!!!exprs, .groups = "drop") |>
    dplyr::rename(!!rlang::sym(src) := ".gs_src",
                  !!rlang::sym(dst) := ".gs_dst")

  keep <- c(src, dst, id_cols, values)
  if (.gs_is_lazy(backend) && !isTRUE(collect)) {
    return(dplyr::select(res, dplyr::all_of(keep)))
  }
  res <- as.data.frame(dplyr::collect(res))
  res <- res[, keep, drop = FALSE]
  ord <- S7::prop(gs, "members")[[to]]
  res <- res[order(match(res[[src]], ord), match(res[[dst]], ord),
                   na.last = TRUE), , drop = FALSE]
  rownames(res) <- NULL
  .gs_restore(res, backend, collect = collect)
}
