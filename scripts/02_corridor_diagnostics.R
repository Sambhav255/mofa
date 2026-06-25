# ============================================================================
# 02_corridor_diagnostics.R
#
# PURPOSE
#   The core descriptive engine behind the brief's "Analysis" and "Key
#   Findings" sections:
#     (a) Latest-quarter corridor cost table for Nepal, with fee/FX-margin
#         decomposition and the $200-vs-$500 small-transfer penalty
#     (b) Benchmark of Nepal's volume-weighted average against the SDG 10.c
#         3% target and the 5% corridor ceiling
#     (c) Cross-country comparison: Nepal vs Bangladesh vs Pakistan vs
#         Philippines vs India, controlling for corridor composition
#     (d) Time trend chart: Nepal corridor costs since 2011 vs SDG target
#
#   Every table/figure here is written to output/tables and output/figures
#   with a filename you can reference directly in the brief.
# ============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

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
