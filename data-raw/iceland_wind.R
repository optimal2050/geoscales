# Iceland onshore wind-speed Geoscale: country -> region -> cluster ----------
#
# Builds `data-raw/iceland_wind.rds` (a small, committed list with the
# Geoscale and the per-cluster mean wind speed) from the Global Wind Atlas
# 100 m mean-wind-speed raster. Used by README.Rmd and the "Get started"
# vignette; neither the raster nor this script ships with the package
# (`^data-raw$` is .Rbuildignored, `data-raw/gwa/` is gitignored).
#
# Clusters are per-region wind-resource classes cut at `int` m/s and made
# contiguous by `globalwindatlas::gwa_group_locations()` (threshold ->
# polygonize -> simplify -> buffer -> drop crumbs). Ranking: `c1` is the
# windiest class of its region. Offshore areas are DEFERRED -- they need a
# regionalization of the EEZ first, there is no offshore admin layer.
#
# Run manually from the package root:  source("data-raw/iceland_wind.R")
# Runtime: ~2-5 min after the one-time ~64 MB download.

library(sf)     # load sf BEFORE terra -- the reverse order segfaults R on
library(terra)  # this Windows setup (GDAL DLL clash)
library(dplyr)
library(geoscales)

dir.create("data-raw/gwa", showWarnings = FALSE, recursive = TRUE)

# 1. Global Wind Atlas raster --------------------------------------------------
# NOTE: pass `filename` explicitly. gwa_get_filename() applies
# gsub("-", "_") to the WHOLE path, so the default would mangle
# "data-raw/gwa/..." into the non-existing "data_raw/gwa/...".
tif <- globalwindatlas::gwa_get_wind_speed(
  "ISL", height = 100,
  filename = "data-raw/gwa/ISL_wind_speed_100.tif"
)

# 2. Onshore regions (Natural Earth states) ------------------------------------
# Natural Earth splits the capital region into two rows -- merge by gn_name
# (ASCII-transliterated region names double as readable region codes).
ne <- ne_source(geoframe = "states", country = "Iceland")
reg <- ne |>
  group_by(region = gn_name) |>
  summarise(.groups = "drop") |>
  st_make_valid()
# short codes for cluster ids; max() picks the ISO-standard IS-1 for the
# merged capital region (its Natural Earth halves carry IS-0 and IS-1)
iso <- ne |>
  st_drop_geometry() |>
  group_by(region = gn_name) |>
  summarise(iso = max(iso_3166_2), .groups = "drop")

# 3. Wind-resource classes per region ------------------------------------------
# Nested ">= threshold" polygons; int[1] = 0 keeps the full region as the
# base class so the clusters tile each region completely.
int <- c(0, 8, 10)  # m/s at 100 m; onshore median is 8.8, p90 is 11.0
grp_cache <- "data-raw/gwa/grp_cache.rds"    # the slow step -- cache it
if (file.exists(grp_cache)) {
  grp <- readRDS(grp_cache)
} else {
  grp <- globalwindatlas::gwa_group_locations(
    tif, gis_sf = reg, ID = "region", int = int,
    aggregate_tif = 2,        # 250 m -> 500 m cells: faster, smoother shapes
    plot_process = FALSE
  )
  saveRDS(grp, grp_cache)
}

# 4. Nested classes -> disjoint clusters, ranked by potential -------------------
# All of this runs in a projected CRS (ISN93 Lambert): s2 SEGFAULTS on the
# lat/lon differences here, planar GEOS is fine -- and simplification
# keeps the committed rds small (the raw shapes carry ~500k vertices).
# Class polygons take plain st_simplify (their edges never have to match
# a neighbour's). The REGION layer must not: st_simplify is not
# topology-aware, each side of a shared border simplifies differently,
# and the slivers survive the country dissolve as phantom border lines.
# rmapshaper::ms_simplify() simplifies every shared arc exactly once.
grp_sf <- st_as_sf(grp)[, c("region", "int")] |>
  st_transform(3057) |> st_make_valid() |>
  st_simplify(dTolerance = 300) |> st_make_valid()
reg_m <- reg |>
  st_transform(3057) |> st_make_valid() |>
  rmapshaper::ms_simplify(keep = 0.2, keep_shapes = TRUE) |>
  st_make_valid()
only_poly <- function(g) {                    # differences/clips can leave
  if (length(g) == 0) {                       # collections, stray lines, or
    return(st_sfc(st_polygon(), crs = st_crs(g)))   # nothing at all
  }
  g <- st_make_valid(g)
  i <- st_geometry_type(g) == "GEOMETRYCOLLECTION"
  if (any(i)) g[i] <- st_collection_extract(g[i], "POLYGON") |> st_union()
  g
}
# Carve each region so that every shared edge carries IDENTICAL
# coordinates in both of its neighbours (the honeycomb lesson: dissolves
# are only exact when shared edges match to the last bit). The windiest
# class is clipped to the region; each next class is differenced against
# the pieces cut so far; the LAST class is the region's remainder -- so
# atoms tile the region exactly, the region plane dissolves back to
# reg_m, and the country plane unions cleanly across ms_simplify's
# shared arcs. No independent clipping anywhere.
clusters <- lapply(seq_len(nrow(reg_m)), function(i) {
  rg  <- st_geometry(reg_m)[i]
  cls <- grp_sf[grp_sf$region == reg_m$region[i] & grp_sf$int > min(int), ]
  cls <- cls[order(-cls$int), ]
  out <- vector("list", nrow(cls) + 1L)
  acc <- NULL                                # union of the pieces so far
  for (k in seq_len(nrow(cls))) {
    pk <- only_poly(st_intersection(st_geometry(cls)[k], rg))
    if (!is.null(acc)) pk <- only_poly(st_difference(pk, acc))
    acc <- if (is.null(acc)) pk else only_poly(st_union(acc, pk))
    out[[k]] <- st_sf(region = reg_m$region[i], int = cls$int[k],
                      geometry = pk)
  }
  out[[nrow(cls) + 1L]] <- st_sf(region = reg_m$region[i], int = min(int),
                                 geometry = only_poly(st_difference(rg, acc)))
  do.call(rbind, out)
})
clusters <- do.call(rbind, clusters) |>
  filter(!st_is_empty(geometry),
         as.numeric(units::set_units(st_area(geometry), "km^2")) > 1) |>
  group_by(region) |>
  arrange(desc(int), .by_group = TRUE) |>
  mutate(rank = row_number()) |>            # c1 = windiest class of its region
  ungroup() |>
  left_join(iso, by = "region") |>
  mutate(cluster = paste0(iso, "_c", rank)) |>
  st_as_sf()

# 5. Mean wind speed per cluster (original 250 m raster) ------------------------
r <- rast(tif)
clusters$wind <- terra::extract(
  r, vect(st_transform(clusters, st_crs(r))),  # raster is lat/lon
  fun = mean, na.rm = TRUE, ID = FALSE
)[[1]]

# 6. Geoscale + pre-saved bundle ------------------------------------------------
atoms <- clusters |>                         # already in ISN93 Lambert
  mutate(km2 = as.numeric(units::set_units(st_area(geometry), "km^2")))

gs <- geoscale_from_leaftable(
  atoms |>
    st_drop_geometry() |>
    # "region" is reserved for coarser geoframes -- landshluti is what
    # these units are, and it matches the Iceland demos elsewhere
    transmute(country = "Iceland", landshluti = region, cluster, km2),
  geoframes = c("country", "landshluti", "cluster"),
  key = "cluster", name = "iceland_wind"
) |>
  attach_geometry_geoscale(atoms, by = "cluster", geoframe = "cluster")

wind <- atoms |>
  st_drop_geometry() |>
  select(cluster, wind) |>
  as.data.frame()

saveRDS(list(gs = gs, wind = wind), "data-raw/iceland_wind.rds")
cat("clusters:", nrow(wind), "| saved data-raw/iceland_wind.rds\n")
