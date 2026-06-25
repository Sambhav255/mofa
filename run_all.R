# ============================================================================
# run_all.R — runs the full pipeline in order
# Topic: Measuring the Invisible: Remittance Costs on Nepal's Korea Corridor
#        and the Case for Payment Provisions in the EPS MOU
#
# Usage: Rscript run_all.R   (from this project directory)
# ============================================================================

USE_REAL_DATA <- TRUE

prep_scripts <- if (USE_REAL_DATA) {
  c(
    "scripts/00b_reshape_rpw_excel.R",
    "scripts/00c_ingest_nrb_real.R",
    "scripts/00d_ingest_korea_fees_real.R"
  )
} else {
  c("scripts/00_generate_demo_data.R")
}

analysis_scripts <- c(
  "scripts/01_load_clean_rpw.R",
  "scripts/02_corridor_diagnostics.R",
  "scripts/02b_korea_cost_reconstruction.R",
  "scripts/03_panel_regression.R",
  "scripts/04_timeseries_structural_break.R",
  "scripts/05_monte_carlo_retention.R",
  "scripts/06_eps_mou_analysis.R"
)

scripts <- c(prep_scripts, analysis_scripts)

dir.create("output", showWarnings = FALSE, recursive = TRUE)
log_file <- "output/pipeline_run_log.txt"
log_con <- file(log_file, open = "wt")
sink(log_con, split = TRUE)
on.exit({
  sink()
  close(log_con)
}, add = TRUE)

cat("Pipeline start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("USE_REAL_DATA =", USE_REAL_DATA, "\n\n")

for (s in scripts) {
  cat("\n", strrep("=", 65), "\n# ", s, "\n", strrep("=", 65), "\n", sep = "")
  tryCatch(
    source(s, local = FALSE),
    error = function(e) {
      cat("\n*** PIPELINE ERROR in", s, "***\n")
      cat(conditionMessage(e), "\n")
      cat("\nTraceback:\n")
      traceback()
      stop(e)
    }
  )
}

cat("\n\nALL SCRIPTS COMPLETE.\n")
cat("Log written to output/pipeline_run_log.txt\n")
