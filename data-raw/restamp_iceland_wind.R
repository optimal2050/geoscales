# Re-stamp data-raw/iceland_wind.rds after a class change in the shared core
# or in geoscales. An S7 object carries its class in its attributes, so the
# object saved under an earlier class definition stops being a Scale for the
# installed packages. Rebuilt from its OWN stored properties, so the content
# is unchanged and the Global Wind Atlas inputs are not needed.
#
#   source("data-raw/restamp_iceland_wind.R")   # after installing geoscales

library(sf) # geometry work needs sf loaded first
library(geoscales)

path <- "data-raw/iceland_wind.rds"
obj <- readRDS(path)
old <- obj$gs
m <- attr(old, "meta")

new <- geoscale_from_leaftable(
  attr(old, "leaftable"),
  geoframes = attr(old, "frames"),
  key = attr(old, "key"),
  members = attr(old, "members"),
  weights = m$weights,
  default_weight = m$default_weight,
  geometry = attr(old, "geometry"),
  name = m$name,
  desc = m$desc
)
S7::prop(new, "meta") <- m # every other meta field (crs, ...) as stored

stopifnot(
  nestedscales::scale_is(new),
  identical(attr(new, "leaftable"), attr(old, "leaftable")),
  identical(attr(new, "frames"), attr(old, "frames")),
  identical(attr(new, "members"), attr(old, "members")),
  identical(attr(new, "key"), attr(old, "key")),
  identical(attr(new, "meta"), m),
  identical(attr(new, "geometry"), attr(old, "geometry"))
)
obj$gs <- new
saveRDS(obj, path)
cat("re-stamped", path, "->", paste(class(new)[1:2], collapse = " / "), "\n")
