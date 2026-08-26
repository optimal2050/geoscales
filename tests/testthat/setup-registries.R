# Registry hygiene for the whole suite: start clean, end clean, so no test
# depends on what another file registered (rules / maps). Individual tests
# still register-and-clear locally where the registry IS the thing under
# test. (The provider registry has no clear_* -- tests register uniquely
# named providers; there is deliberately no conversion registry in space:
# the geoscale_map registry plays that override role.)
clear_geoscale_rules()
clear_geoscale_maps()
withr::defer(
  {
    clear_geoscale_rules()
    clear_geoscale_maps()
  },
  teardown_env()
)
