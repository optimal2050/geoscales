# =============================================================================
# Load hooks
# =============================================================================

.onLoad <- function(libname, pkgname) {
  # Required for S7 methods on generics owned by other packages (here base's
  # `print`/`format`). An S7 object is NOT S4-backed -- `isS4()` on a GeoScale
  # is FALSE and the object carries a plain character class attribute -- so the
  # methods S7 defines against another package's generic are not visible until
  # they are registered here. Without this call, `print(gs)` falls through to
  # the default and dumps the raw properties.
  S7::methods_register()

  # `S7::method(print, ...) <-` leaves a local `print` binding in this
  # namespace, so the NAMESPACE `S3method(print, summary_GeoScale)` entry
  # registers against that shim instead of base's print — invisible to
  # dispatch from user code. Register the plain-S3 class explicitly.
  registerS3method("print", "summary_GeoScale", print.summary_GeoScale,
                   envir = baseenv())

  .register_builtin_providers()

  # ggplot2 is in Suggests, so its `autoplot` generic cannot be imported at
  # build time. Register the method only when ggplot2 is actually present.
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    for (cls in c("GeoScale", "geoscales::GeoScale")) {
      try(
        registerS3method("autoplot", cls, autoplot.GeoScale,
                         envir = asNamespace("ggplot2")),
        silent = TRUE
      )
      try(
        registerS3method("fortify", cls, fortify.GeoScale,
                         envir = asNamespace("ggplot2")),
        silent = TRUE
      )
    }
  }
  invisible()
}
