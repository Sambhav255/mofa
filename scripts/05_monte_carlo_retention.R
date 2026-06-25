# ============================================================================
# 05_monte_carlo_retention.R
# ============================================================================

suppressMessages({ library(dplyr); library(ggplot2) })
set.seed(2026)

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("output/tables",  showWarnings = FALSE, recursive = TRUE)

N_SIM <- 20000

# ---------------------------------------------------------------------------
# SCENARIO 1 — KOREA: Formalization value
# ---------------------------------------------------------------------------
KOREA_TOTAL_USD_MN   <- 484
FORMAL_MTO_COST_PCT  <- 1.30

informal_share_curr  <- pmin(0.75, pmax(0.30, rnorm(N_SIM, 0.55, 0.10)))
informal_share_target<- pmin(0.30, pmax(0.10, rnorm(N_SIM, 0.20, 0.05)))
hundi_cost_pct       <- runif(N_SIM, 0.3, 2.0)
korea_volume         <- rnorm(N_SIM, KOREA_TOTAL_USD_MN, 40)

flows_recaptured_usd_mn <- pmax(0, (informal_share_curr - informal_share_target) * korea_volume)
net_household_cost_usd_mn <- flows_recaptured_usd_mn * (FORMAL_MTO_COST_PCT - hundi_cost_pct) / 100

cat("=================================================================\n")
cat("SCENARIO 1: KOREA — VALUE OF FORMALIZATION (20,000 simulations)\n")
cat("=================================================================\n")
cat(sprintf("  Korea corridor total: USD %.0fM/year (NLSS IV 2022/23)\n", KOREA_TOTAL_USD_MN))
cat(sprintf("  Formal MTO cost: %.2f%%\n", FORMAL_MTO_COST_PCT))
cat("  Current informal share: N(0.55, 0.10) | Target: N(0.20, 0.05)\n")
cat("  Hundi implicit cost: Uniform[0.3%, 2.0%]\n\n")

q_flows <- quantile(flows_recaptured_usd_mn, c(0.10, 0.50, 0.90))
q_cost  <- quantile(net_household_cost_usd_mn, c(0.10, 0.50, 0.90))

cat("Flows recaptured into formal/NRB-visible channels (USD M/year):\n")
cat(sprintf("  10th percentile: USD %.0fM\n", q_flows[1]))
cat(sprintf("  Median:          USD %.0fM\n", q_flows[2]))
cat(sprintf("  90th percentile: USD %.0fM\n\n", q_flows[3]))

cat("Net household COST of switching [+ve = costs more; -ve = saves money]:\n")
cat(sprintf("  10th percentile: USD %.1fM\n", q_cost[1]))
cat(sprintf("  Median:          USD %.1fM\n", q_cost[2]))
cat(sprintf("  90th percentile: USD %.1fM\n\n", q_cost[3]))

# ---------------------------------------------------------------------------
# SCENARIO 2 — SAUDI ARABIA: Bank-to-MTO channel switch
# ---------------------------------------------------------------------------
SAUDI_VOLUME_USD_MN  <- 1020
BANK_COST_PCT_OLD    <- 11.5
MTO_COST_PCT_OLD     <- 3.4
BANK_COST_PCT        <- BANK_COST_PCT_OLD
MTO_COST_PCT         <- MTO_COST_PCT_OLD

rpw_path <- if (file.exists("data/raw/rpw_real.csv")) "data/raw/rpw_real.csv" else "data/processed/rpw_panel_clean.csv"
if (file.exists(rpw_path)) {
  rpw_mc <- read.csv(rpw_path, stringsAsFactors = FALSE)
  saudi_q3 <- rpw_mc %>%
    filter(receiving_country == "Nepal", sending_country == "Saudi Arabia",
           quarter %in% c("2025Q3", "2025_3Q"), amount_usd == 200)
  if (nrow(saudi_q3) >= 1) {
    BANK_COST_PCT <- saudi_q3$bank_cost_pct[1]
    MTO_COST_PCT  <- saudi_q3$mto_cost_pct[1]
    if (is.na(BANK_COST_PCT)) BANK_COST_PCT <- BANK_COST_PCT_OLD
    if (is.na(MTO_COST_PCT))  MTO_COST_PCT  <- MTO_COST_PCT_OLD
    cat(sprintf("BANK_COST_PCT: old=%.2f new=%.2f (Saudi→Nepal Q3 2025, RPW $200)\n",
                BANK_COST_PCT_OLD, BANK_COST_PCT))
    cat(sprintf("MTO_COST_PCT:  old=%.2f new=%.2f (Saudi→Nepal Q3 2025, RPW $200)\n",
                MTO_COST_PCT_OLD, MTO_COST_PCT))
  }
}
cat("\n")

bank_share_curr   <- pmin(0.35, pmax(0.05, rnorm(N_SIM, 0.18, 0.06)))
bank_share_target <- pmin(0.05, pmax(0.0,  rnorm(N_SIM, 0.03, 0.02)))
saudi_volume      <- rnorm(N_SIM, SAUDI_VOLUME_USD_MN, 80)

savings_s2 <- (bank_share_curr - bank_share_target) * saudi_volume *
              (BANK_COST_PCT - MTO_COST_PCT) / 100

cat("=================================================================\n")
cat("SCENARIO 2: SAUDI ARABIA — VALUE OF BANK→MTO CHANNEL SWITCH (20,000 simulations)\n")
cat("=================================================================\n")
cat(sprintf("  Saudi volume: USD %.0fM/year\n", SAUDI_VOLUME_USD_MN))
cat(sprintf("  Bank cost: %.1f%% | MTO cost: %.1f%% (RPW Q3 2025)\n", BANK_COST_PCT, MTO_COST_PCT))
cat("  Current bank share: N(0.18, 0.06) | Target: N(0.03, 0.02)\n\n")

q_s2 <- quantile(savings_s2, c(0.10, 0.50, 0.90))

cat("Annual savings to Saudi-Nepal workers from channel switch (USD M/year):\n")
cat(sprintf("  10th percentile: USD %.0fM\n", q_s2[1]))
cat(sprintf("  Median:          USD %.0fM\n", q_s2[2]))
cat(sprintf("  90th percentile: USD %.0fM\n\n", q_s2[3]))

# ---------------------------------------------------------------------------
# TALL summary table (one row per scenario × metric)
# ---------------------------------------------------------------------------
summary_tbl <- bind_rows(
  data.frame(
    scenario = "S1: Korea formalization",
    metric = "flows_recaptured_usd_mn",
    p10 = round(q_flows[1], 1), median = round(q_flows[2], 1), p90 = round(q_flows[3], 1),
    unit = "USD million/year", stringsAsFactors = FALSE
  ),
  data.frame(
    scenario = "S1: Korea formalization",
    metric = "net_household_cost_usd_mn",
    p10 = round(q_cost[1], 1), median = round(q_cost[2], 1), p90 = round(q_cost[3], 1),
    unit = "USD million/year", stringsAsFactors = FALSE
  ),
  data.frame(
    scenario = "S2: Saudi bank→MTO switch",
    metric = "household_savings_usd_mn",
    p10 = round(q_s2[1], 1), median = round(q_s2[2], 1), p90 = round(q_s2[3], 1),
    unit = "USD million/year", stringsAsFactors = FALSE
  )
)

cat("TABLE 5 SUMMARY (tall format):\n")
print(summary_tbl, row.names = FALSE)
cat("\n")

write.csv(summary_tbl, "output/tables/table5_monte_carlo_summary.csv", row.names = FALSE)
cat("Saved output/tables/table5_monte_carlo_summary.csv\n")

sim_results <- data.frame(
  scenario = c(rep("S1: Korea formalization\n(FX recapture, USD M/yr)", N_SIM),
               rep("S2: Saudi bank→MTO switch\n(Household savings, USD M/yr)", N_SIM)),
  value = c(flows_recaptured_usd_mn, savings_s2)
)

p <- ggplot(sim_results, aes(x = value, fill = scenario)) +
  geom_density(alpha = 0.6, color = NA) +
  facet_wrap(~scenario, scales = "free", ncol = 1) +
  scale_fill_manual(values = c("#13315c", "#b3001b")) +
  labs(title = "Monte Carlo: value at stake under two policy scenarios",
       subtitle = "20,000 simulations per scenario — report range, not point estimate",
       x = "USD million / year", y = "Density") +
  theme_minimal(base_size = 11) + theme(legend.position = "none")

ggsave("output/figures/fig5_monte_carlo_distributions.png", p, width = 7.5, height = 5.5, dpi = 200)
cat("Saved output/figures/fig5_monte_carlo_distributions.png\n\n")
cat("05_monte_carlo_retention.R complete.\n")
