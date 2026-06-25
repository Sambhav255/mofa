# ============================================================================
# collect_real_data.R
# Attempts to pull / assemble real-source data files for the pipeline.
# Run: Rscript scripts/collect_real_data.R
#
# NOTE: Full RPW bulk Excel still requires World Bank download approval.
#       NRB "Monthly Statistics" xlsx = banking stats, NOT remittance inflows.
#       Remittance series comes from Current Macroeconomic Situation PDFs.
# ============================================================================

suppressMessages(library(dplyr))

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
dir.create("data/raw/collected", showWarnings = FALSE, recursive = TRUE)

cat("Collecting available real/public data...\n")

# ---- 1. Korea MTO fees (scraped / published fee schedules, 2026-06-23) ----
# Sources: operator websites + WireBarley published 2026 fee table (krinsider.com)
# Mid-market KRW/NPR from open.er-api.com on collection date
mid_npr_per_krw <- 0.098563  # 1 KRW = 0.098563 NPR (collection day)

korea_ops <- tribble(
  ~operator, ~channel_type, ~flat_fee_krw_500k, ~fx_margin_pct, ~source_note,
  "GME", "MTO", 3000, 0.5, "Published fee schedule (operator site; verify in app)",
  "WireBarley", "MTO", 3000, 0.8, "WireBarley 2026 tier: KRW 3000 under KRW 3M",
  "Sentbe", "MTO", 2500, 0.7, "Demo-calibrated; re-scrape sentbe.com",
  "E9pay", "MTO", 0, 1.2, "Demo-calibrated; re-scrape e9pay.com",
  "Hanpass", "MTO", 4000, 0.6, "Demo-calibrated; re-scrape hanpass.com",
  "SBI_Cosmoney", "MTO", 3500, 0.9, "Demo-calibrated; re-scrape sbicm.co.kr",
  "Rupeesend", "MTO", 2000, 1.0, "Demo-calibrated; re-scrape rupeesend.com",
  "Korea_Post", "Bank", 8000, 2.5, "Demo-calibrated; verify epost.go.kr",
  "KB_Kookmin", "Bank", 10000, 3.2, "Demo-calibrated; verify kbstar.com"
)

korea_fees <- bind_rows(
  korea_ops %>% mutate(transfer_krw = 500000, flat_fee_krw = flat_fee_krw_500k),
  korea_ops %>% mutate(transfer_krw = 1000000, flat_fee_krw = flat_fee_krw_500k)
) %>%
  mutate(
    total_cost_pct = round(100 * (flat_fee_krw + transfer_krw * fx_margin_pct / 100) / transfer_krw, 3),
    npr_midmarket = round(transfer_krw * mid_npr_per_krw, 2),
    collection_date = as.Date("2026-06-23")
  ) %>%
  select(operator, channel_type, transfer_krw, flat_fee_krw, fx_margin_pct,
         total_cost_pct, npr_midmarket, collection_date, source_note)

write.csv(korea_fees, "data/raw/collected/korea_mto_fees_collected_2026-06-23.csv", row.names = FALSE)
cat("Wrote korea_mto_fees_collected_2026-06-23.csv (GME/WireBarley verified; others need re-scrape)\n")

# ---- 2. RPW Nepal corridors — Q3 2025 partial (Saudi Arabia, from RPW website) ----
# Source: remittanceprices.worldbank.org/corridor/Saudi Arabia/Nepal, collected 2026-06-23
# Korea→Nepal: NOT IN RPW (confirmed empty corridor page)
rpw_q3_2025 <- tribble(
  ~quarter, ~quarter_date, ~receiving_country, ~sending_country, ~amount_usd,
  ~firm_type, ~service_name, ~total_cost_pct, ~fee_pct, ~fx_margin_pct, ~access_point,
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "MTO", "STC Pay (mobile)", 3.21, NA, 0.91, "Mobile",
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "MTO", "MTO service 1", 3.12, NA, 0.51, "Agent",
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "MTO", "MTO service 2", 3.37, NA, 1.07, "Mobile",
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "MTO", "MTO avg (low)", 3.12, NA, 0.51, "Mixed",
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "MTO", "MTO avg (high)", 3.96, NA, 1.66, "Agent",
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "Bank", "Bank branch 1", 11.02, NA, 1.02, "Bank",
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "Bank", "Bank branch 2", 12.06, NA, 2.06, "Bank",
  "2025Q3", "2025-07-01", "Nepal", "Saudi Arabia", 200, "All", "Corridor average", 5.02, NA, 1.18, "All"
)

write.csv(rpw_q3_2025, "data/raw/collected/rpw_saudi_nepal_q3_2025_collected.csv", row.names = FALSE)
cat("Wrote rpw_saudi_nepal_q3_2025_collected.csv (partial — one corridor only)\n")
cat("ACTION REQUIRED: Download full RPW Excel from remittanceprices.worldbank.org/data-download\n")

# ---- 3. NRB remittance — partial monthly from official macro reports ----
# Source: NRB Current Macroeconomic and Financial Situation PDFs (NOT monthly-statistics xlsx)
nrb_partial <- tribble(
  ~month, ~remit_npr_bn, ~fx_reserve_usd_bn, ~labor_permits_new, ~source,
  "2025-05-15", 165.30, NA, NA, "NRB ten-month report FY2024/25 (Baisakh 2082 month)",
  "2025-06-15", NA, NA, NA, "NRB — month figure not extracted yet",
  "2025-07-15", 189.11, 19.50, NA, "NRB annual report FY2024/25 (Asar 2082 month)",
  "2025-08-15", 174.67, NA, NA, "NRB two-month report FY2025/26 (Bhadau month)",
  "2025-09-15", 201.22, 21.21, NA, "NRB three-month report FY2025/26 (Ashoj month)",
  "2025-07-16", 177.41, NA, NA, "NRB one-month report FY2025/26 (first month cumulative)"
) %>%
  mutate(month = as.Date(month))

write.csv(nrb_partial, "data/raw/collected/nrb_remit_monthly_partial.csv", row.names = FALSE)
cat("Wrote nrb_remit_monthly_partial.csv (6 official data points — NOT a full series)\n")
cat("ACTION REQUIRED: Transcribe monthly figures from NRB macro PDFs or External Sector DB\n")

# ---- 4. Reference parameters (sourced constants for Monte Carlo) ----
params <- tribble(
  ~parameter, ~value, ~unit, ~source, ~collection_date,
  "korea_corridor_total", 484, "USD million/year", "NLSS IV 2022/23", "2026-06-23",
  "saudi_corridor_total", 1020, "USD million/year", "NLSS IV 2022/23", "2026-06-23",
  "korea_informal_share_historical", 0.80, "proportion", "IOM Seoul / Kathmandu Post ~2017", "2026-06-23",
  "korea_informal_share_current_est", 0.55, "proportion", "Literature triangulation", "2026-06-23",
  "nrb_fx_reserves", 19.50, "USD billion", "NRB annual report mid-July 2025", "2026-06-23",
  "saudi_bank_cost_q3_2025", 11.54, "percent", "RPW Saudi→Nepal Q3 2025 bank avg", "2026-06-23",
  "saudi_mto_cost_q3_2025", 3.35, "percent", "RPW Saudi→Nepal Q3 2025 MTO avg", "2026-06-23",
  "saudi_corridor_avg_q3_2025", 5.02, "percent", "RPW Saudi→Nepal Q3 2025 all-channel avg", "2026-06-23",
  "krw_npr_midmarket", 0.098563, "NPR per KRW", "open.er-api.com", "2026-06-23",
  "korea_in_rpw", 0, "boolean", "RPW corridor page empty — confirmed absent", "2026-06-23"
)

write.csv(params, "data/raw/collected/reference_parameters_collected.csv", row.names = FALSE)
cat("Wrote reference_parameters_collected.csv\n")

cat("\n=== COLLECTION SUMMARY ===\n")
cat("Collected: Korea fees (partial), Saudi RPW Q3 snapshot, NRB partial months, reference params\n")
cat("Blocked:   Full RPW Excel (403/form gate), full NRB series (PDF transcription), live MTO app rates\n")
cat("Files in:  data/raw/collected/\n")
