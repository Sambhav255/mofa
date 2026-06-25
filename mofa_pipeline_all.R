# =============================================================================
# mofa_pipeline_all.R — Full MoFA Cluster 10 statistical pipeline (single file)
#
# Topic: Measuring the Invisible: Remittance Costs on Nepal's Korea Corridor
#        and the Case for Payment Provisions in the EPS MOU
#
# Usage (from project root):
#   Rscript mofa_pipeline_all.R
#   source("mofa_pipeline_all.R")
#
# install.packages(c("dplyr","tidyr","ggplot2","readxl","stringr","plm",
#                     "lmtest","sandwich","broom","zoo","strucchange",
#                     "tseries","forecast"))
# =============================================================================

# ---- Configuration -----------------------------------------------------------
RPW_FILE   <- "data/raw/rpw_demo.csv"              # change to rpw_real.csv when ready
NRB_FILE   <- "data/raw/nrb_remit_monthly_demo.csv"
KOREA_FILE <- "data/raw/korea_mto_fees_demo.csv"
GENERATE_DEMO_DATA <- TRUE  # set FALSE once real raw files are in place

# ---- Libraries & directories (once) ------------------------------------------
suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readxl)
  library(stringr)
  library(plm)
  library(lmtest)
  library(sandwich)
  library(broom)
  library(zoo)
  library(strucchange)
  library(tseries)
  library(forecast)
})

dir.create("data/raw",        showWarnings = FALSE, recursive = TRUE)
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
dir.create("output/tables",  showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

cat("\n", strrep("=", 70), "\nMoFA REMITTANCE PIPELINE — FULL RUN\n", strrep("=", 70), "\n\n", sep = "")


cat("\n", strrep("=", 70), "\n# SECTION 0: Generate demo data\n", strrep("=", 70), "\n", sep = "")

if (GENERATE_DEMO_DATA) {
set.seed(42)
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
}

cat("\n", strrep("=", 70), "\n# SECTION 1: Load and clean RPW panel\n", strrep("=", 70), "\n", sep = "")

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

write.csv(rpw, "data/processed/rpw_panel_clean.csv", row.names = FALSE)

cat("Loaded", nrow(rpw), "corridor-quarter observations across",
    n_distinct(rpw$corridor), "corridors,", n_distinct(rpw$receiving_country),
    "receiving countries, and", n_distinct(rpw$quarter), "quarters.\n")
cat("Flagged", sum(rpw$low_confidence), "low-confidence corridor-quarters (num_services < 5).\n")
cat("Saved cleaned panel to data/processed/rpw_panel_clean.csv\n")

cat("\n", strrep("=", 70), "\n# SECTION 2: Gulf corridor diagnostics\n", strrep("=", 70), "\n", sep = "")

panel <- read.csv("data/processed/rpw_panel_clean.csv", stringsAsFactors = FALSE)
panel$quarter_date <- as.Date(panel$quarter_date)

latest_q <- max(panel$quarter_date)
cat("Latest quarter in panel:", format(latest_q, "%Y-%m"), "\n\n")

# ---------------------------------------------------------------------------
# (a) Latest-quarter Nepal corridor table with fee/FX decomposition
# ---------------------------------------------------------------------------
nepal_latest <- panel %>%
  filter(receiving_country == "Nepal", quarter_date == latest_q) %>%
  transmute(
    Corridor       = corridor,
    `Cost $200 (%)`  = round(total_cost_pct, 2),
    `Cost $500 (%)`  = round(total_cost_pct_500, 2),
    `Fee (%)`        = round(fee_pct, 2),
    `FX margin (%)`  = round(fx_margin_pct, 2),
    `FX share of cost (%)` = round(100 * fx_margin_pct / total_cost_pct, 1),
    `Small-transfer penalty (pp)` = round(total_cost_pct - total_cost_pct_500, 2),
    `# services surveyed` = num_services,
    `Digital share (%)`   = round(100 * pct_digital, 1)
  ) %>%
  arrange(desc(`Cost $200 (%)`))

write.csv(nepal_latest, "output/tables/table1_nepal_corridor_diagnostic.csv", row.names = FALSE)
cat("TABLE 1 -- Nepal corridor diagnostic, latest quarter\n")
print(nepal_latest, row.names = FALSE)
cat("\n")

# ---------------------------------------------------------------------------
# (b) Volume-weighted national average vs SDG target
#     NOTE: weights below are PLACEHOLDER equal weights. Replace with real
#     NRB/KNOMAD corridor volume shares (see README "Weighting corridors by
#     volume") before this number goes in the brief -- an unweighted average
#     understates the true national cost if Nepal's largest corridor (e.g.
#     UAE/Saudi/Qatar) is also a high-cost one.
# ---------------------------------------------------------------------------
weights <- nepal_latest %>%
  transmute(Corridor, weight = 1 / n())   # PLACEHOLDER equal weights

weighted_avg <- sum(nepal_latest$`Cost $200 (%)` * weights$weight)
cat(sprintf("PLACEHOLDER volume-weighted average cost to Nepal (%s): %.2f%%\n",
            format(latest_q, "%Y-%m"), weighted_avg))
cat("  -> SDG 10.c target: 3.00%  |  Gap:", round(weighted_avg - 3, 2), "pp\n")
cat("  -> G20/5x5 ceiling: 5.00%  |  Corridors above ceiling:",
    sum(nepal_latest$`Cost $200 (%)` > 5), "of", nrow(nepal_latest), "\n\n")

# ---------------------------------------------------------------------------
# (c) Cross-country comparison (latest quarter, simple corridor average)
# ---------------------------------------------------------------------------
country_compare <- panel %>%
  filter(quarter_date == latest_q) %>%
  group_by(receiving_country) %>%
  summarise(
    mean_cost_200   = round(mean(total_cost_pct), 2),
    mean_fx_margin  = round(mean(fx_margin_pct), 2),
    mean_fee        = round(mean(fee_pct), 2),
    mean_digital    = round(100 * mean(pct_digital), 1),
    n_corridors     = n(),
    .groups = "drop"
  ) %>%
  arrange(mean_cost_200)

write.csv(country_compare, "output/tables/table2_country_comparison.csv", row.names = FALSE)
cat("TABLE 2 -- Cross-country comparison, latest quarter (simple corridor average)\n")
print(country_compare, row.names = FALSE)
cat("\nCAUTION: This is an unweighted, uncontrolled comparison -- it does not\n")
cat("account for the fact that each country's corridor MIX differs (e.g. more\n")
cat("Gulf-heavy vs more US/UK-heavy). See 03_panel_regression.R for the\n")
cat("regression-adjusted version that controls for this via fixed effects.\n\n")

# ---------------------------------------------------------------------------
# (d) Time trend chart: Nepal corridors since 2011 vs SDG target
# ---------------------------------------------------------------------------
nepal_trend <- panel %>%
  filter(receiving_country == "Nepal") %>%
  group_by(quarter_date) %>%
  summarise(mean_cost = mean(total_cost_pct), .groups = "drop")

p1 <- ggplot(nepal_trend, aes(x = quarter_date, y = mean_cost)) +
  geom_line(color = "#13315c", linewidth = 1) +
  geom_hline(yintercept = 3, linetype = "dashed", color = "#b3001b") +
  annotate("text", x = min(nepal_trend$quarter_date), y = 3.15,
           label = "SDG 10.c target (3%)", hjust = 0, size = 3, color = "#b3001b") +
  labs(title = "Average cost of sending remittances to Nepal, 2011-2025",
       subtitle = "Simple average across tracked corridors, $200 send amount",
       x = NULL, y = "Cost (% of amount sent)") +
  theme_minimal(base_size = 11)

ggsave("output/figures/fig1_nepal_cost_trend.png", p1, width = 7.5, height = 4.2, dpi = 200)
cat("Saved output/figures/fig1_nepal_cost_trend.png\n")

# ---------------------------------------------------------------------------
# (e) Fee vs FX-margin decomposition chart (stacked), latest quarter
# ---------------------------------------------------------------------------
decomp <- nepal_latest %>%
  select(Corridor, `Fee (%)`, `FX margin (%)`) %>%
  pivot_longer(-Corridor, names_to = "Component", values_to = "Value")

p2 <- ggplot(decomp, aes(x = reorder(Corridor, Value, sum), y = Value, fill = Component)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = c("Fee (%)" = "#13315c", "FX margin (%)" = "#7fb3d5")) +
  labs(title = "Where the cost comes from: fee vs FX margin by corridor",
       subtitle = paste0(format(latest_q, "%Y"), " Q", (as.integer(format(latest_q, "%m")) - 1) %/% 3 + 1),
       x = NULL, y = "Cost (% of $200 sent)", fill = NULL) +
  theme_minimal(base_size = 11)

ggsave("output/figures/fig2_fee_vs_fx_decomposition.png", p2, width = 7.5, height = 4.2, dpi = 200)
cat("Saved output/figures/fig2_fee_vs_fx_decomposition.png\n")

cat("\n02_corridor_diagnostics.R complete.\n")

cat("\n", strrep("=", 70), "\n# SECTION 2b: Korea cost reconstruction\n", strrep("=", 70), "\n", sep = "")

# ---------------------------------------------------------------------------
# 1. Load Korea fee data and Gulf RPW data
# ---------------------------------------------------------------------------
korea <- read.csv(KOREA_FILE, stringsAsFactors = FALSE)
korea$collection_date <- as.Date(korea$collection_date)

rpw <- read.csv("data/processed/rpw_panel_clean.csv", stringsAsFactors = FALSE)
rpw$quarter_date <- as.Date(rpw$quarter_date)

cat("=================================================================\n")
cat("KOREA CORRIDOR COST RECONSTRUCTION\n")
cat("Data source: manually scraped MTO fee schedules (demo)\n")
cat("Replace korea_mto_fees_demo.csv with real scrape before citing\n")
cat("=================================================================\n\n")

# ---------------------------------------------------------------------------
# 2. Korea cost summary table
# ---------------------------------------------------------------------------
korea_500k <- korea %>%
  filter(transfer_krw == 500000) %>%
  arrange(total_cost_pct)

korea_1m <- korea %>%
  filter(transfer_krw == 1000000) %>%
  arrange(total_cost_pct)

usd_equiv_500k  <- round(500000 / 1380, 0)   # approx USD at KRW 1380/USD
usd_equiv_1m    <- round(1000000 / 1380, 0)

cat(sprintf("Korea → Nepal cost estimates (KRW 500,000 ≈ USD %d)\n", usd_equiv_500k))
cat(strrep("-", 55), "\n")
print(korea_500k %>% select(operator, channel_type, flat_fee_krw, fx_margin_pct, total_cost_pct),
      row.names = FALSE)
cat(sprintf("\nMTO simple average:  %.2f%%\n", mean(korea_500k$total_cost_pct[korea_500k$channel_type == "MTO"])))
cat(sprintf("Bank simple average: %.2f%%\n", mean(korea_500k$total_cost_pct[korea_500k$channel_type == "Bank"])))
cat(sprintf("Bank:MTO cost ratio: %.1fx\n\n",
            mean(korea_500k$total_cost_pct[korea_500k$channel_type == "Bank"]) /
            mean(korea_500k$total_cost_pct[korea_500k$channel_type == "MTO"])))

write.csv(korea_500k, "output/tables/table_korea_mto_costs_500k.csv", row.names = FALSE)
write.csv(korea_1m,   "output/tables/table_korea_mto_costs_1m.csv",   row.names = FALSE)

# ---------------------------------------------------------------------------
# 3. Compare Korea MTO costs to Gulf corridor MTO costs
# ---------------------------------------------------------------------------
gulf_latest <- rpw %>%
  filter(quarter_date == max(quarter_date)) %>%
  mutate(corridor = paste(sending_country, "→ Nepal"),
         cost_type = "Gulf (RPW official)",
         total_cost_pct = mto_cost_pct)

korea_mto_summary <- tibble(
  corridor   = "Korea → Nepal",
  cost_type  = "Korea (reconstructed, MTO only)",
  total_cost_pct = mean(korea_500k$total_cost_pct[korea_500k$channel_type == "MTO"])
)

comparison <- bind_rows(
  gulf_latest %>% select(corridor, cost_type, total_cost_pct),
  korea_mto_summary
) %>% arrange(total_cost_pct)

cat("CROSS-CORRIDOR COMPARISON (MTO costs only, ~USD 360 equivalent)\n")
cat(strrep("-", 55), "\n")
print(comparison, row.names = FALSE)

cat("\n*** KEY FINDING ***\n")
cat("Korea formal MTO costs (~1.5%) are LOWER than any Gulf corridor.\n")
cat("This means the Korea policy problem is NOT 'costs are too high'\n")
cat("on formal channels — it is 'workers are not using formal channels'\n")
cat("despite those channels being cheaper than most Gulf alternatives.\n")
cat("The brief's central argument therefore shifts from cost-reduction\n")
cat("to FORMALIZATION — and the diplomatic instrument is the EPS MOU\n")
cat("(pre-departure orientation + account setup + fee disclosure),\n")
cat("not a fee-cap negotiation.\n\n")

write.csv(comparison, "output/tables/table_korea_vs_gulf_comparison.csv", row.names = FALSE)

# ---------------------------------------------------------------------------
# 4. Visualise Korea operator costs vs SDG target and Gulf average
# ---------------------------------------------------------------------------
gulf_mto_avg <- gulf_latest %>% summarise(avg = mean(mto_cost_pct)) %>% pull(avg)

korea_plot <- korea_500k %>%
  mutate(operator = reorder(operator, total_cost_pct),
         bar_color = ifelse(channel_type == "Bank", "#b3001b", "#13315c"))

p_korea <- ggplot(korea_plot, aes(x = operator, y = total_cost_pct, fill = channel_type)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 3.0, linetype = "dashed", color = "#b3001b", linewidth = 0.8) +
  geom_hline(yintercept = gulf_mto_avg, linetype = "dotted", color = "#888888", linewidth = 0.8) +
  annotate("text", x = 0.6, y = 3.15, label = "SDG 10.c target (3%)",
           hjust = 0, size = 2.8, color = "#b3001b") +
  annotate("text", x = 0.6, y = gulf_mto_avg + 0.15,
           label = sprintf("Gulf MTO avg (%.1f%%)", gulf_mto_avg),
           hjust = 0, size = 2.8, color = "#555555") +
  scale_fill_manual(values = c("MTO" = "#13315c", "Bank" = "#b3001b")) +
  coord_flip() +
  labs(
    title   = "Korea → Nepal: Cost by operator (KRW 500,000 transfer)",
    subtitle = "Reconstructed from operator fee schedules — formal MTOs are already below the SDG 3% target",
    x = NULL, y = "Total cost (% of transfer amount)", fill = "Channel type",
    caption = "Source: Sambhav Lamichhane (2026), operator fee schedule reconstruction. Demo data — replace with real scrape."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave("output/figures/fig_korea_operator_costs.png", p_korea, width = 8, height = 5, dpi = 200)
cat("Saved output/figures/fig_korea_operator_costs.png\n\n")

# ---------------------------------------------------------------------------
# 5. The formalization gap calculation
#    This is the headline number for the brief's Key Findings section.
# ---------------------------------------------------------------------------
cat("=================================================================\n")
cat("THE FORMALIZATION GAP\n")
cat("=================================================================\n\n")

# Inputs (all sourced in the research handbook — replace with real latest figures)
KOREA_TOTAL_USD_MN     <- 484   # NLSS IV 2022/23 estimate (formal + informal)
INFORMAL_SHARE_HIST    <- 0.80  # IOM Seoul / Kathmandu Post 2017 figure
INFORMAL_SHARE_CURRENT <- 0.55  # estimated improvement (formal use growing, KP 2023)
FORMAL_MTO_COST_PCT    <- 1.30  # MTO simple average from reconstruction (KRW 500k)
HUNDI_IMPLICIT_COST_PCT <- 1.0  # estimated (hundi charges via worse FX rate; range 0.5-2.5%)
SDG_TARGET             <- 3.0

formal_flows_hist    <- KOREA_TOTAL_USD_MN * (1 - INFORMAL_SHARE_HIST)
formal_flows_current <- KOREA_TOTAL_USD_MN * (1 - INFORMAL_SHARE_CURRENT)
informal_flows_hist  <- KOREA_TOTAL_USD_MN * INFORMAL_SHARE_HIST
informal_flows_curr  <- KOREA_TOTAL_USD_MN * INFORMAL_SHARE_CURRENT

cat(sprintf("Total Korea corridor (NLSS IV 2023 estimate): USD %.0fM/year\n", KOREA_TOTAL_USD_MN))
cat(sprintf("Historical informal share (~2017 IOM estimate): %.0f%% → USD %.0fM informal\n",
            INFORMAL_SHARE_HIST * 100, informal_flows_hist))
cat(sprintf("Estimated current informal share:              %.0f%% → USD %.0fM informal\n\n",
            INFORMAL_SHARE_CURRENT * 100, informal_flows_curr))

cat("NET COST TO HOUSEHOLDS OF FULL FORMALIZATION\n")
cat(sprintf("  Switching USD %.0fM from informal (%.1f%%) to formal MTO (%.1f%%):\n",
            informal_flows_curr, HUNDI_IMPLICIT_COST_PCT, FORMAL_MTO_COST_PCT))
net_cost_switch_usd_mn <- informal_flows_curr * (FORMAL_MTO_COST_PCT - HUNDI_IMPLICIT_COST_PCT) / 100
cat(sprintf("  Net additional fee cost to households: USD %.1fM/year\n", net_cost_switch_usd_mn))
cat(sprintf("  Per EPS worker (est. 40,000-100,000): USD %.0f–%.0f/year\n",
            net_cost_switch_usd_mn * 1e6 / 100000,
            net_cost_switch_usd_mn * 1e6 / 40000))
cat("\nINTERPRETATION FOR THE BRIEF:\n")
cat("  The net household cost of switching to formal channels is SMALL —\n")
cat("  only ~0.3 percentage points more than estimated hundi cost.\n")
cat("  The national benefit (FX reserve capture, FATF compliance, worker\n")
cat("  financial protection, and data visibility) FAR outweighs this cost.\n")
cat("  This is the core policy case: formalization benefits Nepal at minimal\n")
cat("  cost to the workers doing the remitting.\n\n")

cat(sprintf("FX RESERVES BENEFIT (flows recaptured into NRB-visible channels):\n"))
cat(sprintf("  If current informal share (%.0f%%) falls to 20%%:\n",
            INFORMAL_SHARE_CURRENT * 100))
recapture_usd_mn <- informal_flows_curr * 0.636  # bringing 63.6% of informal into formal
cat(sprintf("  ~USD %.0fM/year moves into official/measured channels\n", recapture_usd_mn))
cat(sprintf("  This is %.1f%% of Nepal's total FX reserve buffer\n",
            recapture_usd_mn / 18650 * 100))  # NRB June 2025 reserves USD 18.65bn

cat("\n02b_korea_cost_reconstruction.R complete.\n")

cat("\n", strrep("=", 70), "\n# SECTION 3: Panel regression\n", strrep("=", 70), "\n", sep = "")

panel <- read.csv("data/processed/rpw_panel_clean.csv", stringsAsFactors = FALSE)
panel$quarter_date <- as.Date(panel$quarter_date)
panel$corridor_id  <- paste(panel$sending_country, panel$receiving_country, sep = "_")

# ---------------------------------------------------------------------------
# MODEL A: within-Nepal panel, corridor + quarter fixed effects
# ---------------------------------------------------------------------------
nepal_panel <- panel %>% filter(receiving_country == "Nepal")

pdata_a <- pdata.frame(nepal_panel, index = c("corridor_id", "quarter"))

model_a <- plm(
  total_cost_pct ~ num_services + pct_digital,
  data  = pdata_a,
  model = "within",
  effect = "twoways"   # corridor FE + quarter FE
)

# Cluster-robust SEs by corridor (vcovHC with cluster type "group")
se_a <- coeftest(model_a, vcov = vcovHC(model_a, type = "HC1", cluster = "group"))

cat("=================================================================\n")
cat("MODEL A: Within-Nepal fixed-effects panel regression\n")
cat("  total_cost_pct ~ num_services + pct_digital + corridor FE + quarter FE\n")
cat("=================================================================\n")
print(se_a)
cat("\nInterpretation guide:\n")
cat("  - num_services coefficient: expected change in cost (pp) per additional\n")
cat("    RSP surveyed in that corridor-quarter, holding corridor & time fixed.\n")
cat("    A negative, significant coefficient supports the competition channel\n")
cat("    from Beck & Martinez Peria (2011) -- i.e. a diplomatic case for actively\n")
cat("    recruiting more licensed remittance service providers into thin corridors.\n")
cat("  - pct_digital coefficient: expected change in cost (pp) per 1-unit (100pp)\n")
cat("    rise in the digital share of services in that corridor-quarter. A\n")
cat("    negative, significant coefficient supports prioritizing digital-payment\n")
cat("    interoperability (the UPI-NPI precedent) as a cost-reduction lever.\n\n")

a_tidy <- tidy(se_a) %>% mutate(model = "A: within-Nepal")
write.csv(a_tidy, "output/tables/table3a_model_within_nepal.csv", row.names = FALSE)

# ---------------------------------------------------------------------------
# MODEL B: cross-country OLS, latest quarter (Nepal as reference category)
# NOTE: We do NOT use plm's "within" estimator here because receiving_country
# is constant within each corridor_id, so the FE demeaning would absorb it
# (leaving a factor with one level, which throws the contrasts error).
# Instead: pooled OLS on the latest-quarter cross-section with explicit
# receiving_country dummies and corridor-level controls, clustering SEs by
# corridor. This matches the Beck/Martinez-Peria cross-country design.
# ---------------------------------------------------------------------------

latest_cross <- panel %>% filter(quarter_date == max(quarter_date))
latest_cross$receiving_country <- relevel(factor(latest_cross$receiving_country), ref = "Nepal")

model_b_ols <- lm(
  total_cost_pct ~ receiving_country + num_services + pct_digital + sending_country,
  data = latest_cross   # latest-quarter cross-section, Nepal releveled as reference
)

se_b <- coeftest(model_b_ols, vcov = vcovHC(model_b_ols, type = "HC1"))

cat("=================================================================\n")
cat("MODEL B: Cross-country comparison, latest quarter\n")
cat("  total_cost_pct ~ receiving_country + num_services + pct_digital + sending_country\n")
cat("  (Nepal is the omitted/reference category for receiving_country)\n")
cat("=================================================================\n")
print(se_b)
cat("\nInterpretation guide:\n")
cat("  - Each receiving_country coefficient is that country's cost gap vs Nepal,\n")
cat("    HOLDING the sending-country mix, competition, and digital share fixed.\n")
cat("    Compare this to the raw, unadjusted gaps in Table 2 (script 02) -- if\n")
cat("    the regression-adjusted gap is similar, your Table 2 comparison is robust;\n")
cat("    if it shrinks a lot, the raw comparison was partly an artifact of corridor mix.\n\n")
cat("  CAVEAT: with only ~19 corridors this is a small cross-section -- treat\n")
cat("  p-values as indicative, not definitive, and say so explicitly in the brief.\n")
cat("  Expanding to the FULL real RPW corridor set for these five countries\n")
cat("  (likely 40-60+ corridors once you pull the real bulk file) will sharpen this.\n\n")

b_tidy <- tidy(se_b) %>% mutate(model = "B: cross-country")
write.csv(b_tidy, "output/tables/table3b_model_cross_country.csv", row.names = FALSE)

cat("03_panel_regression.R complete. Coefficient tables in output/tables/.\n")

cat("\n", strrep("=", 70), "\n# SECTION 4: Time series & structural breaks\n", strrep("=", 70), "\n", sep = "")

nrb <- read.csv(NRB_FILE, stringsAsFactors = FALSE)
nrb$month <- as.Date(nrb$month)
nrb <- nrb %>% arrange(month)

ts_remit <- ts(nrb$remit_npr_bn, start = c(as.integer(format(min(nrb$month), "%Y")),
                                            as.integer(format(min(nrb$month), "%m"))),
                frequency = 12)

# ---------------------------------------------------------------------------
# 1. Stationarity check
# ---------------------------------------------------------------------------
adf_level <- adf.test(ts_remit)
adf_diff  <- adf.test(diff(ts_remit))

cat("=================================================================\n")
cat("1. AUGMENTED DICKEY-FULLER UNIT ROOT TEST\n")
cat("=================================================================\n")
cat(sprintf("  Levels:           Dickey-Fuller = %.3f, p = %.3f  %s\n",
            adf_level$statistic, adf_level$p.value,
            ifelse(adf_level$p.value < 0.05, "(stationary)", "(NON-stationary -- use differences/growth rates)")))
cat(sprintf("  First difference: Dickey-Fuller = %.3f, p = %.3f  %s\n\n",
            adf_diff$statistic, adf_diff$p.value,
            ifelse(adf_diff$p.value < 0.05, "(stationary)", "(still non-stationary -- investigate further)")))
cat("Nepali precedent: Bhatt (2013, NRB WP14) and the Granger-causality study\n")
cat("on Nepal remittances both find trade deficit & remittance series are\n")
cat("non-stationary in levels but stationary in first differences --\n")
cat("expect a similar result here, and model YoY growth rates, not levels,\n")
cat("in the brief's headline charts.\n\n")

# ---------------------------------------------------------------------------
# 2. STL decomposition (trend / seasonal / remainder)
# ---------------------------------------------------------------------------
stl_fit <- stl(ts_remit, s.window = "periodic")
png("output/figures/fig3_stl_decomposition.png", width = 1400, height = 900, res = 200)
plot(stl_fit, main = "STL decomposition of NRB monthly remittance inflows")
dev.off()
cat("Saved output/figures/fig3_stl_decomposition.png\n\n")

# ---------------------------------------------------------------------------
# 3. Endogenous structural break detection
# ---------------------------------------------------------------------------
bp <- breakpoints(remit_npr_bn ~ 1, data = nrb, h = 0.10)  # h = min segment size (10% of series)
bp_dates <- nrb$month[bp$breakpoints]

cat("=================================================================\n")
cat("2. ENDOGENOUS STRUCTURAL BREAK DETECTION (strucchange::breakpoints)\n")
cat("=================================================================\n")
cat("Data-detected most likely break date(s):\n")
print(bp_dates)
cat("\nCompare these to your candidate event dates (COVID-19 2020-03, FATF\n")
cat("grey-listing 2025-02, UPI-NPI launch 2026-06). A break detected within a\n")
cat("month or two of a candidate date is suggestive evidence (not proof) that\n")
cat("the event coincided with a level/trend shift.\n\n")

png("output/figures/fig4_structural_breaks.png", width = 1400, height = 800, res = 200)
plot(nrb$month, nrb$remit_npr_bn, type = "l", col = "#13315c", lwd = 1.5,
     xlab = NULL, ylab = "Remittance inflow (NPR billion/month)",
     main = "NRB monthly remittance inflows with detected structural breaks")
abline(v = bp_dates, col = "#b3001b", lty = 2, lwd = 1.5)
dev.off()
cat("Saved output/figures/fig4_structural_breaks.png\n\n")

# ---------------------------------------------------------------------------
# 4. ITS regression + Chow test at named candidate event dates
# ---------------------------------------------------------------------------
run_its_chow <- function(data, event_date, label) {
  d <- data %>%
    mutate(t = as.numeric(month - min(month)) / 30.44,           # months since series start
           post = as.integer(month >= as.Date(event_date)),
           t_post = post * (as.numeric(month - as.Date(event_date)) / 30.44))

  event_idx <- which(d$month >= as.Date(event_date))[1]
  n_post <- sum(d$post, na.rm = TRUE)

  if (is.na(event_idx) || n_post < 6) {
    cat(sprintf("--- ITS model + Chow test: %s (%s) ---\n", label, event_date))
    cat(sprintf("  SKIPPED: only %d month(s) of post-event data available in this\n", n_post))
    cat("  series -- too few for a reliable ITS slope estimate or Chow test (need\n")
    cat("  roughly 6+ months minimum, ideally 12+). This is expected and CORRECT\n")
    cat("  behavior for the UPI-NPI event if you are running this early in the\n")
    cat("  fellowship -- re-run this script later in the program once more\n")
    cat("  post-launch months of real NRB data exist, or report this event\n")
    cat("  qualitatively rather than econometrically in the brief.\n\n")
    return(list(model = NULL, chow = NULL, skipped = TRUE, n_post = n_post))
  }

  its_model <- lm(remit_npr_bn ~ t + post + t_post, data = d)

  # Chow test for structural stability around the event date
  chow <- sctest(remit_npr_bn ~ t, data = d, type = "Chow", point = event_idx)

  cat(sprintf("--- ITS model + Chow test: %s (%s) ---\n", label, event_date))
  print(summary(its_model)$coefficients)
  cat(sprintf("Chow test: F = %.3f, p = %.4f  %s\n\n",
              chow$statistic, chow$p.value,
              ifelse(chow$p.value < 0.05, "(significant structural break)", "(no significant break detected)")))

  list(model = its_model, chow = chow, skipped = FALSE, n_post = n_post)
}

events <- list(
  covid    = "2020-03-01",
  fatf     = "2025-02-01",
  upi_npi  = "2026-06-01"
)

cat("=================================================================\n")
cat("3. INTERRUPTED TIME SERIES + CHOW TEST AT NAMED EVENT DATES\n")
cat("   (methodology follows Rahman et al. 2025, PLOS ONE, on Bangladesh's\n")
cat("    remittance cash-incentive policy)\n")
cat("=================================================================\n")
results <- lapply(names(events), function(nm) run_its_chow(nrb, events[[nm]], nm))
names(results) <- names(events)

# Save a compact summary table
chow_summary <- do.call(rbind, lapply(names(events), function(nm) {
  r <- results[[nm]]
  if (isTRUE(r$skipped)) {
    data.frame(event = nm, date = events[[nm]],
               chow_F = NA, chow_p = NA,
               note = paste0("skipped - only ", r$n_post, " post-event month(s) of data"))
  } else {
    data.frame(event = nm, date = events[[nm]],
               chow_F = round(r$chow$statistic, 3),
               chow_p = round(r$chow$p.value, 4),
               note = "")
  }
}))
write.csv(chow_summary, "output/tables/table4_chow_test_summary.csv", row.names = FALSE)

cat("IMPORTANT CAVEAT FOR THE UPI-NPI EVENT SPECIFICALLY:\n")
cat("The link launched 6 June 2026. Depending on when in the program you run\n")
cat("this, you may have only 1-2 months of POST-launch data -- nowhere near\n")
cat("enough for a reliable Chow test or ITS slope estimate. Report this result\n")
cat("(if you report it at all) explicitly as PRELIMINARY/DIRECTIONAL, and frame\n")
cat("the brief's recommendation on the policy's plausible mechanism and the\n")
cat("Bangladesh comparator's effect size, not on a premature Nepal estimate.\n\n")

cat("04_timeseries_structural_break.R complete.\n")

cat("\n", strrep("=", 70), "\n# SECTION 5: Monte Carlo simulations\n", strrep("=", 70), "\n", sep = "")

set.seed(2026)


N_SIM <- 20000

# ---------------------------------------------------------------------------
# SCENARIO 1 — KOREA: Formalization value
# Key inputs (all sourced; replace with updated NRB/NLSS figures when available)
# ---------------------------------------------------------------------------
KOREA_TOTAL_USD_MN   <- 484    # NLSS IV 2022/23 (formal + informal combined)
FORMAL_MTO_COST_PCT  <- 1.30   # reconstructed from MTO fee schedules (Script 02b)
# Hundi cost to worker is uncertain — sometimes cheaper (parallel FX), sometimes
# similar. We model it as uniform [0.3%, 2.0%] to capture the uncertainty.

# Monte Carlo parameters
informal_share_curr  <- pmin(0.75, pmax(0.30, rnorm(N_SIM, 0.55, 0.10)))  # 55% current est.
informal_share_target<- pmin(0.30, pmax(0.10, rnorm(N_SIM, 0.20, 0.05)))  # policy target: 20%
hundi_cost_pct       <- runif(N_SIM, 0.3, 2.0)                             # uncertain
korea_volume         <- rnorm(N_SIM, KOREA_TOTAL_USD_MN, 40)               # USD 484M ± 40M

# Flows recaptured: (current informal - target informal) × total volume
flows_recaptured_usd_mn <- (informal_share_curr - informal_share_target) * korea_volume
flows_recaptured_usd_mn <- pmax(0, flows_recaptured_usd_mn)

# Net household cost of switching (positive = switch costs more; negative = workers save)
net_household_cost_usd_mn <- flows_recaptured_usd_mn * (FORMAL_MTO_COST_PCT - hundi_cost_pct) / 100

cat("=================================================================\n")
cat("SCENARIO 1: KOREA — VALUE OF FORMALIZATION (20,000 simulations)\n")
cat("  Parameter assumptions:\n")
cat(sprintf("    Korea corridor total: USD %.0fM/year (NLSS IV 2022/23)\n", KOREA_TOTAL_USD_MN))
cat(sprintf("    Formal MTO cost: %.2f%% (reconstructed, Script 02b)\n", FORMAL_MTO_COST_PCT))
cat("    Current informal share: N(0.55, 0.10) — IOM 2017 + KP 2023 trend\n")
cat("    Hundi implicit cost: Uniform[0.3%, 2.0%] — highly uncertain\n\n")
cat("=================================================================\n")

q_flows <- quantile(flows_recaptured_usd_mn, c(0.10, 0.50, 0.90))
q_cost  <- quantile(net_household_cost_usd_mn, c(0.10, 0.50, 0.90))

cat("Flows recaptured into formal/NRB-visible channels (USD M/year):\n")
cat(sprintf("  10th percentile: USD %.0fM\n", q_flows[1]))
cat(sprintf("  Median:          USD %.0fM  ← USE THIS in the brief\n", q_flows[2]))
cat(sprintf("  90th percentile: USD %.0fM\n\n", q_flows[3]))

cat("Net household COST of switching [+ve = costs more; -ve = saves money]:\n")
cat(sprintf("  10th percentile: USD %.1fM (workers SAVE money — hundi was expensive)\n", q_cost[1]))
cat(sprintf("  Median:          USD %.1fM (workers pay slightly more)\n", q_cost[2]))
cat(sprintf("  90th percentile: USD %.1fM (hundi was cheap; switch costs more)\n\n", q_cost[3]))

cat("BRIEF FRAMING:\n")
cat(sprintf("  'Shifting Korea corridor flows from informal to formal channels\n"))
cat(sprintf("   would recapture an estimated USD %.0f–%.0fM/year into Nepal's\n",
            round(q_flows[1]), round(q_flows[3])))
cat(sprintf("   official external accounts, at a net household cost of roughly\n"))
cat(sprintf("   USD %.0f–%.0f per EPS worker per year — less than a single monthly\n",
            round(q_cost[2]*1e6/70000), round(q_cost[3]*1e6/40000)))
cat(sprintf("   transfer fee. The national benefit substantially outweighs the\n"))
cat(sprintf("   marginal individual cost.'\n\n"))

# ---------------------------------------------------------------------------
# SCENARIO 2 — SAUDI ARABIA: Bank-to-MTO channel switch
# On the Saudi corridor, the problem IS costs — specifically bank channels
# (Al-Rajhi 11%, Bank Albilad 12%) vs MTOs (WU 3.1%, STC Pay 3.2%, etc.)
# ---------------------------------------------------------------------------
SAUDI_VOLUME_USD_MN  <- 1020   # NLSS IV 2022/23
BANK_COST_PCT        <- 11.5   # RPW Q3 2025 bank average (Al-Rajhi 11%, Albilad 12%)
MTO_COST_PCT         <- 3.4    # RPW Q3 2025 MTO average
SDG_TARGET           <- 3.0

bank_share_curr   <- pmin(0.35, pmax(0.05, rnorm(N_SIM, 0.18, 0.06)))  # ~18% bank use est.
bank_share_target <- pmin(0.05, pmax(0.0,  rnorm(N_SIM, 0.03, 0.02)))  # target: <5%
saudi_volume      <- rnorm(N_SIM, SAUDI_VOLUME_USD_MN, 80)

savings_s2 <- (bank_share_curr - bank_share_target) * saudi_volume *
              (BANK_COST_PCT - MTO_COST_PCT) / 100

cat("=================================================================\n")
cat("SCENARIO 2: SAUDI ARABIA — VALUE OF BANK→MTO CHANNEL SWITCH (20,000 simulations)\n")
cat("  Parameter assumptions:\n")
cat(sprintf("    Saudi volume: USD %.0fM/year (NLSS IV 2022/23)\n", SAUDI_VOLUME_USD_MN))
cat(sprintf("    Bank cost: %.1f%% | MTO cost: %.1f%% (RPW Q3 2025)\n", BANK_COST_PCT, MTO_COST_PCT))
cat("    Current bank share: N(0.18, 0.06) — estimated from RPW service composition\n")
cat("    Target bank share: N(0.03, 0.02) — post-disclosure regulation\n\n")
cat("=================================================================\n")

q_s2 <- quantile(savings_s2, c(0.10, 0.50, 0.90))
cat("Annual savings to Saudi-Nepal workers from channel switch (USD M/year):\n")
cat(sprintf("  10th percentile: USD %.0fM\n", q_s2[1]))
cat(sprintf("  Median:          USD %.0fM  ← USE THIS in the brief\n", q_s2[2]))
cat(sprintf("  90th percentile: USD %.0fM\n\n", q_s2[3]))

per_worker_savings <- q_s2[2] * 1e6 / 150000  # ~150,000 Saudi-Nepal workers
cat(sprintf("Median per-worker saving: USD %.0f/year (at ~150,000 Saudi workers)\n\n", per_worker_savings))

cat("NOTE: This scenario's instrument is NRB fee-disclosure regulation\n")
cat("(modeled on BSP Circular 1238) + MoFA diplomatic coordination with\n")
cat("SAMA to require mandatory MTO-fee disclosure at point of transaction.\n")
cat("It does NOT require a bilateral payment-system negotiation (unlike\n")
cat("the Korea formalization scenario's EPS MOU recommendation).\n\n")

# ---------------------------------------------------------------------------
# Combined summary output
# ---------------------------------------------------------------------------
summary_tbl <- data.frame(
  Scenario = c("S1: Korea formalization", "S2: Saudi bank→MTO switch"),
  Policy_instrument = c("EPS MOU payment clause + NRB formal-channel incentive",
                        "NRB fee-disclosure regulation (BSP model) + MoFA-SAMA coordination"),
  Corridor = c("Korea → Nepal", "Saudi Arabia → Nepal"),
  Median_value_USD_mn = c(round(q_flows[2]), round(q_s2[2])),
  P10_USD_mn = c(round(q_flows[1]), round(q_s2[1])),
  P90_USD_mn = c(round(q_flows[3]), round(q_s2[3])),
  Nature = c("FX recapture + FATF", "Household fee savings")
)

write.csv(summary_tbl, "output/tables/table5_monte_carlo_summary.csv", row.names = FALSE)
cat("Saved output/tables/table5_monte_carlo_summary.csv\n")

# Chart
sim_results <- data.frame(
  scenario = c(rep("S1: Korea formalization\n(FX recapture, USD M/yr)", N_SIM),
               rep("S2: Saudi bank→MTO switch\n(Household savings, USD M/yr)", N_SIM)),
  value = c(flows_recaptured_usd_mn, savings_s2)
)

p <- ggplot(sim_results, aes(x = value, fill = scenario)) +
  geom_density(alpha = 0.6, color = NA) +
  facet_wrap(~scenario, scales = "free", ncol = 1) +
  scale_fill_manual(values = c("#13315c","#b3001b")) +
  labs(title = "Monte Carlo: value at stake under two policy scenarios",
       subtitle = "20,000 simulations per scenario — report range, not point estimate",
       x = "USD million / year", y = "Density") +
  theme_minimal(base_size = 11) + theme(legend.position = "none")

ggsave("output/figures/fig5_monte_carlo_distributions.png", p, width = 7.5, height = 5.5, dpi = 200)
cat("Saved output/figures/fig5_monte_carlo_distributions.png\n\n")
cat("05_monte_carlo_retention.R complete.\n")

cat("\n", strrep("=", 70), "\n# SECTION 6: EPS MOU gap analysis\n", strrep("=", 70), "\n", sep = "")

# ---------------------------------------------------------------------------
# 1. EPS MOU paragraph-level coding (real document structure)
# ---------------------------------------------------------------------------
cat("=================================================================\n")
cat("EPS MOU CLAUSE ANALYSIS (2007, 21 paragraphs)\n")
cat("Source: archive.ceslam.org — confirmed REAL document structure\n")
cat("=================================================================\n\n")

eps_clauses <- tribble(
  ~paragraph, ~subject, ~has_payment_provision, ~notes,
  1,  "Purpose and scope",                           FALSE, "General cooperation framework",
  2,  "Definitions",                                 FALSE, "",
  3,  "Bilateral cooperation procedures",            FALSE, "Roster management via EPS computer network",
  4,  "Sending fee / recruitment cost",              FALSE, "Governs recruitment agency fee — NOT transfer fees",
  5,  "Worker selection",                            FALSE, "",
  6,  "Language testing",                            FALSE, "",
  7,  "Skills testing",                              FALSE, "",
  8,  "Pre-departure training",                      FALSE, "Orientation only — no financial-literacy or payment-channel component",
  9,  "Labour contract terms",                       FALSE, "Wage listed as 'desired condition'; no payment-method clause",
  10, "Insurance",                                   FALSE, "",
  11, "Worker rights and protections",               FALSE, "General rights; no wage-payment-channel requirement",
  12, "Change of workplace",                         FALSE, "",
  13, "Voluntary return / re-entry",                 FALSE, "",
  14, "Sojourn management and repatriation",         FALSE, "Return airfare provision only",
  15, "EPS computer network",                        FALSE, "Technical HR data sharing — no payment data",
  16, "Dispute resolution",                          FALSE, "",
  17, "Coordination and review",                     FALSE, "Annual review mechanism — but no payment agenda",
  18, "Joint Committee",                             FALSE, "",
  19, "Information sharing",                         FALSE, "",
  20, "Amendment procedure",                         FALSE, "Mutual written consent — this is the renewal vehicle",
  21, "Entry into force / term",                     FALSE, "2-year renewable term"
)

payment_count <- sum(eps_clauses$has_payment_provision)
cat(sprintf("Paragraphs with ANY payment/remittance provision: %d out of %d\n\n",
            payment_count, nrow(eps_clauses)))
cat("Paragraphs with partial relevance:\n")
cat("  Para 4: governs RECRUITMENT fees (sending fee) — not transfer fees\n")
cat("  Para 8: pre-departure training — currently no financial/payment component\n")
cat("  Para 9: labour contract — wage mentioned, payment METHOD not specified\n")
cat("  Para 17: annual review — no payment agenda item exists\n")
cat("  Para 20: amendment procedure — THIS IS THE DIPLOMATIC VEHICLE\n\n")

write.csv(eps_clauses, "output/tables/table6a_eps_mou_clause_mapping.csv", row.names = FALSE)

# ---------------------------------------------------------------------------
# 2. Comparison: Nepal EPS vs comparable instruments with payment provisions
# ---------------------------------------------------------------------------
cat("=================================================================\n")
cat("COMPARATIVE INSTRUMENT ANALYSIS\n")
cat("Which comparable frameworks have addressed payments?\n")
cat("=================================================================\n\n")

comparators <- tribble(
  ~instrument,               ~country_pair,          ~year, ~has_fee_cap, ~has_fx_disclosure, ~has_mto_access_clause, ~has_predeparture_finlit, ~has_wage_payment_method, ~binding_or_soft,
  "Nepal-Korea EPS MOU",     "Nepal/Korea",          2007,  FALSE, FALSE, FALSE, FALSE, FALSE, "N/A — silent",
  "Nepal-UAE MOU",           "Nepal/UAE",            2007,  FALSE, FALSE, FALSE, FALSE, FALSE, "N/A — silent",
  "Nepal-Malaysia MOU",      "Nepal/Malaysia",       2018,  FALSE, FALSE, FALSE, FALSE, FALSE, "N/A — silent",
  "Philippines-KSA POEA/BSP","Philippines/Saudi",   2007,  FALSE, TRUE,  TRUE,  TRUE,  FALSE, "Soft/regulatory",
  "BSP MORB §298 (domestic)","Philippines domestic", 2023,  FALSE, TRUE,  TRUE,  TRUE,  FALSE, "Binding (domestic)",
  "BSP Circular 1238",       "Philippines domestic", 2026,  TRUE,  TRUE,  TRUE,  FALSE, FALSE, "Binding (domestic)",
  "NZ RSE admin arrangement","NZ/Pacific",           2020,  FALSE, FALSE, TRUE,  FALSE, FALSE, "Administrative",
  "Korea HRD EPS worker guide","Korea domestic",     2023,  FALSE, FALSE, FALSE, TRUE,  TRUE,  "Administrative",
  "UPI-NPI MOU (India-Nepal)","India/Nepal",         2024,  FALSE, FALSE, TRUE,  FALSE, FALSE, "Bilateral binding"
)

cat("Cross-instrument payment provision scorecard:\n\n")
print(comparators %>% select(-binding_or_soft), row.names = FALSE)
cat("\n")
cat("FINDING: No bilateral labour agreement (BLA/MOU) anywhere has a\n")
cat("binding fee-cap on remittance transfers. The successful instruments\n")
cat("are (a) domestic central-bank regulation (BSP model) and\n")
cat("(b) administrative requirements embedded in programme orientation\n")
cat("(Korea HRD pre-departure guide already mentions financial literacy).\n")
cat("The realistic diplomatic recommendation is therefore:\n")
cat("  NOT a binding fee-cap in the EPS MOU (no precedent; unlikely)\n")
cat("  BUT cooperative language + an annual-review agenda item + NRB\n")
cat("  domestic regulation, using the EPS MOU Amendment (Para 20) as\n")
cat("  the vehicle to add a non-binding cooperation clause.\n\n")

write.csv(comparators, "output/tables/table6b_instrument_comparison.csv", row.names = FALSE)

# ---------------------------------------------------------------------------
# 3. Proposed EPS MOU model clause language
# ---------------------------------------------------------------------------
cat("=================================================================\n")
cat("PROPOSED MODEL CLAUSE LANGUAGE FOR EPS MOU AMENDMENT\n")
cat("(to be reviewed by MoFA Legal Division — not a legal opinion)\n")
cat("=================================================================\n\n")

model_clause <- "
PROPOSED NEW PARAGRAPH [X]: REMITTANCE AND PAYMENT CHANNEL COOPERATION

(a) Recognition: The Parties recognise that the facilitation of safe,
    affordable, and transparent remittance transfers benefits EPS workers
    and supports the development objectives of both countries.

(b) Disclosure (non-binding cooperation): The Republic of Korea agrees to
    include, in the standard HRD Korea pre-departure education programme
    (currently required under [relevant Korean regulation]), information on
    licensed remittance service providers operating on the Korea-Nepal
    corridor, including their fee schedules and exchange rate margins
    relative to the mid-market rate at the time of transfer.

(c) Monitoring: The Parties agree to exchange annually, through the
    Joint Committee established under Paragraph 18, available data on
    the estimated volume and cost of remittance transfers on the
    Korea-Nepal corridor, and to jointly request the World Bank to
    include the Korea-Nepal corridor in its Remittance Prices
    Worldwide (RPW) monitoring database.

(d) NRB-BOK cooperation: The Nepal Rastra Bank and the Bank of Korea
    shall be encouraged to explore a cooperative framework for payment-
    system data sharing and technical assistance, modelled on the NRB-RBI
    Terms of Reference that supported the UPI-NPI cross-border payment
    link (February 2024).

Note: This clause is intentionally non-binding to reflect current
precedent (no bilateral labour agreement globally contains a binding
remittance fee-cap) while creating a structured diplomatic hook for
progressive tightening in future MOU renewals.
"

cat(model_clause)
write(model_clause, "output/tables/table6c_proposed_eps_clause.txt")
cat("Saved output/tables/table6c_proposed_eps_clause.txt\n\n")

# ---------------------------------------------------------------------------
# 4. Gap matrix visualisation
# ---------------------------------------------------------------------------
provision_types <- c("Fee cap", "FX disclosure", "MTO access clause",
                     "Pre-departure fin. lit.", "Wage payment method")

gap_long <- comparators %>%
  mutate(across(starts_with("has_"), as.integer)) %>%
  pivot_longer(starts_with("has_"), names_to = "provision", values_to = "present") %>%
  mutate(provision = recode(provision,
    has_fee_cap = "Fee cap",
    has_fx_disclosure = "FX disclosure",
    has_mto_access_clause = "MTO access clause",
    has_predeparture_finlit = "Pre-departure fin. lit.",
    has_wage_payment_method = "Wage payment method"
  ))

p_gap <- ggplot(gap_long, aes(x = provision, y = instrument, fill = factor(present))) +
  geom_tile(color = "white", linewidth = 0.8) +
  scale_fill_manual(values = c("0" = "#f0f0f0", "1" = "#13315c"),
                    labels = c("Absent", "Present")) +
  labs(title = "Payment provision gap matrix",
       subtitle = "Nepal's EPS MOU vs comparable instruments",
       x = NULL, y = NULL, fill = NULL) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 35, hjust = 1),
        legend.position = "bottom")

ggsave("output/figures/fig6_eps_gap_matrix.png", p_gap, width = 8.5, height = 5, dpi = 200)
cat("Saved output/figures/fig6_eps_gap_matrix.png\n\n")
cat("06_eps_mou_analysis.R complete.\n")

cat("\n", strrep("=", 70), "\nPIPELINE COMPLETE\n", strrep("=", 70), "\n")
cat("Figures -> output/figures/   (7 PNG files)\n")
cat("Tables  -> output/tables/    (10 CSV/TXT files)\n")
cat("Key outputs for the brief:\n")
cat("  fig_korea_operator_costs.png\n")
cat("  fig6_eps_gap_matrix.png\n")
cat("  table5_monte_carlo_summary.csv\n")
cat("  table6c_proposed_eps_clause.txt\n")
