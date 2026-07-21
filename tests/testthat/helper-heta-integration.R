skip_if_heta_integration_disabled <- function() {
  enabled <- identical(
    tolower(Sys.getenv("DYNMSR_RUN_HETA_INTEGRATION", unset = "false")),
    "true"
  )

  if (!enabled) {
    skip("Set DYNMSR_RUN_HETA_INTEGRATION=true to run Heta integration tests.")
  }
}
