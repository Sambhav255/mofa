# ============================================================================
# 00_generate_demo_data.R
#
# PURPOSE
#   Generates THREE synthetic/demo datasets that mirror the column structure
#   of the real data sources for this project. Replace each with real data
#   following the instructions in README.md. Demo data is calibrated to
#   real-world magnitudes sourced in the research handbook — but no
#   individual number here should be cited in the brief.
#
# TOPIC: Measuring the Invisible: Remittance Costs on Nepal's Korea Corridor
#        and the Case for Payment Provisions in the EPS MOU
#
# DATASET 1  rpw_demo.csv         — RPW corridor-quarter panel (Gulf/Malaysia)
# DATASET 2  nrb_remit_monthly_demo.csv — NRB monthly inflow series
# DATASET 3  korea_mto_fees_demo.csv    — Korea MTO fee schedules (NEW)
#            This is the PRIMARY ORIGINAL DATA CONTRIBUTION of the brief:
#            because Korea→Nepal is not covered by RPW, Sambhav constructs
#            a cost estimate from manually scraped MTO fee schedules.
#            Operators to scrape: GME/Global Money Express, WireBarley,
#            Sentbe, E9pay, Hanpass, SBI Cosmoney, Rupeesend, Korea Post.
#            See 02b_korea_cost_reconstruction.R for the analysis.
# ============================================================================

set.seed(42)
suppressMessages(library(dplyr))

out_dir <- "data/raw"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---------------------------------------------------------------------------
# DATASET 1: RPW corridor-quarter panel (Gulf + Malaysia corridors only)
#   NOTE: Korea→Nepal is ABSENT from RPW — that is itself a finding.
#   This dataset covers the four measured corridors used as comparators.
#   The Gulf corridors are NOT Nepal's primary problem (costs are near 3%
#   for MTOs), but they provide the empirical baseline and the bank-channel
#   penalty finding (banks 11-12% vs MTOs 3-4%).
# ---------------------------------------------------------------------------
quarters <- seq(as.Date("2011-01-01"), as.Date("2025-07-01"), by = "3 months")
qlab <- function(d) paste0(format(d, "%Y"), "Q", (as.integer(format(d, "%m")) - 1) %/% 3 + 1)

gulf_corridors <- tribble(
  ~sending_country, ~base_cost_mto, ~base_cost_bank, ~trend_per_q, ~vol_usd_mn_2023,
  "Saudi Arabia",   5.6,            13.5,            -0.025,        1020,
  "Qatar",          5.8,            14.0,            -0.026,         980,
  "UAE",            5.2,            13.0,            -0.024,         920,
  "Malaysia",       4.4,            12.5,            -0.028,         960
)

rpw_panel <- gulf_corridors %>%
  rowwise() %>%
  do({
    cc <- .
    n   <- length(quarters)
    t   <- 0:(n-1)
    noise <- arima.sim(model = list(ar = 0.6), n = n) * 0.30

    cost_mto  <- pmax(1.0, cc$base_cost_mto  + cc$trend_per_q * t + noise)
    cost_bank <- pmax(3.5, cc$base_cost_bank + cc$trend_per_q * t + noise * 0.5)
    cost_all  <- 0.75 * cost_mto + 0.25 * cost_bank  # realistic MTO:bank mix

    tibble(
      quarter           = qlab(quarters),
      quarter_date      = quarters,
      receiving_country = "Nepal",
      sending_country   = cc$sending_country,
      amount_usd        = 200,
      total_cost_pct    = round(cost_all, 3),
      mto_cost_pct      = round(cost_mto, 3),
      bank_cost_pct     = round(cost_bank, 3),
      fee_pct           = round(cost_all * runif(n, 0.45, 0.65), 3),
      fx_margin_pct     = round(cost_all * runif(n, 0.35, 0.55), 3),
      total_cost_pct_500= round(pmax(0.6, cost_all - runif(n, 0.8, 1.5)), 3),
      num_services      = round(pmax(6, rnorm(n, 12, 3))),
      pct_digital       = round(pmin(0.55, pmax(0.01, 0.03 + 0.016 * t + rnorm(n,0,0.02))), 3),
      vol_usd_mn_2023   = cc$vol_usd_mn_2023
    )
  }) %>%
  ungroup()

# ---------------------------------------------------------------------------
# Comparator country corridors (Bangladesh, Philippines, India) -- kept
# deliberately in the RPW panel because they are needed for Model B in
# 03_panel_regression.R (cross-country OLS, Nepal as reference category).
# In the Korea-focused brief these appear as a two-sentence aside:
# "Nepal's formal MTO costs are lower than Bangladesh's and comparable to
# India's, supporting the formalization-not-cost-reduction argument."
# Calibrated to real RPW Q3 2025 country averages documented in the research.
# ---------------------------------------------------------------------------
comparator_corridors <- tribble(
  ~receiving_country, ~sending_country, ~base_cost, ~trend_per_q,
  "Bangladesh", "Saudi Arabia", 8.4, -0.020,
  "Bangladesh", "UAE",          8.0, -0.021,
  "Bangladesh", "Malaysia",     7.6, -0.022,
  "Philippines","USA",          5.4, -0.026,
  "Philippines","Saudi Arabia", 5.8, -0.025,
  "India",      "UAE",          4.0, -0.027,
  "India",      "USA",          4.6, -0.028
)

comparator_panel <- comparator_corridors %>%
  rowwise() %>%
  do({
    cc <- .; n <- length(quarters); t <- 0:(n-1)
    noise <- arima.sim(model = list(ar = 0.6), n = n) * 0.32
    cost <- pmax(1.5, cc$base_cost + cc$trend_per_q * t + noise)
    tibble(
      quarter = qlab(quarters), quarter_date = quarters,
      receiving_country = cc$receiving_country, sending_country = cc$sending_country,
      amount_usd = 200,
      total_cost_pct = round(cost, 3),
      mto_cost_pct   = round(pmax(1.0, cost - runif(n, 0.5, 1.5)), 3),
      bank_cost_pct  = round(cost + runif(n, 5.0, 8.0), 3),
      fee_pct        = round(cost * runif(n, 0.45, 0.65), 3),
      fx_margin_pct  = round(cost * runif(n, 0.35, 0.55), 3),
      total_cost_pct_500 = round(pmax(0.6, cost - runif(n, 0.8, 1.5)), 3),
      num_services   = round(pmax(4, rnorm(n, 10, 3))),
      pct_digital    = round(pmin(0.5, pmax(0.01, 0.02 + 0.014 * t + rnorm(n,0,0.02))), 3),
      vol_usd_mn_2023 = NA_real_
    )
  }) %>%
  ungroup()

rpw_panel <- bind_rows(rpw_panel, comparator_panel)

write.csv(rpw_panel, file.path(out_dir, "rpw_demo.csv"), row.names = FALSE)
cat("DATASET 1: Wrote", nrow(rpw_panel), "rows to rpw_demo.csv\n")

# ---------------------------------------------------------------------------
# DATASET 2: NRB monthly remittance series
# ---------------------------------------------------------------------------
months <- seq(as.Date("2011-08-01"), as.Date("2026-05-01"), by = "1 month")
n_m    <- length(months)
t_m    <- 0:(n_m - 1)

trend   <- 8 + 0.55 * t_m + 0.0015 * t_m^2
season  <- 3 * sin(2 * pi * (t_m %% 12) / 12)
noise_m <- arima.sim(model = list(ar = 0.5), n = n_m) * 4
remit   <- trend + season + noise_m

covid_idx  <- which(months >= as.Date("2020-03-01") & months <= as.Date("2020-09-01"))
surge_idx  <- which(months >= as.Date("2021-06-01") & months <= as.Date("2023-06-01"))
recent_idx <- which(months >= as.Date("2025-07-01"))
remit[covid_idx]  <- remit[covid_idx] * seq(0.55, 0.95, length.out = length(covid_idx))
remit[surge_idx]  <- remit[surge_idx] * 1.12
remit[recent_idx] <- remit[recent_idx] * seq(1.05, 1.30, length.out = length(recent_idx))
remit <- pmax(5, remit)

nrb <- tibble(
  month             = months,
  remit_npr_bn      = round(remit, 2),
  fx_reserve_usd_bn = round(8 + 0.045 * t_m + rnorm(n_m, 0, 0.4), 2),
  labor_permits_new = round(pmax(5000, 32000 + 250 * t_m + rnorm(n_m, 0, 4000) -
                                   ifelse(months >= as.Date("2020-03-01") &
                                          months <= as.Date("2020-12-01"), 25000, 0)))
)

write.csv(nrb, file.path(out_dir, "nrb_remit_monthly_demo.csv"), row.names = FALSE)
cat("DATASET 2: Wrote", nrow(nrb), "rows to nrb_remit_monthly_demo.csv\n")

# ---------------------------------------------------------------------------
# DATASET 3: Korea MTO fee schedules (the primary original data contribution)
#
# REAL DATA ACTION (Week 1, highest priority):
#   Manually visit or scrape the following operators' KRW→NPR pages and
#   record for each: flat fee (KRW), FX margin (% above mid-market rate),
#   and the NPR received for standard transfer amounts. Operators:
#     GME / Global Money Express  — gmemts.com
#     WireBarley                  — wirebarley.com
#     Sentbe                      — sentbe.com
#     E9pay                       — e9pay.com
#     Hanpass                     — hanpass.com
#     SBI Cosmoney                — sbicm.co.kr
#     Rupeesend                   — rupeesend.com
#     Korea Post (bank baseline)  — epost.go.kr
#     KB Kookmin Bank (bank)      — kbstar.com
#   Use XE.com or Wise mid-market rate on the day as the FX benchmark.
#   Collect at TWO standard sizes: KRW 500,000 (~USD 360) and KRW 1,000,000
#   (~USD 720). Repeat across 3-4 collection dates if possible.
#
# COLUMN STRUCTURE:
#   operator | channel_type | transfer_krw | flat_fee_krw |
#   fx_margin_pct | total_cost_pct | npr_received | collection_date
# ---------------------------------------------------------------------------

# Demo calibration: formal Korea MTOs are actually cheap (~1.5-3%)
# The binding problem is NOT high formal costs — it's that 80%+ of workers
# historically used hundi. The policy ask is formalization, not cost reduction.
operators <- tribble(
  ~operator,         ~channel_type, ~flat_fee_krw_500k, ~fx_margin_pct,
  "GME",             "MTO",         3000,                0.5,
  "WireBarley",      "MTO",         2000,                0.8,
  "Sentbe",          "MTO",         2500,                0.7,
  "E9pay",           "MTO",         0,                   1.2,
  "Hanpass",         "MTO",         4000,                0.6,
  "SBI_Cosmoney",    "MTO",         3500,                0.9,
  "Rupeesend",       "MTO",         2000,                1.0,
  "Korea_Post",      "Bank",        8000,                2.5,
  "KB_Kookmin",      "Bank",        10000,               3.2
)

# Compute total cost at two transfer sizes
korea_fees <- bind_rows(
  operators %>% mutate(
    transfer_krw   = 500000,
    flat_fee_krw   = flat_fee_krw_500k,
    total_cost_pct = round(100 * (flat_fee_krw + transfer_krw * fx_margin_pct / 100) / transfer_krw, 3),
    collection_date = as.Date("2026-06-01")  # replace with real scrape date
  ),
  operators %>% mutate(
    transfer_krw   = 1000000,
    flat_fee_krw   = flat_fee_krw_500k,  # flat fee same, % cost halves
    total_cost_pct = round(100 * (flat_fee_krw + transfer_krw * fx_margin_pct / 100) / transfer_krw, 3),
    collection_date = as.Date("2026-06-01")
  )
) %>%
  select(operator, channel_type, transfer_krw, flat_fee_krw,
         fx_margin_pct, total_cost_pct, collection_date)

write.csv(korea_fees, file.path(out_dir, "korea_mto_fees_demo.csv"), row.names = FALSE)
cat("DATASET 3: Wrote", nrow(korea_fees), "rows to korea_mto_fees_demo.csv\n")
cat("\nKorea MTO cost range (KRW 500,000 transfer):\n")
print(korea_fees %>% filter(transfer_krw == 500000) %>%
        arrange(total_cost_pct) %>%
        select(operator, channel_type, total_cost_pct))
cat("\n*** These are DEMO values. Replace with real scrape before citing. ***\n")
cat("    The KEY finding will be: MTO costs are low (~1.5-3%),\n")
cat("    bank costs are 3-5x higher, AND formal-channel use is\n")
cat("    historically <20% — the policy problem is formalization,\n")
cat("    not cost reduction. This is the central original argument.\n\n")
cat("Demo data generation complete.\n")
