# ============================================================================
# 01_load_clean_rpw.R
#
# PURPOSE
#   Loads the RPW corridor-quarter panel (real or demo), cleans column types,
#   and writes a tidy processed file used by every downstream script.
#
# REAL-DATA MAPPING (once you have the actual RPW bulk Excel file):
#   The RPW download (remittanceprices.worldbank.org/data-download) arrives
#   as an Excel workbook with sheets: "Terms of Use", "Methodology", "Legend",
#   "Countries", and two data sheets (one for the $200 send amount, one for
#   $500). Each data sheet has one row per RSP (firm) per corridor per quarter.
#   To get to the corridor-quarter panel shape used here:
#     1. Read both amount-sheets with readxl::read_excel().
#     2. Filter receiving_country %in% c("Nepal","Bangladesh","Pakistan",
#        "Philippines","India") -- or whichever comparator set you finalize.
#     3. Group by (quarter, receiving_country, sending_country) and compute:
#          total_cost_pct   = mean(total cost column, transparent services only)
#          fee_pct          = mean(transaction fee % column)
#          fx_margin_pct    = total_cost_pct - fee_pct   (RPW reports an
#                              explicit FX margin column in most recent
#                              vintages -- use it directly if present)
#          num_services     = n() [count of RSPs surveyed in that corridor-quarter]
#          pct_digital      = mean(service is "digital" indicator)
#     4. Do the same for the $500 sheet -> total_cost_pct_500, join on the
#        same keys.
#   Save the result as data/raw/rpw_real.csv with IDENTICAL column names to
#   rpw_demo.csv, then just change RPW_FILE below.
# ============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(readxl)
  library(stringr)
})

RPW_FILE <- if (exists("USE_REAL_DATA") && isTRUE(USE_REAL_DATA)) {
  "data/raw/rpw_real.csv"
} else {
  "data/raw/rpw_demo.csv"
}

if (!file.exists(RPW_FILE)) {
  stop("RPW file not found at ", RPW_FILE,
       ". Run scripts/00_generate_demo_data.R first, or supply the real file.")
}

rpw <- read.csv(RPW_FILE, stringsAsFactors = FALSE)
rpw$quarter_date <- as.Date(rpw$quarter_date)

# Basic integrity checks -- these will catch most real-data formatting issues
stopifnot(all(c("quarter","receiving_country","sending_country",
                 "total_cost_pct","fee_pct","fx_margin_pct",
                 "total_cost_pct_500","num_services","pct_digital") %in% names(rpw)))

if (any(is.na(rpw$total_cost_pct))) {
  warning(sum(is.na(rpw$total_cost_pct)), " rows have missing total_cost_pct -- check source file.")
}

# Flag corridor-quarters with very few surveyed services (low-confidence averages)
rpw <- rpw %>%
  mutate(low_confidence = num_services < 5,
         corridor = paste0(sending_country, " -> ", receiving_country))

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
write.csv(rpw, "data/processed/rpw_panel_clean.csv", row.names = FALSE)

cat("Loaded", nrow(rpw), "corridor-quarter observations across",
    n_distinct(rpw$corridor), "corridors,", n_distinct(rpw$receiving_country),
    "receiving countries, and", n_distinct(rpw$quarter), "quarters.\n")
cat("Flagged", sum(rpw$low_confidence), "low-confidence corridor-quarters (num_services < 5).\n")
cat("Saved cleaned panel to data/processed/rpw_panel_clean.csv\n")
