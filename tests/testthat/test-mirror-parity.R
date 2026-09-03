# =========================================================================== #
# The sibling API mirror, enforced. geoscales Imports timescales, so this
# suite can see both packages and assert the 0.5.0 harmonization ruling
# (CONVENTIONS.md, "Sibling API mirror"): every export is either PAIRED
# with its twin through the vocabulary translation, or a DECLARED
# one-sider. A new export on either side that is neither fails here --
# which is the point.
# =========================================================================== #

skip_if_not_installed("timescales")

.mirror_translate <- function(nm) {
  nm <- gsub("calendar", "geoscale", nm, fixed = TRUE)
  nm <- gsub("Calendar", "Geoscale", nm, fixed = TRUE)
  nm <- gsub("CALENDAR", "GEOSCALE", nm, fixed = TRUE)
  nm <- gsub("timeslices", "regions", nm, fixed = TRUE)
  nm <- gsub("timeframes", "geoframes", nm, fixed = TRUE)
  nm <- gsub("timeframe", "geoframe", nm, fixed = TRUE)
  nm <- gsub("TIMEFRAMES", "GEOFRAMES", nm, fixed = TRUE)
  nm <- gsub("timebase", "geoatoms", nm, fixed = TRUE)
  nm
}

# Special pairs the translation cannot derive
.SPECIAL_PAIRS <- c(datetime_to_timeslice = "coords_to_region")

# Deliberate one-siders (CONVENTIONS.md rulings). Time-only:
.TS_ONE_SIDERS <- c(
  # datetime machinery
  "base_calendar", "expand_calendar", "as_timeframe",
  # token + conversion registries (space's override mechanism is the
  # geoscale_map registry -- ruling 2026-08-25, no conversion registry)
  "register_calendar_token", "get_calendar_token", "list_calendar_tokens",
  "register_calendar_conversion", "get_calendar_conversion",
  "list_calendar_conversions", "clear_calendar_conversions",
  "ALIGNMENT_RULES",
  # the wall-calendar family + axis helper + the shipped catalog
  "calendar_wall_plot", "calendar_wall_layout", "calendar_weekdays",
  "calendar_breaks", "calendars", "calendar_catalog",
  # the catalog shortcut: geoscales ships no designs (no bundled maps),
  # so there is no name-based geoscale() constructor
  "calendar",
  # per-frame qualified-tile geom exists only in time
  "geom_calendar_tile",
  # instant helper unique to the time grid
  "instant_to_datetime"
)
# Space-only:
.GS_ONE_SIDERS <- c(
  # geometry (sf-backed, the core is geometry-free)
  "attach_geometry_geoscale", "geoscale_geometry", "add_area_geoscale",
  # providers: maps have owners; time has no data provider layer
  "register_geoscale_provider", "get_geoscale_provider",
  "list_geoscale_providers", "ne_geoscale", "ne_source",
  "geoscale_from_provider",
  # space need not nest; time always does
  "geoscale_nests",
  # many named weights vs the fixed share/weight pair
  "geoscale_weights",
  # misc space-only surface
  "geoscale_example", "is_valid_geoframe", "recast_to_geoatoms",
  "recast_from_geoatoms", "CORE_LEVELS",
  # telescoping zoom. A time twin (hourly for a few days, daily for the
  # rest of the month, monthly beyond) is conceptually valid and is
  # DEFERRED, not ruled out -- listed here so the parity test stays
  # honest about which one-siders are principled and which are pending.
  "zoom_geoscale",
  # data keyed by a pair of regions -- a corridor, a flow, a commute. Two
  # slices of time do not form an edge, so there is no time twin.
  "recast_pairs"
)
# NOTE: recast_to/from_geoatoms are NOT one-siders (they pair with the
# timebase route); they are in the list above only if translation fails --
# see the pairing test, which removes what pairs successfully.
.GS_ONE_SIDERS <- setdiff(.GS_ONE_SIDERS,
                          c("recast_to_geoatoms", "recast_from_geoatoms",
                            "CORE_LEVELS"))

.ts_exports <- function() {
  e <- getNamespaceExports("timescales")
  e[!grepl("^\\[|\\.Calendar$|^recast$", e)]
}
.gs_exports <- function() {
  e <- getNamespaceExports("geoscales")
  # `recast` is re-exported FROM timescales; S3/`[` methods mirror by class
  e[!grepl("^\\[|\\.Geoscale$|^recast$", e)]
}

test_that("every export is paired or a declared one-sider", {
  ts <- .ts_exports()
  gs <- .gs_exports()

  unpaired_ts <- character()
  for (nm in setdiff(ts, .TS_ONE_SIDERS)) {
    twin <- if (nm %in% names(.SPECIAL_PAIRS)) .SPECIAL_PAIRS[[nm]]
            else .mirror_translate(nm)
    if (!twin %in% gs) unpaired_ts <- c(unpaired_ts, paste0(nm, " -> ", twin))
  }
  expect_identical(unpaired_ts, character(0))

  # and the reverse: every gs export is reachable from some ts export or
  # declared one-sided
  reachable <- c(vapply(setdiff(ts, .TS_ONE_SIDERS), .mirror_translate, ""),
                 unname(.SPECIAL_PAIRS))
  unpaired_gs <- setdiff(gs, c(reachable, .GS_ONE_SIDERS))
  expect_identical(unpaired_gs, character(0))
})

# Shared arguments whose NAMES and DEFAULTS must agree across a pair
.SHARED_ARGS <- list(
  list("join_calendar", "join_geoscale",
       args = c("x", "key", "meta", "as_factor", "collect")),
  list("recast_calendar", "recast_geoscale",
       args = c("x", "key", "values", "rule", "na_action", "collect")),
  list("recast_to_timebase", "recast_to_geoatoms",
       args = c("x", "key", "values", "rule", "attach_weight", "collect")),
  list("recast_from_timebase", "recast_from_geoatoms",
       args = c("x", "key", "values", "rule", "na_action", "collect")),
  list("filter_calendar", "filter_geoscale", args = "x"),
  list("prune_calendar", "prune_geoscale", args = "x"),
  list("calendar_coverage", "geoscale_coverage",
       args = c("x", "weight")),
  list("calendar_leaftable", "geoscale_leaftable", args = "x"),
  list("calendar_ancestry", "geoscale_ancestry", args = "x"),
  list("calendar_family", "geoscale_family",
       args = c("x", "parent", "child")),
  list("calendar_timeframes", "geoscale_geoframes",
       args = c("x", "finest")),
  list("calendar_autoplot", "geoscale_autoplot",
       args = c("x", "type", "rule", "colour", "linewidth", "frame",
                "frame_fill", "connectors", "direction", "gap", "rotate",
                "view", "angle", "ratio", "data", "z"))
)

test_that("paired signatures agree on their shared arguments", {
  for (spec in .SHARED_ARGS) {
    f_ts <- get(spec[[1]], envir = asNamespace("timescales"))
    f_gs <- get(spec[[2]], envir = asNamespace("geoscales"))
    fm_ts <- formals(f_ts); fm_gs <- formals(f_gs)
    for (a in spec$args) {
      expect_true(a %in% names(fm_ts),
                  label = sprintf("%s has `%s`", spec[[1]], a))
      expect_true(a %in% names(fm_gs),
                  label = sprintf("%s has `%s`", spec[[2]], a))
      expect_identical(
        deparse(fm_ts[[a]]), deparse(fm_gs[[a]]),
        label = sprintf("default of `%s` agrees between %s and %s",
                        a, spec[[1]], spec[[2]]))
    }
  }
})

test_that("na_action choices are identical everywhere they appear", {
  fns <- list(timescales::recast_calendar, timescales::recast_from_timebase,
              geoscales::recast_geoscale, geoscales::recast_from_geoatoms)
  for (f in fns) {
    expect_identical(eval(formals(f)$na_action),
                     c("drop", "error", "keep"))
  }
})
