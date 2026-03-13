# =============================================================================
# SCRIPT   : bridge.R
# STUDY    : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
# PURPOSE  : Demonstrates Altair SLC ↔ R bridge using the slcR package.
#            Runs SAS programs via SLC and reads results directly into R
#            without writing intermediate CSV files.
# NOTE     : Requires Altair SLC extension installed in Positron.
#            Falls back to reading CSVs if SLC is not available.
#            ALL DATA IS SYNTHETIC. For demonstration purposes only.
# =============================================================================

library(slcR)
library(tidyverse)

# Helper: check if SLC is available
slc_available <- function() {
  tryCatch({
    conn <- slc_init()
    slc_close(conn)
    TRUE
  }, error = function(e) FALSE)
}

# =============================================================================
# OPTION 1: ALTAIR SLC BRIDGE (live SAS ↔ R handoff)
# This is the "hero" demo path - data flows directly from SAS memory to R
# without any intermediate CSV files.
# =============================================================================

run_with_slc <- function() {
  message("Initializing Altair SLC connection...")
  conn <- slc_init()

  # --- Step 1: Run SDTM generation via SLC ---
  message("Submitting generate_sdtm.sas via Altair SLC...")
  sdtm_code <- paste(readLines("sas/generate_sdtm.sas"), collapse = "\n")
  slc_submit(sdtm_code, conn)

  # Capture SAS log for audit trail
  sdtm_log <- get_slc_log(conn, type = "log")
  message("SAS log (last 10 lines):")
  cat(paste(tail(sdtm_log, 10), collapse = "\n"), "\n")

  # --- Step 2: Read SDTM datasets directly from SLC workspace into R ---
  # KEY DEMO POINT: Data lives in SAS memory; no file I/O needed.
  # Positron Variables Pane will display these alongside R objects.
  message("Reading SDTM datasets from SLC workspace into R...")

  dm <- read_slc_data("sdtm_dm", conn)  # maps to libname sdtm, dataset dm
  ae <- read_slc_data("sdtm_ae", conn)
  ex <- read_slc_data("sdtm_ex", conn)
  ds <- read_slc_data("sdtm_ds", conn)

  message(sprintf("  DM: %d subjects loaded", nrow(dm)))
  message(sprintf("  AE: %d adverse event records loaded", nrow(ae)))
  message(sprintf("  EX: %d exposure records loaded", nrow(ex)))
  message(sprintf("  DS: %d disposition records loaded", nrow(ds)))

  # --- Step 3: Run ADaM creation via SLC ---
  message("Submitting create_adam.sas via Altair SLC...")
  adam_code <- paste(readLines("sas/create_adam.sas"), collapse = "\n")
  slc_submit(adam_code, conn)

  # --- Step 4: Read ADaM datasets directly from SLC workspace ---
  message("Reading ADaM datasets from SLC workspace...")
  adsl <- read_slc_data("adam_adsl", conn)
  adae <- read_slc_data("adam_adae", conn)

  message(sprintf("  ADSL: %d subjects | Dropout rate: %.1f%%",
                  nrow(adsl), mean(adsl$DPTFL == "Y") * 100))
  message(sprintf("  ADAE: %d treatment-emergent AE records", nrow(adae)))

  # --- Step 5: Demonstrate Variables Pane ---
  # In Positron, the following objects will appear in the Variables Pane
  # alongside any Python objects - showcasing true polyglot analysis.
  message("\n--- POSITRON VARIABLES PANE DEMO ---")
  message("The following R objects are now visible in the Variables Pane:")
  message("  dm    : SAS DM dataset (", nrow(dm), " rows x ", ncol(dm), " cols)")
  message("  ae    : SAS AE dataset (", nrow(ae), " rows x ", ncol(ae), " cols)")
  message("  adsl  : ADaM ADSL     (", nrow(adsl), " rows x ", ncol(adsl), " cols)")
  message("  adae  : ADaM ADAE     (", nrow(adae), " rows x ", ncol(adae), " cols)")

  slc_close(conn)
  message("SLC connection closed.")

  list(dm = dm, ae = ae, ex = ex, ds = ds, adsl = adsl, adae = adae)
}

# =============================================================================
# OPTION 2: CSV FALLBACK
# If SLC is not available, read from pre-generated CSV files.
# Run sas/generate_sdtm.sas and sas/create_adam.sas first.
# =============================================================================

run_from_csv <- function() {
  message("Altair SLC not available. Reading from CSV files...")

  required_files <- c(
    "data/sdtm/dm.csv", "data/sdtm/ae.csv",
    "data/sdtm/ex.csv", "data/sdtm/ds.csv",
    "data/adam/adsl.csv", "data/adam/adae.csv"
  )

  missing <- required_files[!file.exists(required_files)]
  if (length(missing) > 0) {
    stop(
      "Missing data files: ", paste(missing, collapse = ", "),
      "\nPlease run sas/generate_sdtm.sas and sas/create_adam.sas first."
    )
  }

  dm   <- read_csv("data/sdtm/dm.csv",   show_col_types = FALSE)
  ae   <- read_csv("data/sdtm/ae.csv",   show_col_types = FALSE)
  ex   <- read_csv("data/sdtm/ex.csv",   show_col_types = FALSE)
  ds   <- read_csv("data/sdtm/ds.csv",   show_col_types = FALSE)
  adsl <- read_csv("data/adam/adsl.csv", show_col_types = FALSE)
  adae <- read_csv("data/adam/adae.csv", show_col_types = FALSE)

  message(sprintf("Loaded ADSL: %d subjects | Dropout rate: %.1f%%",
                  nrow(adsl), mean(adsl$DPTFL == "Y", na.rm = TRUE) * 100))

  list(dm = dm, ae = ae, ex = ex, ds = ds, adsl = adsl, adae = adae)
}

# =============================================================================
# MAIN: Auto-detect SLC and load data
# =============================================================================

message("=== NovaStat Therapeutics - NSVT-001 SAS/R Bridge ===")
message("NOTE: All data is AI-generated and synthetic. Demonstration purposes only.\n")

if (slc_available()) {
  data <- run_with_slc()
} else {
  message("NOTE: To use the SLC bridge, install the Altair SLC extension in Positron.")
  data <- run_from_csv()
}

# Expose datasets at top level for use in other scripts
dm   <- data$dm
ae   <- data$ae
ex   <- data$ex
ds   <- data$ds
adsl <- data$adsl
adae <- data$adae

# =============================================================================
# QUICK VALIDATION: Show dropout distribution
# =============================================================================

message("\n--- Data Summary ---")
adsl |>
  count(TRT01P, DPTFL) |>
  pivot_wider(names_from = DPTFL, values_from = n, values_fill = 0) |>
  mutate(pct_dropout = round(Y / (Y + N) * 100, 1)) |>
  print()

message("\nBridge complete. Data ready for train_model.R and app.R.")
