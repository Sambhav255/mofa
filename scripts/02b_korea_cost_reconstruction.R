# ============================================================================
# 02b_korea_cost_reconstruction.R
# ============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

dir.create("output/tables",  showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

KOREA_FILE <- if (exists("USE_REAL_DATA") && isTRUE(USE_REAL_DATA)) {
  "data/raw/korea_mto_fees_real.csv"
} else {
  "data/raw/korea_mto_fees_demo.csv"
}

korea <- read.csv(KOREA_FILE, stringsAsFactors = FALSE)
korea$collection_date <- as.Date(korea$collection_date)
if ("serves_nepal" %in% names(korea)) {
  korea <- korea %>% filter(serves_nepal == TRUE | is.na(serves_nepal))
}

rpw <- read.csv("data/processed/rpw_panel_clean.csv", stringsAsFactors = FALSE)
rpw$quarter_date <- as.Date(rpw$quarter_date)

n_lower_bound <- sum(is.na(korea$fx_margin_pct) | korea$cost_is_lower_bound %in% TRUE, na.rm = TRUE)

cat("=================================================================\n")
cat("KOREA CORRIDOR COST RECONSTRUCTION\n")
cat(sprintf(
  "NOTE: fx_margin_pct is blank for %d operators — total_cost_pct reflects\n",
  n_lower_bound
))
cat("      flat fee only (lower bound). Do not cite as final cost estimate.\n")
cat("=================================================================\n\n")

# Gulf average FX margin — Nepal corridors, latest quarter (Q3 2025)
latest_q <- max(rpw$quarter_date)
gulf_avg_fx_margin <- rpw %>%
  filter(receiving_country == "Nepal", quarter_date == latest_q, !is.na(fx_margin_pct)) %>%
  summarise(avg = mean(fx_margin_pct, na.rm = TRUE)) %>%
  pull(avg)
cat(sprintf("gulf_avg_fx_margin (Nepal corridors, %s): %.3f%%\n\n",
            format(latest_q, "%Y-%m"), gulf_avg_fx_margin))

NPR_PER_USD <- 134.5
FX_BENCHMARK_KRW_NPR <- if ("fx_benchmark_krw_npr" %in% names(korea)) korea$fx_benchmark_krw_npr[1] else 0.0982839
KRW_PER_USD <- NPR_PER_USD / FX_BENCHMARK_KRW_NPR
cat(sprintf("Implied KRW/USD: %.1f\n\n", KRW_PER_USD))

korea_500k <- korea %>%
  filter(transfer_krw == 500000) %>%
  mutate(
    total_cost_pct_adjusted = total_cost_pct + gulf_avg_fx_margin,
    total_cost_pct_range = ifelse(
      is.na(total_cost_pct),
      NA_character_,
      sprintf("%.2f–%.2f%%", total_cost_pct, total_cost_pct + gulf_avg_fx_margin)
    )
  ) %>%
  arrange(total_cost_pct)

korea_1m <- korea %>%
  filter(transfer_krw == 1000000) %>%
  mutate(
    total_cost_pct_adjusted = total_cost_pct + gulf_avg_fx_margin,
    total_cost_pct_range = ifelse(
      is.na(total_cost_pct),
      NA_character_,
      sprintf("%.2f–%.2f%%", total_cost_pct, total_cost_pct + gulf_avg_fx_margin)
    )
  ) %>%
  arrange(total_cost_pct)

cat(sprintf("Korea → Nepal cost estimates (KRW 500,000 ≈ USD %d)\n", round(500000 / KRW_PER_USD)))
cat(strrep("-", 55), "\n")
print(korea_500k %>% select(operator, channel_type, total_cost_pct, total_cost_pct_adjusted, total_cost_pct_range),
      row.names = FALSE)

mto_lb <- mean(korea_500k$total_cost_pct[korea_500k$channel_type == "MTO"], na.rm = TRUE)
mto_ub <- mean(korea_500k$total_cost_pct_adjusted[korea_500k$channel_type == "MTO"], na.rm = TRUE)
cat(sprintf("\nMTO average lower bound (fee only):  %.2f%%\n", mto_lb))
cat(sprintf("MTO average upper bound (+ Gulf FX):   %.2f%%\n\n", mto_ub))

write.csv(korea_500k, "output/tables/table_korea_mto_costs_500k.csv", row.names = FALSE)
write.csv(korea_1m,   "output/tables/table_korea_mto_costs_1m.csv",   row.names = FALSE)

gulf_latest <- rpw %>%
  filter(quarter_date == latest_q, receiving_country == "Nepal", !is.na(mto_cost_pct)) %>%
  transmute(
    corridor = paste(sending_country, "→ Nepal"),
    rpw_mto_cost_pct = mto_cost_pct
  )

comparison <- tibble(
  corridor = "Korea → Nepal",
  korea_lower_bound_pct = mto_lb,
  korea_upper_bound_pct = mto_ub,
  rpw_mto_cost_pct = NA_real_
) %>%
  bind_rows(
    gulf_latest %>% mutate(
      korea_lower_bound_pct = NA_real_,
      korea_upper_bound_pct = NA_real_
    ) %>%
      select(corridor, korea_lower_bound_pct, korea_upper_bound_pct, rpw_mto_cost_pct)
  )

cat("CROSS-CORRIDOR COMPARISON (MTO costs, apples-to-apples adjusted)\n")
cat(strrep("-", 55), "\n")
print(comparison, row.names = FALSE)

n_below_ub <- sum(gulf_latest$rpw_mto_cost_pct > mto_ub, na.rm = TRUE)
n_total <- nrow(gulf_latest)
cat("\n*** KEY FINDING ***\n")
cat(sprintf(
  "Korea formal MTO costs range from %.2f%% (fee-only lower bound) to %.2f%% (adding\n",
  mto_lb, mto_ub
))
cat(sprintf(
  " the average Gulf FX margin as a conservative upper bound). Even at the upper\n"
))
cat(sprintf(
  " bound, Korea MTO costs remain below %d of %d RPW-covered Nepal corridors.\n\n",
  n_below_ub, n_total
))

write.csv(comparison, "output/tables/table_korea_vs_gulf_comparison.csv", row.names = FALSE)

gulf_mto_avg <- mean(gulf_latest$rpw_mto_cost_pct, na.rm = TRUE)

korea_plot <- korea_500k %>%
  filter(!is.na(total_cost_pct)) %>%
  mutate(
    operator = reorder(operator, total_cost_pct),
    fee_only = total_cost_pct,
    fx_est = gulf_avg_fx_margin
  )

p_korea <- ggplot(korea_plot) +
  geom_col(aes(x = operator, y = fee_only, fill = "Fee only (lower bound)"), width = 0.7) +
  geom_col(aes(x = operator, y = fx_est, fill = "Est. FX margin (Gulf avg)"),
           position = position_stack(), width = 0.7, alpha = 0.45) +
  geom_hline(yintercept = 3.0, linetype = "dashed", color = "#b3001b", linewidth = 0.8) +
  geom_hline(yintercept = gulf_mto_avg, linetype = "dotted", color = "#888888", linewidth = 0.8) +
  annotate("text", x = 0.6, y = 3.15, label = "SDG 10.c target (3%)",
           hjust = 0, size = 2.8, color = "#b3001b") +
  annotate("text", x = 0.6, y = gulf_mto_avg + 0.15,
           label = sprintf("Gulf MTO avg (%.1f%%)", gulf_mto_avg),
           hjust = 0, size = 2.8, color = "#555555") +
  scale_fill_manual(
    name = NULL,
    values = c("Fee only (lower bound)" = "#13315c", "Est. FX margin (Gulf avg)" = "#7fa6c9")
  ) +
  coord_flip() +
  labs(
    title = "Korea → Nepal: Cost range by operator (KRW 500,000)",
    subtitle = "Stacked bars = fee-only lower bound + assumed Gulf-average FX margin",
    x = NULL, y = "Total cost (% of transfer amount)",
    caption = "FX extension uses Nepal Gulf-corridor average FX margin from RPW Q3 2025."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave("output/figures/fig_korea_operator_costs.png", p_korea, width = 8.5, height = 5.5, dpi = 200)
cat("Saved output/figures/fig_korea_operator_costs.png\n\n")
cat("02b_korea_cost_reconstruction.R complete.\n")
