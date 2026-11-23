# Cross-language round trips of GeoScale definitions, driven by
# tests/test_definition_roundtrip.py.
#
#   Rscript roundtrip.R <repo root> write <dir>
#       R writes one definition per case into <dir>
#   Rscript roundtrip.R <repo root> check <dir> <reference dir>
#       R reads the definitions Python wrote into <dir> and compares each
#       with the definition of the same name R wrote into <reference dir>
#       and with the GeoScale R builds for that case
#
# `check` prints one line per case: "OK <name>" or "FAIL <name>: <reason>".
#
# A definition holds the tables and the metadata of a GeoScale. It holds
# neither the geometry nor the hidden geoframes, and the class it names is
# read back as the core scale, from which the GeoScale is rebuilt.

args <- commandArgs(trailingOnly = TRUE)
suppressMessages(pkgload::load_all(args[[1]], quiet = TRUE, export_all = FALSE))
mode <- args[[2]]
dir <- args[[3]]

sq <- function(x0, y0, d = 1) {
  sprintf("POLYGON ((%g %g, %g %g, %g %g, %g %g, %g %g))", x0, y0, x0 + d, y0,
          x0 + d, y0 + d, x0, y0 + d, x0, y0)
}

with_geometry <- function() {
  if (!requireNamespace("sf", quietly = TRUE)) return(NULL)
  cells <- c(sq(0, 0), sq(1, 0), sq(0, 1), sq(1, 1), sq(2, 0), sq(2, 1),
             sq(10, 10, 2))
  shp <- sf::st_sf(
    cell = c("A1", "A2", "A3", "A4", "A5", "A6", "ROW"),
    geometry = sf::st_as_sfc(cells, crs = 4326))
  attach_geometry_geoscale(geoscale_example(), shp)
}

with_labels <- function() {
  x <- attach_labels_geoscale(
    geoscale_example(),
    data.frame(geoframe = c("country", "country", "country", "state", "cell"),
               region = c("N", "S", NA, "N1", "A3"),
               label = c("North", "South", "Country", "North one",
                         "Cell three")))
  x <- attach_labels_geoscale(
    x, data.frame(geoframe = c("country", "zone"), region = c("N", "ZB"),
                  label = c("Nth", "Zone B")),
    variant = "short", default = "short")
  hide_geoframes_geoscale(x, "zone")
}

finer_leaves <- function() {
  geoscale_from_leaftable(
    data.frame(big = c("Y", "X", "Y", "X", "X"),
               mid = c("m3", "m1", "m3", "m2", "m1"),
               id = c("p4", "p1", "p5", "p3", "p2"),
               w = c(2, 1, 2, 2, 3), n = c(1, 1, 1, 1, 1)),
    geoframes = c("big", "mid"), leaf = "id", weights = "w", name = "fine")
}

cases <- function() {
  out <- list(
    plain = geoscale_example(),
    labels = with_labels(),
    filtered = filter_geoscale(geoscale_example(), "country", "N"),
    filtered_labels = filter_geoscale(with_labels(), "zone", c("ZB", "ZC")),
    pruned = prune_geoscale(geoscale_example(), "state"),
    finer_leaves = finer_leaves()
  )
  g <- with_geometry()
  if (!is.null(g)) out$geometry <- g
  out
}

same_table <- function(a, b) {
  identical(names(a), names(b)) &&
    isTRUE(all.equal(as.data.frame(a), as.data.frame(b),
                     check.attributes = FALSE, tolerance = 1e-12))
}

# The class recorded in a definition is read back when it is registered;
# otherwise the core scale is read.
read_definition <- function(file) {
  tryCatch(nestedscales::read_scale(file), error = function(e) {
    nestedscales::read_scale(file, class = "core")
  })
}

as_geoscale <- function(x) {
  if (S7::S7_inherits(x, GeoScale)) return(x)
  GeoScale(leaftable = nestedscales::scale_leaftable(x),
           geoframes = nestedscales::scale_frames(x),
           members = S7::prop(x, "members"), meta = S7::prop(x, "meta"),
           leaf = nestedscales::scale_leaf_column(x),
           labels = nestedscales::scale_labels(x))
}

header_class <- function(file) {
  jsonlite::read_json(file)[["class"]]
}

same_definition <- function(got, orig) {
  m1 <- S7::prop(got, "meta")
  m0 <- S7::prop(orig, "meta")
  checks <- c(
    class = identical(class(got), class(orig)),
    geoframes = identical(nestedscales::scale_frames(got),
                          nestedscales::scale_frames(orig)),
    leaf = identical(nestedscales::scale_leaf_column(got),
                     nestedscales::scale_leaf_column(orig)),
    members = identical(S7::prop(got, "members"), S7::prop(orig, "members")),
    leaftable = same_table(nestedscales::scale_leaftable(got),
                           nestedscales::scale_leaftable(orig)),
    meta = isTRUE(all.equal(m1, m0, tolerance = 1e-12)),
    meta_names = identical(names(m1), names(m0)),
    id = identical(nestedscales::scale_id(got), nestedscales::scale_id(orig)),
    attributes = same_table(nestedscales::scale_attributes(got),
                            nestedscales::scale_attributes(orig)),
    aliases = same_table(nestedscales::scale_aliases(got),
                         nestedscales::scale_aliases(orig)),
    labels = same_table(nestedscales::scale_labels(got),
                        nestedscales::scale_labels(orig))
  )
  names(checks)[!checks]
}

# The GeoScale rebuilt from a definition against the one R builds.
same_as_built <- function(got, built) {
  gs <- as_geoscale(got)
  checks <- c(
    id_built = identical(geoscale_id(gs), geoscale_id(built)),
    geoframes_built = identical(geoscale_geoframes(gs),
                                geoscale_geoframes(built)),
    leaf_built = identical(geoscale_leaf_column(gs),
                           geoscale_leaf_column(built)),
    leaftable_built = same_table(geoscale_leaftable(gs),
                                 geoscale_leaftable(built)),
    labels_built = same_table(geoscale_labels(gs), geoscale_labels(built)),
    weights_built = identical(geoscale_weights(gs), geoscale_weights(built)),
    coverage_built = isTRUE(all.equal(geoscale_coverage(gs),
                                      geoscale_coverage(built))),
    meta_built = isTRUE(all.equal(S7::prop(gs, "meta"),
                                  S7::prop(built, "meta"), tolerance = 1e-12))
  )
  names(checks)[!checks]
}

if (mode == "write") {
  cs <- cases()
  for (nm in names(cs)) {
    nestedscales::write_scale(cs[[nm]], file.path(dir, paste0(nm, ".json")),
                              overwrite = TRUE)
  }
} else {
  ref <- args[[4]]
  built <- cases()
  for (f in sort(list.files(dir))) {
    nm <- sub("\\.json$", "", f)
    bad <- tryCatch({
      got <- read_definition(file.path(dir, f))
      out <- same_definition(got, read_definition(file.path(ref, f)))
      if (!identical(header_class(file.path(dir, f)),
                     header_class(file.path(ref, f)))) {
        out <- c(out, "header_class")
      }
      c(out, same_as_built(got, built[[nm]]))
    }, error = function(e) conditionMessage(e))
    cat(if (length(bad)) sprintf("FAIL %s: %s\n", nm,
                                 paste(bad, collapse = ", "))
        else sprintf("OK %s\n", nm))
  }
}
