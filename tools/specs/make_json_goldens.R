# =========================================================================== #
# make_json_goldens.R -- broad cross-language goldens for the Python port.
#
# Usage (from the package root):
#   Rscript tools/specs/make_json_goldens.R [path/to/nestedscales]
#
# Loads geoscales from SOURCE on top of nestedscales loaded from SOURCE
# (default ../nestedscales; its R code is the version submitted to CRAN).
# Writes specs/json/<topic>.json: each case is a call and its result, with
# every warning and error message. Geometry is synthetic (WKT squares), so
# no boundary data is needed; geometric results are compared as type, area
# and bounds.
# =========================================================================== #

args <- commandArgs(trailingOnly = TRUE)
ns_path <- if (length(args)) args[[1]] else file.path("..", "nestedscales")
suppressMessages({
  pkgload::load_all(ns_path, quiet = TRUE, export_all = FALSE)
  pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
  library(sf)
})
sf::sf_use_s2(FALSE)
out_dir <- file.path("specs", "json")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

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
  for (st in spec$steps) x <- do.call(st$fn, c(list(x), st$args))
  x
}
describe <- function(x) {
  m <- S7::prop(x, "meta")
  list(frames = vec(geoscale_geoframes(x)),
       members = lapply(S7::prop(x, "members"), vec),
       name = m[["name"]], parent_name = m[["parent_name"]],
       weights = vec(m[["weights"]] %||% character()),
       default_weight = m[["default_weight"]],
       coverage = if (!is.null(m[["coverage"]])) as.list(m[["coverage"]]),
       parent_totals = if (!is.null(m[["parent_totals"]])) as.list(m[["parent_totals"]]),
       crs = m[["crs"]],
       leaftable = rows(geoscale_leaftable(x)),
       geometry = geom_info(S7::prop(x, "geometry")))
}
encode <- function(v) {
  if (S7::S7_inherits(v, GeoScale)) return(list(kind = "geoscale", value = describe(v)))
  if (inherits(v, "sf")) {
    return(list(kind = "sf", value = rows(v),
                geometry = geom_info(sf::st_geometry(v))))
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
is_spec <- function(a) is.list(a) && !is.null(a$build)
enc_arg <- function(a) {
  if (is_spec(a)) return(list(scale = a))
  if (inherits(a, "sf")) {
    g <- sf::st_geometry(a)
    return(list(sf = list(table = tab(sf::st_drop_geometry(a)),
                          wkt = I(sf::st_as_text(g)),
                          crs = sf::st_crs(g)$input)))
  }
  if (is.data.frame(a)) return(list(table = tab(a)))
  a
}
dec_arg <- function(a) if (is_spec(a)) build_gs(a) else a
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

# synthetic geometry: one square cell per atom, ROW far away
sq <- function(x0, y0, d = 1) {
  sprintf("POLYGON ((%g %g, %g %g, %g %g, %g %g, %g %g))", x0, y0, x0 + d, y0,
          x0 + d, y0 + d, x0, y0 + d, x0, y0)
}
atoms <- c("A1", "A2", "A3", "A4", "A5", "A6", "ROW")
cells <- c(sq(0, 0), sq(1, 0), sq(0, 1), sq(1, 1), sq(2, 0), sq(2, 1), sq(10, 10, 2))
geo_atoms <- list(wkt = I(cells), codes = I(atoms), crs = 4326, by = "atom",
                  geoframe = "atom")
exg <- list(build = "example", geometry = geo_atoms)
geo_states <- list(wkt = I(c(sq(0, 0, 2), sq(0, 2, 2), sq(2, 0, 2))),
                   codes = I(c("N1", "N2", "S1")), crs = 4326, by = "state",
                   geoframe = "state")

# ---- construction ------------------------------------------------------------- #

lt <- data.frame(c1 = c("X", "X", "Y", " "), c2 = c("a", "b", "c", "d"),
                 w = c(1, 2, 3, 4), stringsAsFactors = FALSE)
call("construct", "geoscale_example")
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"), name = "lt")
call("construct", "geoscale_from_leaftable", lt, c("c2", "c1"), name = "inv")
call("construct", "geoscale_from_leaftable", lt, c("c1", "c2"), key = "c2",
     weights = character(), name = "nw")
call("construct", "geoscale_from_leaftable", lt, c("c1", "zz"))
call("construct", "geoscale_from_leaftable", rbind(lt, lt[1, ]), c("c1", "c2"))
x1 <- data.frame(state = c("N1", "N1", "N2", "S1"), atom = c("a1", "a2", "a3", "a4"))
x2 <- data.frame(country = c("N", "N", "S"), state = c("N1", "N2", "S1"))
x3 <- data.frame(zone = c("Z1", "Z1", "Z2", "Z2"), atom = c("a1", "a3", "a2", "a4"))
wts <- data.frame(atom = c("a4", "a1", "a2", "a3"), km2 = c(4, 1, 2, 3))
call("construct", "geoscale_build", x1, x2,
     geoframes = c("country", "state", "atom"))
call("construct", "geoscale_build", x2, x1,
     geoframes = c("country", "state", "atom"), weights = wts, name = "built")
call("construct", "geoscale_build", x1, x3, x2,
     geoframes = c("country", "state", "zone", "atom"))
call("construct", "geoscale_build", x2, geoframes = c("country", "state", "atom"))
call("construct", "geoscale_build", x1, data.frame(zone = "Z9", country = "N"),
     geoframes = c("country", "zone", "state", "atom"))
call("construct", "geoscale_build", x1,
     data.frame(state = c("N1", "N1"), atom = c("a1", "a9")),
     data.frame(country = c("N", "N"), atom = c("a1", "a1")),
     geoframes = c("country", "state", "atom"))
call("construct", "geoscale_from_provider",
     data.frame(cont = c("E", "E", "A"), feature = c("f1", "f2", "f3"),
                pop = c(1, 2, 3)), geoframes = c("cont", "feature"),
     weights = c("pop", "gdp"), name = "prov")

# ---- navigation, filter, prune, zoom ----------------------------------------- #

for (p in list(c("country", "state"), c("state", "zone"), c("zone", "atom"),
               c("country", "atom"))) {
  call("navigate", "geoscale_nests", ex, p[1], p[2])
  call("navigate", "geoscale_family", ex, p[1], p[2], ordered = FALSE)
}
call("navigate", "geoscale_family", ex, ordered = FALSE)
call("navigate", "geoscale_ancestry", ex, ordered = FALSE)
call("navigate", "geoscale_children", ex, "country", "N")
call("navigate", "geoscale_children", ex, "country", "N", target = "zone")
call("navigate", "geoscale_parents", ex, "atom", "A5")
call("navigate", "geoscale_descendants", ex, "country", "S")
call("navigate", "geoscale_ancestors", ex, "atom", c("A3", "A5"))
call("navigate", "geoscale_children", ex, "atom", "A1")
call("navigate", "geoscale_children", ex, "planet", "A1")
call("navigate", "geoscale_share", ex, "state", weight = "pop", within = "country")
call("navigate", "geoscale_share", ex, "zone")
call("navigate", "geoscale_regions", ex, "zone")
call("navigate", "geoscale_rank", ex, c("zone", "country", "nope"))
call("navigate", "geoscale_coverage", exs(step("filter_geoscale", "state", "N1")))
call("navigate", "filter_geoscale", ex, "country", "N")
call("navigate", "filter_geoscale", ex, "zone", c("ZB", "ZC"))
call("navigate", "filter_geoscale", exs(step("filter_geoscale", "country", "N")),
     "state", "N2")
call("navigate", "filter_geoscale", ex, "atom", "ROW")
call("navigate", "filter_geoscale", ex, "atom", "ROW", drop_empty_geoframes = TRUE)
call("navigate", "filter_geoscale", exg, "state", "N1")
for (g in c("country", "state", "zone", "atom")) {
  call("navigate", "prune_geoscale", ex, g)
}
call("navigate", "prune_geoscale", exg, "state")
call("navigate", "prune_geoscale", exg, "country", keep_geometry = FALSE)
call("navigate", "zoom_geoscale", ex, "A3")
call("navigate", "zoom_geoscale", ex, "A3", geoframes = c("country", "state"))
call("navigate", "zoom_geoscale", ex, c("A1", "A5"), geoframes = c("country", "state"),
     name = "ring", label_rest = "rest-%s")
call("navigate", "zoom_geoscale", ex, "N1")
call("navigate", "zoom_geoscale", ex, "A1", geoframes = "atom")

# ---- recast, maps, joins -------------------------------------------------------- #

d_atoms <- data.frame(atom = c("A1", "A2", "A3", "A4", "A5", "A6"),
                      cap = c(1, 2, 3, 4, 5, 6), eff = c(.5, .6, .7, .8, .9, 1))
d_ids <- rbind(cbind(d_atoms, id = "x"), cbind(transform(d_atoms, cap = cap * 2),
                                               id = "y"))
d_country <- data.frame(country = c("N", "S"), cap = c(10, 20), eff = c(.4, .6))
for (r in c("sum", "mean", "weighted_mean", "copy", "sd")) {
  call("recast", "recast_geoscale", d_atoms, ex, target = "country", rule = r,
       values = c("cap", "eff"))
  call("recast", "recast_geoscale", d_country, ex, target = "zone", rule = r)
  call("recast", "recast_to_geoatoms", d_country, ex, rule = r, ordered = FALSE)
  call("recast", "recast_from_geoatoms", d_ids, ex, target = "zone", rule = r,
       values = c("cap", "eff"), key = "atom")
  call("recast", "recast_from_geoatoms",
       data.frame(region = c("A1", "A2", "A3", "ROW"), v = c(1, NA, 3, 9)), ex,
       target = "state", rule = r, na_rm = TRUE, na_action = "keep")
}
call("recast", "recast_geoscale", d_atoms, ex, target = "country",
     rule = list(cap = "sum", eff = "weighted_mean"), weight = list(eff = "pop"))
call("recast", "recast_geoscale", d_atoms, ex, target = "country", rule = "share",
     values = "cap")
call("recast", "recast_geoscale", d_country, ex, target = list(build = "leaftable",
     leaftable = data.frame(big = c("X", "X", "Y"), region = c("A1", "A3", "A5"),
                            km2 = c(1, 1, 1)),
     args = list(geoframes = c("big", "region"), name = "other")), rule = "sum")
call("recast", "recast_to_geoatoms", d_country, ex, rule = "sum", weight = "pop",
     ordered = FALSE)
call("recast", "recast_to_geoatoms", data.frame(state = c("N1", "Q9"), v = c(4, 1)),
     ex, rule = "sum", attach_weight = FALSE, ordered = FALSE)
call("recast", "recast_to_geoatoms", cbind(d_country, weight = 1), ex, rule = "sum")
call("recast", "recast_from_geoatoms",
     data.frame(region = c("A1", "A5", "ZZ"), v = c(1, 2, 3), w = c(1, 3, 1)), ex,
     target = "country", rule = "weighted_mean", weight = "w")
call("recast", "recast_from_geoatoms", data.frame(region = "ZZ", v = 1), ex,
     target = "country", rule = "sum")
call("recast", "recast_from_geoatoms",
     data.frame(region = c("A1", "ROW"), v = c(1, 2)), ex, target = "country",
     rule = "sum", na_action = "error")
pairs <- data.frame(src = c("A1", "A3", "A5", "A2", "A6", "QQ"),
                    dst = c("A5", "A1", "A6", "A6", "A1", "A1"),
                    flow = c(1, 2, 3, 4, 5, 6), yr = c(1, 1, 1, 2, 2, 2))
call("recast", "recast_pairs", pairs, ex, target = "country", rule = "sum",
     values = "flow")
call("recast", "recast_pairs", pairs, ex, target = "state", rule = "mean",
     values = "flow", directed = FALSE)
call("recast", "recast_pairs", pairs, ex, target = "state", rule = "sum",
     values = "flow", drop_internal = FALSE)
call("recast", "recast_pairs", pairs, ex, target = "atom", source = "country",
     rule = "sum", values = "flow")
for (p in list(c("atom", "country"), c("state", "zone"), c("country", "atom"))) {
  call("recast", "geoscale_map", ex, p[1], p[2], ordered = FALSE)
  call("recast", "geoscale_map", ex, p[1], p[2], weight = "pop", ordered = FALSE)
}
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

# ---- geometry ------------------------------------------------------------------- #

call("geometry", "attach_geometry_geoscale", ex,
     sf::st_sf(atom = atoms[c(3, 1, 2)], geometry = sf::st_as_sfc(cells[c(3, 1, 2)],
                                                                crs = 4326)))
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
