# =========================================================================== #
# make_goldens.R -- generate the cross-language golden specs (geoscales).
#
# Usage (from the package root):
#   Rscript tools/specs/make_goldens.R
#
# Writes, per specs/README.md:
#   specs/regions/<name>.yaml              named structures (leaftable form)
#   specs/golden/NNN-<case>/input.yaml     structure ref + op + params + input
#   specs/golden/NNN-<case>/expected.csv   the R implementation's result
#
# The R test suite re-loads every pair and re-runs the op
# (tests/testthat/test-specs-golden.R sources THIS file for the runner).
# Numeric output is %.17g -- regeneration is byte-stable. Behaviour change
# => regenerate the goldens in the same commit.
# =========================================================================== #

suppressMessages({
  stopifnot(file.exists("DESCRIPTION"))
  PKG <- unname(read.dcf("DESCRIPTION")[1, "Package"])
  if (!isNamespaceLoaded(PKG)) {
    if (requireNamespace("pkgload", quietly = TRUE)) {
      pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
    } else {
      library(PKG, character.only = TRUE)
    }
  }
  library(yaml)
})

STRUCT_DIR <- file.path("specs", "regions")
GOLDEN_DIR <- file.path("specs", "golden")

# ---- structures ----------------------------------------------------------- #

spec_structures <- function() {
  ex <- geoscales::geoscale_leaftable(geoscales::geoscale_example())
  ex$region <- NULL                     # the key column is re-derived
  bands <- data.frame(band = rep(c("X", "Y"), 3),
                      atom = paste0("A", 1:6),
                      km2 = c(100, 200, 300, 400, 500, 600))
  list(
    example = list(leaftable = ex,
                   geoframes = c("country", "state", "zone", "atom"),
                   weights = c("km2", "pop")),
    bands   = list(leaftable = bands, geoframes = c("band", "atom"),
                   weights = "km2")
  )
}

load_structure <- function(name, dir = STRUCT_DIR) {
  y <- yaml::read_yaml(file.path(dir, paste0(name, ".yaml")))
  lt <- as.data.frame(do.call(rbind, lapply(y$leaftable, as.data.frame)))
  for (cc in unlist(y$weights)) lt[[cc]] <- as.numeric(lt[[cc]])
  for (cc in unlist(y$geoframes)) {
    lt[[cc]][lt[[cc]] == "NA"] <- NA_character_
  }
  geoscales::geoscale_from_leaftable(
    lt, geoframes = unlist(y$geoframes), weights = unlist(y$weights),
    name = y$name)
}

# ---- the op runner (shared by generator and test) ------------------------- #

`%||%` <- function(a, b) if (is.null(a)) b else a

run_spec_op <- function(spec, structures_dir = STRUCT_DIR) {
  x <- as.data.frame(do.call(rbind, lapply(spec$input, as.data.frame)))
  for (cc in names(x)) {
    if (!is.na(suppressWarnings(as.numeric(x[[cc]][1]))) &&
        !cc %in% c("id")) x[[cc]] <- as.numeric(x[[cc]])
  }
  p <- spec$params
  gs <- load_structure(spec$structure, structures_dir)
  out <- switch(spec$op,
    recast = geoscales::recast_geoscale(
      x, gs, from = p$from, to = p$to, rule = p$rule,
      weight = p$weight %||% NULL,
      na_action = p$na_action %||% "drop"),
    to_atoms = geoscales::recast_to_geoatoms(
      x, gs, from = p$from, rule = p$rule, weight = p$weight %||% NULL),
    from_atoms = geoscales::recast_from_geoatoms(
      x, gs, to = p$to, rule = p$rule, values = unlist(p$values)),
    join = geoscales::join_geoscale(
      x, gs, geoframe = p$geoframe,
      geoframes = if (!is.null(p$geoframes)) unlist(p$geoframes) else NULL,
      meta = isTRUE(p$meta), weight = p$weight %||% NULL,
      as_factor = FALSE),
    filter = geoscales::geoscale_leaftable(
      geoscales::filter_geoscale(gs, p$geoframe, unlist(p$regions))),
    prune = geoscales::geoscale_leaftable(
      geoscales::prune_geoscale(gs, p$geoframe, keep_geometry = FALSE)),
    stop("unknown op: ", spec$op))
  out <- as.data.frame(out)
  key <- intersect(c("id", "country", "state", "zone", "atom", "region",
                     "band"), names(out))
  if (length(key)) {
    out <- out[do.call(order, out[key]), , drop = FALSE]
  }
  rownames(out) <- NULL
  out
}

# ---- case set ------------------------------------------------------------- #

.in_atoms <- function(col = "cap", v = NULL, ids = NULL) {
  d <- data.frame(atom = paste0("A", 1:6))
  d[[col]] <- if (is.null(v)) as.numeric(seq_len(nrow(d))) else
    rep_len(as.numeric(v), nrow(d))
  if (!is.null(ids)) {
    d <- do.call(rbind, lapply(ids, function(i) cbind(d, id = i)))
  }
  d
}

spec_cases <- function() {
  list(
    list(id = "001-recast-atom-country-sum", structure = "example",
         op = "recast", input = .in_atoms(ids = c("A", "B")),
         params = list(from = "atom", to = "country", rule = "sum")),
    list(id = "002-recast-atom-country-weighted-mean",
         structure = "example", op = "recast", input = .in_atoms(),
         params = list(from = "atom", to = "country",
                       rule = "weighted_mean", weight = "km2")),
    list(id = "003-recast-country-state-sum-down", structure = "example",
         op = "recast",
         input = data.frame(country = c("N", "S"), cap = c(120, 60)),
         params = list(from = "country", to = "state", rule = "sum",
                       weight = "km2")),
    list(id = "004-recast-state-zone-crosscut", structure = "example",
         op = "recast",
         input = data.frame(state = c("N1", "N2", "S1"),
                            cap = c(30, 70, 110)),
         params = list(from = "state", to = "zone", rule = "sum",
                       weight = "km2")),
    list(id = "005-recast-atom-country-copy", structure = "example",
         op = "recast", input = .in_atoms(col = "flag", v = 7),
         params = list(from = "atom", to = "country", rule = "copy")),
    list(id = "006-recast-keep-na", structure = "example",
         op = "recast",
         input = rbind(.in_atoms(v = 1),
                       data.frame(atom = "ROW", cap = 1)),
         params = list(from = "atom", to = "country", rule = "sum",
                       weight = "km2", na_action = "keep")),
    list(id = "007-to-atoms-sum", structure = "example",
         op = "to_atoms",
         input = data.frame(country = c("N", "S"), cap = c(120, 60)),
         params = list(from = "country", rule = "sum", weight = "km2")),
    list(id = "008-from-atoms-sum", structure = "example",
         op = "from_atoms",
         input = data.frame(region = paste0("A", 1:6),
                            cap = as.numeric(1:6)),
         params = list(to = "state", rule = "sum",
                       values = list("cap"))),
    list(id = "009-join-meta-km2", structure = "example",
         op = "join", input = .in_atoms(),
         params = list(geoframe = "atom", meta = TRUE, weight = "km2")),
    list(id = "010-join-geoframes", structure = "example",
         op = "join", input = .in_atoms(),
         params = list(geoframe = "atom",
                       geoframes = list("country", "state"))),
    list(id = "011-filter-north", structure = "example",
         op = "filter", input = data.frame(),
         params = list(geoframe = "country", regions = list("N"))),
    list(id = "012-prune-state", structure = "example",
         op = "prune", input = data.frame(),
         params = list(geoframe = "state"))
  )
}

# ---- serialisation (identical to the timescales tool) --------------------- #

.df_records <- function(d) {
  lapply(seq_len(nrow(d)), function(i) {
    r <- as.list(d[i, , drop = FALSE])
    lapply(r, function(v) if (is.numeric(v)) unname(v) else
      unname(as.character(v)))
  })
}

write_expected_csv <- function(out, path) {
  fmt <- out
  for (cc in names(fmt)) {
    if (is.numeric(fmt[[cc]])) fmt[[cc]] <- sprintf("%.17g", fmt[[cc]])
  }
  utils::write.csv(fmt, path, row.names = FALSE, quote = TRUE, na = "NA",
                   eol = "\n")
}

make_goldens <- function() {
  dir.create(STRUCT_DIR, recursive = TRUE, showWarnings = FALSE)
  for (nm in names(spec_structures())) {
    st <- spec_structures()[[nm]]
    yaml::write_yaml(
      # "spec_" prefix: registry caches are keyed by NAME (see the
      # timescales tool)
      list(name = paste0("spec_", nm), geoframes = st$geoframes,
           weights = st$weights,
           leaftable = .df_records(st$leaftable)),
      file.path(STRUCT_DIR, paste0(nm, ".yaml")))
  }
  for (case in spec_cases()) {
    d <- file.path(GOLDEN_DIR, case$id)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    spec <- list(structure = case$structure, op = case$op,
                 params = case$params,
                 input = if (nrow(case$input)) .df_records(case$input)
                         else list())
    yaml::write_yaml(spec, file.path(d, "input.yaml"))
    out <- suppressWarnings(run_spec_op(spec))
    write_expected_csv(out, file.path(d, "expected.csv"))
  }
  message("Wrote ", length(spec_cases()), " golden cases and ",
          length(spec_structures()), " structures under specs/")
}

if (sys.nframe() == 0L) make_goldens()
