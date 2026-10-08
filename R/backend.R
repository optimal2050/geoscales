# =============================================================================
# Backend dispatch -- delegated to nestedscales
# =============================================================================
# data.frame / tibble / data.table / dtplyr / arrow in, the same class out,
# lazy inputs staying lazy unless collected. The implementation lives in
# `nestedscales`, which exports these for exactly this. They are direct
# bindings rather than wrapper calls: they sit in the per-row path of every
# conversion, so an extra frame is not free.
# =============================================================================

# dtplyr generates data.table syntax that is evaluated with THIS package as
# the calling namespace; without this flag data.table's cedta() check makes
# `[.data.table` fall through to `[.data.frame` and the joins break.
.datatable.aware <- TRUE

# Internal working columns referenced as bare symbols inside dplyr verbs
# (bare symbols, not `.data[[...]]`, because dtplyr and arrow mistranslate
# pronoun subsetting) -- declared so R CMD check knows they are data masks.
utils::globalVariables(c(".gs_to", ".gs_f", ".gs_n_from", ".gs_n_overlap",
                         ".gs_w", ".gs_w_from", ".gs_label", "weight"))

.gs_backend <- nestedscales::.ms_backend
.gs_is_lazy <- nestedscales::.ms_is_lazy
.gs_lazy    <- nestedscales::.ms_lazy
.gs_schema  <- nestedscales::.ms_schema
.gs_pull    <- nestedscales::.ms_pull
.gs_restore <- nestedscales::.ms_restore
