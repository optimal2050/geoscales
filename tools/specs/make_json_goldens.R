# =========================================================================== #
# make_json_goldens.R -- broad cross-language goldens for the Python port.
#
# Usage (from the package root):
#   Rscript tools/specs/make_json_goldens.R [path/to/nestedscales]
#
# Loads geoscales from SOURCE. nestedscales is the installed package, or is
# loaded from source when its path is given. Writes specs/json/<topic>.json:
# each case is a call and its result, with every warning and error message.
# Geometry is synthetic (WKT squares), so no boundary data is needed;
# geometric results are compared as type, area and bounds.
# =========================================================================== #

args <- commandArgs(trailingOnly = TRUE)
suppressMessages({
  if (length(args)) pkgload::load_all(args[[1]], quiet = TRUE, export_all = FALSE)
  pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
  library(sf)
})
sf::sf_use_s2(FALSE)
out_dir <- file.path("specs", "json")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

`%||%` <- function(a, b) if (is.null(a)) b else a
vec <- function(x) I(as.character(x))
rows <- function(df) {
  df <- as.data.frame(df)
  if (inherits(df, "sf") || "geometry" %in% names(df)) df$geometry <- NULL
  for (c in names(df)) if (is.factor(df[[c]])) df[[c]] <- as.character(df[[c]])
  if (nrow(df) == 0L) return(I(list()))
  lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
}
tab <- function(df) list(
  columns = lapply(df, function(c) if (is.character(c)) vec(c) else I(as.numeric(c))),
  types = lapply(df, function(c) if (is.character(c)) "string" else "double")
)
geom_info <- function(g) {
  if (is.null(g)) return(NULL)
  lapply(seq_along(g), function(i) {
    gi <- g[i]
    if (sf::st_is_empty(gi)) return(list(empty = TRUE))
    b <- sf::st_bbox(gi)
    list(type = as.character(sf::st_geometry_type(gi)),
         area = as.numeric(sf::st_area(gi)),
         bounds = I(unname(as.numeric(b))))
  })
}

# A named numeric vector: JSON arrays carry no names, so it travels as an
# object under `named`.
nv <- function(...) structure(list(values = list(...)), class = "gs_named")

# A scale spec, rebuilt identically by every binding.
#   list(build = "example" | "leaftable" | "build", ..., steps = list(...),
#        geometry = list(wkt =, crs =, by =, geoframe =))
build_gs <- function(spec) {
  x <- switch(spec$build,
    example = geoscale_example(),
    leaftable = do.call(geoscale_from_leaftable,
                        c(list(as.data.frame(spec$leaftable,
                                             stringsAsFactors = FALSE)),
                          spec$args)),
    build = do.call(geoscale_build,
                    c(lapply(spec$xwalks, as.data.frame, stringsAsFactors = FALSE),
                      spec$args)))
  if (!is.null(spec$geometry)) {
    g <- spec$geometry
    shp <- sf::st_sf(code = as.character(unlist(g$codes)),
                     geometry = sf::st_as_sfc(as.character(unlist(g$wkt)),
                                              crs = g$crs))
    names(shp)[1] <- g$by
    x <- attach_geometry_geoscale(x, shp, by = g$by, geoframe = g$geoframe)
  }
  for (st in spec$steps) x <- do.call(st$fn, c(list(x), lapply(st$args, dec_arg)))
  x
}
describe <- function(x) {
  m <- S7::prop(x, "meta")
  list(frames = vec(geoscale_geoframes(x)),
       members = lapply(S7::prop(x, "members"), vec),
       leaf = geoscale_leaf_column(x),
       id = geoscale_id(x),
       name = m[["name"]], parent_name = m[["parent_name"]],
       weights = vec(m[["weights"]] %||% character()),
       default_weight = m[["default_weight"]],
       default_label = m[["default_label"]],
       row_permuted = m[["row_permuted"]],
       coverage = if (!is.null(m[["coverage"]])) as.list(m[["coverage"]]),
       parent_totals = if (!is.null(m[["parent_totals"]])) as.list(m[["parent_totals"]]),
       crs = m[["crs"]],
       hidden = vec(geoscale_geoframes(x, visible = FALSE)),
       labels = rows(geoscale_labels(x)),
       leaftable = rows(geoscale_leaftable(x)),
       geometry = geom_info(S7::prop(x, "geometry")))
}
encode <- function(v) {
  if (S7::S7_inherits(v, GeoScale)) return(list(kind = "geoscale", value = describe(v)))
  if (inherits(v, "sf")) {
    return(list(kind = "sf", value = rows(v),
                geometry = geom_info(sf::st_geometry(v))))
  }
  if (inherits(v, "scale_tree")) {
    return(list(kind = "tree", header = attr(v, "header"), value = rows(v)))
  }
  if (is.data.frame(v)) return(list(kind = "table", value = rows(v)))
  if (is.character(v)) return(list(kind = "character", value = vec(v)))
  if (is.logical(v) && length(v) == 1L) {
    return(list(kind = "verdict", value = isTRUE(v),
                offenders = vec(attr(v, "offenders") %||% character())))
  }
  if (is.numeric(v)) return(list(kind = "numeric", value = I(as.numeric(v))))
  if (is.list(v)) return(list(kind = "list", value = v))
  stop("cannot encode ", class(v)[1])
}
run <- function(expr) {
  w <- character()
  r <- withCallingHandlers(
    tryCatch(list(error = FALSE, value = expr),
             error = function(e) list(error = TRUE, message = conditionMessage(e))),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    },
    message = function(cnd) invokeRestart("muffleMessage"))
  if (!r$error) r$value <- encode(r$value)
  c(r, list(warnings = vec(w)))
}
is_spec <- function(a) is.list(a) && !inherits(a, "gs_named") && !is.null(a$build)
# The arguments of a spec's steps are encoded like those of a call.
enc_spec <- function(s) {
  s$steps <- lapply(s$steps, function(st) {
    list(fn = st$fn, args = lapply(st$args, enc_arg))
  })
  if (length(s$steps) == 0L) s$steps <- NULL
  s
}
enc_arg <- function(a) {
  if (inherits(a, "gs_named")) return(list(named = a$values))
  if (is_spec(a)) return(list(scale = enc_spec(a)))
  if (inherits(a, "sfc")) {
    return(list(sfc = list(wkt = I(sf::st_as_text(a)), crs = sf::st_crs(a)$input)))
  }
  if (inherits(a, "sf")) {
    g <- sf::st_geometry(a)
    return(list(sf = list(table = tab(sf::st_drop_geometry(a)),
                          wkt = I(sf::st_as_text(g)),
                          crs = sf::st_crs(g)$input)))
  }
  if (is.data.frame(a)) return(list(table = tab(a)))
  a
}
dec_arg <- function(a) {
  if (inherits(a, "gs_named")) return(unlist(a$values))
  if (is_spec(a)) build_gs(a) else a
}
cases <- list()
# Dotted formals: R partial-matches named arguments against formals before
# `...`, and a call's own `to =` would otherwise bind to `topic`.
call <- function(.topic, .fn, ..., ordered = TRUE) {
  a <- list(...)
  r <- run(do.call(get(.fn), lapply(a, dec_arg)))
  cases[[.topic]][[length(cases[[.topic]]) + 1L]] <<- c(
    list(fn = .fn, args = lapply(a, enc_arg), ordered = ordered), r)
}
step <- function(fn, ...) list(fn = fn, args = list(...))
ex <- list(build = "example")
exs <- function(...) list(build = "example", steps = list(...))

# synthetic geometry: one square per leaf, ROW far away
sq <- function(x0, y0, d = 1) {
  sprintf("POLYGON ((%g %g, %g %g, %g %g, %g %g, %g %g))", x0, y0, x0 + d, y0,
          x0 + d, y0 + d, x0, y0 + d, x0, y0)
}
leaves <- c("A1", "A2", "A3", "A4", "A5", "A6", "ROW")
cells <- c(sq(0, 0), sq(1, 0), sq(0, 1), sq(1, 1), sq(2, 0), sq(2, 1), sq(10, 10, 2))
geo_cells <- list(wkt = I(cells), codes = I(leaves), crs = 4326, by = "cell",
                  geoframe = "cell")
exg <- list(build = "example", geometry = geo_cells)
geo_states <- list(wkt = I(c(sq(0, 0, 2), sq(0, 2, 2), sq(2, 0, 2))),
                   codes = I(c("N1", "N2", "S1")), crs = 4326, by = "state",
                   geoframe = "state")

# labels on the example: two variants at `country`, the geoframe's own name,
# one label at `state`
lab <- data.frame(geoframe = c("country", "country", "country", "state", "cell"),
                  region = c("N", "S", NA, "N1", "A3"),
                  label = c("North", "South", "Country", "North one", "Cell three"),
                  stringsAsFactors = FALSE)
lab_short <- data.frame(geoframe = c("country", "zone"), region = c("N", "ZB"),
                        label = c("Nth", "Zone B"), stringsAsFactors = FALSE)
exl <- exs(step("attach_labels_geoscale", lab),
           step("attach_labels_geoscale", lab_short, variant = "short"))

# leaves finer than the finest geoframe: the leaf column is named by `leaf=`
lt_fine <- data.frame(big = c("X", "X", "X", "Y", "Y"),
                      mid = c("m1", "m1", "m2", "m3", "m3"),
                      id = c("p1", "p2", "p3", "p4", "p5"),
                      w = c(1, 3, 2, 2, 2), stringsAsFactors = FALSE)
fine <- list(build = "leaftable", leaftable = lt_fine,
             args = list(geoframes = c("big", "mid"), leaf = "id", name = "fine"))

# ---- construction ------------------------------------------------------------- #

lt <- data.frame(c1 = c("X", "X", "Y", " "), c2 = c("a", "b", "c", "d"),
                 w = c(1, 2, 3, 4), stringsAsFactors = FALSE)
call("construct", "geoscale_example")
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"), name = "lt")
call("construct", "geoscale_from_leaftable", lt, c("c2", "c1"), name = "inv")
call("construct", "geoscale_from_leaftable", lt, c("c2", "c1"), leaf = "c2",
     name = "inv")
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"), leaf = "c2",
     weights = character(), name = "nw")
call("construct", "geoscale_from_leaftable", lt, c("c1", "zz"))
call("construct", "geoscale_from_leaftable", rbind(lt, lt[1, ]), c("c1", "c2"))
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"), leaf = "zz")
call("construct", "geoscale_from_leaftable", lt_fine, c("big", "mid"), leaf = "id",
     name = "fine")
call("construct", "geoscale_from_leaftable", lt_fine, c("big", "mid"))
call("construct", "geoscale_from_leaftable", lt_fine[c(4, 1, 5, 3, 2), ],
     c("big", "mid", "id"), name = "sorted")
call("construct", "geoscale_from_leaftable", lt_fine[c(4, 1, 5, 3, 2), ],
     c("big", "mid", "id"), name = "given", row_order = "given")
call("construct", "geoscale_from_leaftable",
     data.frame(country = c("N", "N", "S"), region = c("r1", "r2", "r3"),
                pop = c(1, 2, 3)), c("country", "region"), name = "reg")
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"), name = "lab",
     labels = data.frame(geoframe = c("c1", "c2"), region = c("X", "a"),
                         label = c("Ex", "Ay")), hidden = "c2")
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"),
     labels = data.frame(geoframe = "c1", unit = "X", label = "Ex"))
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"),
     hidden = c("c1", "c2"))
x1 <- data.frame(state = c("N1", "N1", "N2", "S1"), cell = c("a1", "a2", "a3", "a4"))
x2 <- data.frame(country = c("N", "N", "S"), state = c("N1", "N2", "S1"))
x3 <- data.frame(zone = c("Z1", "Z1", "Z2", "Z2"), cell = c("a1", "a3", "a2", "a4"))
wts <- data.frame(cell = c("a4", "a1", "a2", "a3"), km2 = c(4, 1, 2, 3))
call("construct", "geoscale_build", x1, x2,
     geoframes = c("country", "state", "cell"))
call("construct", "geoscale_build", x2, x1,
     geoframes = c("country", "state", "cell"), weights = wts, name = "built")
call("construct", "geoscale_build", x1, x3, x2,
     geoframes = c("country", "state", "zone", "cell"))
call("construct", "geoscale_build", x2, geoframes = c("country", "state", "cell"))
call("construct", "geoscale_build", x1, data.frame(zone = "Z9", country = "N"),
     geoframes = c("country", "zone", "state", "cell"))
call("construct", "geoscale_build", x1,
     data.frame(state = c("N1", "N1"), cell = c("a1", "a9")),
     data.frame(country = c("N", "N"), cell = c("a1", "a1")),
     geoframes = c("country", "state", "cell"))
call("construct", "geoscale_from_provider",
     data.frame(cont = c("E", "E", "A"), feature = c("f1", "f2", "f3"),
                pop = c(1, 2, 3)), geoframes = c("cont", "feature"),
     weights = c("pop", "gdp"), name = "prov")

# ---- navigation, filter, prune, zoom ----------------------------------------- #

for (p in list(c("country", "state"), c("state", "zone"), c("zone", "cell"),
               c("country", "cell"))) {
  call("navigate", "geoscale_nests", ex, p[1], p[2])
  call("navigate", "geoscale_family", ex, p[1], p[2], ordered = FALSE)
}
call("navigate", "geoscale_family", ex, ordered = FALSE)
call("navigate", "geoscale_ancestry", ex)
call("navigate", "geoscale_children", ex, "country", "N")
call("navigate", "geoscale_children", ex, "country", "N", target = "zone")
call("navigate", "geoscale_parents", ex, "cell", "A5")
call("navigate", "geoscale_descendants", ex, "country", "S")
call("navigate", "geoscale_ancestors", ex, "cell", c("A3", "A5"))
call("navigate", "geoscale_children", ex, "cell", "A1")
call("navigate", "geoscale_children", ex, "planet", "A1")
call("navigate", "geoscale_children", fine, "big", "X")
call("navigate", "geoscale_share", ex, "state", weight = "pop", within = "country")
call("navigate", "geoscale_share", ex, "zone")
call("navigate", "geoscale_regions", ex, "zone")
call("navigate", "geoscale_regions", ex)
call("navigate", "geoscale_regions", fine)
call("navigate", "geoscale_rank", ex, c("zone", "country", "nope"))
call("navigate", "geoscale_coverage", exs(step("filter_geoscale", "state", "N1")))
call("navigate", "geoscale_weights", ex)
call("navigate", "geoscale_geoframes", ex)
call("navigate", "geoscale_geoframes", ex, finest = TRUE)
call("navigate", "filter_geoscale", ex, "country", "N")
call("navigate", "filter_geoscale", ex, "zone", c("ZB", "ZC"))
call("navigate", "filter_geoscale", exs(step("filter_geoscale", "country", "N")),
     "state", "N2")
call("navigate", "filter_geoscale", ex, "cell", "ROW")
call("navigate", "filter_geoscale", ex, "cell", "ROW", drop_empty_geoframes = TRUE)
call("navigate", "filter_geoscale", exg, "state", "N1")
call("navigate", "filter_geoscale", fine, "mid", "m1")
for (g in c("country", "state", "zone", "cell")) {
  call("navigate", "prune_geoscale", ex, g)
}
call("navigate", "prune_geoscale", exg, "state")
call("navigate", "prune_geoscale", exg, "country", keep_geometry = FALSE)
call("navigate", "prune_geoscale", fine, "mid")
call("navigate", "prune_geoscale", fine, "big")
call("navigate", "zoom_geoscale", ex, "A3")
call("navigate", "zoom_geoscale", ex, "A3", geoframes = c("country", "state"))
call("navigate", "zoom_geoscale", ex, c("A1", "A5"), geoframes = c("country", "state"),
     name = "ring", label_rest = "rest-%s")
call("navigate", "zoom_geoscale", ex, "N1")
call("navigate", "zoom_geoscale", ex, "A1", geoframes = "cell")
call("navigate", "zoom_geoscale", exg, "A3", geoframes = c("country", "state"))

# ---- recast, maps, joins -------------------------------------------------------- #

d_cells <- data.frame(cell = c("A1", "A2", "A3", "A4", "A5", "A6"),
                      cap = c(1, 2, 3, 4, 5, 6), eff = c(.5, .6, .7, .8, .9, 1))
d_ids <- rbind(cbind(d_cells, id = "x"), cbind(transform(d_cells, cap = cap * 2),
                                               id = "y"))
d_country <- data.frame(country = c("N", "S"), cap = c(10, 20), eff = c(.4, .6))
for (r in c("sum", "mean", "weighted_mean", "copy", "sd")) {
  call("recast", "recast_geoscale", d_cells, ex, target = "country", rule = r,
       values = c("cap", "eff"))
  call("recast", "recast_geoscale", d_country, ex, target = "zone", rule = r)
  call("recast", "recast_to_geoleaves", d_country, ex, rule = r, ordered = FALSE)
  call("recast", "recast_from_geoleaves", d_ids, ex, target = "zone", rule = r,
       values = c("cap", "eff"))
  call("recast", "recast_from_geoleaves",
       data.frame(place = c("A1", "A2", "A3", "ROW"), v = c(1, NA, 3, 9)), ex,
       target = "state", rule = r, key = "place", na_rm = TRUE, na_action = "keep")
}
call("recast", "recast_geoscale", d_cells, ex, target = "country",
     rule = list(cap = "sum", eff = "weighted_mean"), weight = list(eff = "pop"))
call("recast", "recast_geoscale", d_cells, ex, target = "country", rule = "share",
     values = "cap")
call("recast", "recast_geoscale", d_country, ex, target = list(build = "leaftable",
     leaftable = data.frame(big = c("X", "X", "Y"), region = c("A1", "A3", "A5"),
                            km2 = c(1, 1, 1)),
     args = list(geoframes = c("big", "region"), name = "other")), rule = "sum")
call("recast", "recast_geoscale", data.frame(big = c("X", "Y"), v = c(12, 8)), fine,
     target = "mid", rule = "sum")
call("recast", "recast_geoscale", data.frame(id = c("p1", "p2", "p5"), v = c(1, 2, 4)),
     fine, source = "id", target = "big", rule = "sum")
call("recast", "recast_to_geoleaves", d_country, ex, rule = "sum", weight = "pop",
     ordered = FALSE)
call("recast", "recast_to_geoleaves", data.frame(state = c("N1", "Q9"), v = c(4, 1)),
     ex, rule = "sum", attach_weight = FALSE, ordered = FALSE)
call("recast", "recast_to_geoleaves", cbind(d_country, weight = 1), ex, rule = "sum")
call("recast", "recast_to_geoleaves",
     data.frame(state = c("N1", "N2"), cell = c("a", "b"), v = c(4, 1)), ex,
     source = "state", rule = "sum")
call("recast", "recast_to_geoleaves", d_cells, ex, rule = "sum", values = "cap",
     ordered = FALSE)
call("recast", "recast_to_geoleaves", data.frame(big = c("X", "Y"), v = c(12, 8)), fine,
     rule = "sum", ordered = FALSE)
call("recast", "recast_from_geoleaves",
     data.frame(id = c("p1", "p2", "p3", "p4"), v = c(1, 2, 3, 4)), fine,
     target = "mid", rule = "weighted_mean")
call("recast", "recast_from_geoleaves",
     data.frame(cell = c("A1", "A5", "ZZ"), v = c(1, 2, 3), w = c(1, 3, 1)), ex,
     target = "country", rule = "weighted_mean", data_weight = "w")
call("recast", "recast_from_geoleaves",
     data.frame(cell = c("A1", "A2", "A5"), v = c(1, 2, 3)), ex,
     target = "country", rule = "weighted_mean", weight = "pop")
call("recast", "recast_from_geoleaves",
     data.frame(cell = c("A1", "A2", "A5"), v = c(1, 2, 3)), ex,
     target = "country", rule = "weighted_mean", data_weight = "nope")
call("recast", "recast_from_geoleaves", data.frame(cell = "ZZ", v = 1), ex,
     target = "country", rule = "sum")
call("recast", "recast_from_geoleaves", data.frame(region = "A1", v = 1), ex,
     target = "country", rule = "sum")
call("recast", "recast_from_geoleaves",
     data.frame(cell = c("A1", "ROW"), v = c(1, 2)), ex, target = "country",
     rule = "sum", na_action = "error")
call("recast", "recast_from_geoleaves",
     data.frame(cell = c("A1", "ROW"), v = c(1, 2)), ex, target = "country",
     rule = "sum")
pairs <- data.frame(src = c("A1", "A3", "A5", "A2", "A6", "QQ"),
                    dst = c("A5", "A1", "A6", "A6", "A1", "A1"),
                    flow = c(1, 2, 3, 4, 5, 6), yr = c(1, 1, 1, 2, 2, 2))
call("recast", "recast_pairs", pairs, ex, target = "country", rule = "sum",
     values = "flow")
call("recast", "recast_pairs", pairs, ex, target = "state", rule = "mean",
     values = "flow", directed = FALSE)
call("recast", "recast_pairs", pairs, ex, target = "state", rule = "sum",
     values = "flow", drop_internal = FALSE)
call("recast", "recast_pairs", pairs, ex, target = "cell", source = "country",
     rule = "sum", values = "flow")
call("recast", "recast_pairs", cbind(pairs, cw = c(1, 2, 3, 4, 5, 6)), ex,
     target = "country", rule = "weighted_mean", values = "flow", data_weight = "cw")
for (p in list(c("cell", "country"), c("state", "zone"), c("country", "cell"))) {
  call("recast", "geoscale_map", ex, p[1], p[2], ordered = FALSE)
  call("recast", "geoscale_map", ex, p[1], p[2], weight = "pop", ordered = FALSE)
}
call("recast", "geoscale_map", fine, "big", "id", ordered = FALSE)
call("recast", "geoscale_map_between", ex, list(build = "leaftable",
     leaftable = data.frame(big = c("X", "X", "Y"), region = c("A1", "A3", "A9")),
     args = list(geoframes = c("big", "region"), name = "other")), ordered = FALSE)
d_join <- data.frame(state = c("S1", "N1", "N2", "N1"), v = c(1, 2, 3, 4))
call("recast", "join_geoscale", d_join, ex)
call("recast", "join_geoscale", d_join, ex, geoframes = TRUE, meta = TRUE,
     as_factor = FALSE)
call("recast", "join_geoscale", d_join, ex, geoframes = "country", weight = "pop",
     meta = TRUE, as_factor = FALSE)
call("recast", "join_geoscale", data.frame(zone = c("ZB", "N1")), ex,
     geoframes = "state", as_factor = FALSE)
call("recast", "join_geoscale", data.frame(country = "N", state = "N1"), ex)
call("recast", "register_geoscale_rule", "", "sum")
call("recast", "register_geoscale_rule", "cap", "nope")
call("recast", "geoscale_rule_action")
call("recast", "geoscale_rule_action", c("copy", "sum", "sd"))
call("recast", "geoscale_rule_action", c("sum", "nope"))

# ---- labels ------------------------------------------------------------------- #

call("labels", "attach_labels_geoscale", ex, lab)
call("labels", "attach_labels_geoscale", ex, lab_short, variant = "short")
call("labels", "attach_labels_geoscale", exl, lab_short, variant = "short")
call("labels", "attach_labels_geoscale", exl,
     data.frame(geoframe = "country", region = "N", label = "NORTH"),
     overwrite = TRUE, default = "short")
call("labels", "attach_labels_geoscale", exl, lab_short, variant = "long",
     default = "nope")
call("labels", "attach_labels_geoscale", ex,
     data.frame(frame = "country", member = "S", variant = "v", label = "Sth"))
call("labels", "attach_labels_geoscale", ex,
     data.frame(geoframe = "country", unit = "S", label = "Sth"))
call("labels", "attach_labels_geoscale", ex,
     data.frame(geoframe = "country", label = "Sth"))
call("labels", "attach_labels_geoscale", ex,
     data.frame(geoframe = c("planet", "country"), region = c("E", "Q"),
                label = c("Earth", "Queue")))
call("labels", "attach_labels_geoscale", ex,
     data.frame(geoframe = "country", region = "N", variant = "a", label = "x"),
     variant = "b")
call("labels", "geoscale_labels", ex)
call("labels", "geoscale_labels", exl)
call("labels", "geoscale_labels", exl, "country")
call("labels", "geoscale_labels", exl, variant = "short")
call("labels", "geoscale_labels", exl, "planet")
call("labels", "geoscale_label", exl, c("N", "S", "zz", NA), "country")
call("labels", "geoscale_label", exl, c("N", "S", NA), "country", variant = "short")
call("labels", "geoscale_label", exl, "ZB", "zone")
call("labels", "geoscale_label", ex, c("N1", NA), "state")
call("labels", "geoscale_label", exl, "N", "country", variant = "nope")
call("labels", "filter_geoscale", exl, "country", "S")
call("labels", "prune_geoscale", exl, "state")
call("labels", "zoom_geoscale", exl, "A3", geoframes = c("country", "state"))

# ---- identity, parts, weights, hidden geoframes ------------------------------ #

exh <- exs(step("hide_geoframes_geoscale", c("zone", "cell")))
call("identity", "geoscale_id", ex)
call("identity", "geoscale_id", exl)
call("identity", "geoscale_id", exs(step("filter_geoscale", "country", "N")))
call("identity", "geoscale_id", fine)
call("identity", "geoscale_leaf_column", ex)
call("identity", "geoscale_leaf_column", fine)
call("identity", "geoscale_leaf_column", exs(step("prune_geoscale", "state")))
call("identity", "geoscale_tree", ex)
call("identity", "geoscale_tree", fine)
call("identity", "geoscale_tree", exh)
call("identity", "geoscale_tree", list(build = "example", geometry = geo_cells,
                                       steps = exl$steps))
call("identity", "geoscale_add_weight", ex,
     gdp = nv(A1 = 1, A2 = 2, A3 = 3, A4 = 4, A5 = 5, A6 = 6, ROW = 7))
call("identity", "geoscale_add_weight", ex,
     gdp = nv(ROW = 7, A6 = 6, A5 = 5, A4 = 4, A3 = 3, A2 = 2, A1 = 1), one = 1,
     default = "gdp")
call("identity", "geoscale_add_weight", ex, seq = c(7, 6, 5, 4, 3, 2, 1))
call("identity", "geoscale_add_weight", ex,
     data.frame(cell = leaves, gdp = c(1, 2, 3, 4, 5, 6, 7), n = c(1, 1, 1, 1, 1, 1, 2)))
call("identity", "geoscale_add_weight", ex, gdp = nv(A1 = 1, A2 = 2))
call("identity", "geoscale_add_weight", ex, pop = 1)
call("identity", "geoscale_add_weight", ex, pop = 1, overwrite = TRUE)
call("identity", "geoscale_add_weight", ex, state = 1)
call("identity", "geoscale_add_weight", ex, gdp = c(1, 2))
call("identity", "geoscale_add_weight", ex, gdp = -1)
call("identity", "geoscale_add_weight", ex, gdp = 0)
call("identity", "geoscale_add_weight", ex, gdp = 1, default = "nope")
call("identity", "geoscale_add_weight", ex, data.frame(state = "N1", gdp = 1))
call("identity", "geoscale_add_weight", ex)
call("identity", "hide_geoframes_geoscale", ex, "zone")
call("identity", "hide_geoframes_geoscale", exh, "state")
call("identity", "hide_geoframes_geoscale", ex, "planet")
call("identity", "hide_geoframes_geoscale", ex, c("country", "state", "zone", "cell"))
call("identity", "show_geoframes_geoscale", exh)
call("identity", "show_geoframes_geoscale", exh, "cell")
call("identity", "show_geoframes_geoscale", exh, "planet")
call("identity", "geoscale_geoframes", exh, visible = TRUE)
call("identity", "geoscale_geoframes", exh, visible = FALSE)
call("identity", "geoscale_geoframes", exh, finest = TRUE, visible = TRUE)
call("identity", "filter_geoscale", exh, "cell", "ROW", drop_empty_geoframes = TRUE)
call("identity", "prune_geoscale", exh, "zone")
call("identity", "zoom_geoscale", exh, "A3", geoframes = c("country", "state"))

# ---- geometry ------------------------------------------------------------------- #

call("geometry", "attach_geometry_geoscale", ex,
     sf::st_sf(cell = leaves[c(3, 1, 2)], geometry = sf::st_as_sfc(cells[c(3, 1, 2)],
                                                                 crs = 4326)))
call("geometry", "attach_geometry_geoscale", ex, sf::st_as_sfc(cells, crs = 4326))
call("geometry", "attach_geometry_geoscale", ex, sf::st_as_sfc(cells[1:3], crs = 4326))
permuted <- list(build = "leaftable", leaftable = lt_fine[c(4, 1, 5, 3, 2), ],
                 args = list(geoframes = c("big", "mid", "id"), name = "sorted"))
call("geometry", "attach_geometry_geoscale", permuted,
     sf::st_as_sfc(cells[1:5], crs = 4326))
call("geometry", "attach_geometry_geoscale", permuted,
     sf::st_as_sfc(cells[1:5], crs = 4326), positional = TRUE)
call("geometry", "attach_geometry_geoscale", ex,
     sf::st_sf(code = leaves, geometry = sf::st_as_sfc(cells, crs = 4326)))
call("geometry", "attach_geometry_geoscale", ex,
     sf::st_sf(cell = c("q1", "q2"), geometry = sf::st_as_sfc(cells[1:2], crs = 4326)))
call("geometry", "geoscale_geometry", exg, "state")
call("geometry", "geoscale_geometry", exg, "zone")
call("geometry", "geoscale_geometry", exg, "country")
call("geometry", "geoscale_geometry", exg)
call("geometry", "geoscale_geometry", ex, "state")
call("geometry", "geoscale_geometry",
     list(build = "example", geometry = geo_states), "country")
call("geometry", "add_area_geoscale", exg)
call("geometry", "add_area_geoscale", exg, name = "area", crs = "EPSG:6933")
call("geometry", "coords_to_region",
     data.frame(lon = c(0.5, 1.5, 2.5, 50, 11, 1), lat = c(0.5, 1.5, 0.5, 50, 11, 1)),
     exg, "state")
call("geometry", "coords_to_region",
     data.frame(x = c(0.2, 2.2), y = c(0.2, 1.8)), exg, coords = c("x", "y"))

for (topic in names(cases)) {
  jsonlite::write_json(
    list(generated_by = paste("geoscales", packageVersion("geoscales"), "+",
                              "nestedscales", packageVersion("nestedscales"), "+ sf",
                              packageVersion("sf")),
         cases = cases[[topic]]),
    file.path(out_dir, paste0(topic, ".json")),
    auto_unbox = TRUE, digits = NA, null = "null", na = "null", pretty = FALSE)
  cat("wrote", file.path(out_dir, paste0(topic, ".json")), length(cases[[topic]]),
      "cases\n")
}
