# ============================================================================
# 07_bla_comparative_analysis.R
#
# PURPOSE
#   Comparative gap matrix for Nepal's bilateral labour agreements (BLAs),
#   extending the EPS MOU case study to Gulf, Malaysia, and Japan partners.
#   Korea row is confirmed from pipeline data; other partners are scaffolded
#   for pending desk research (MOU text scan).
#
# INPUTS
#   output/tables/table6b_instrument_comparison.csv (existing comparator table)
#
# OUTPUTS
#   output/tables/table7_bla_comparison.csv
#   output/tables/table7_bla_comparison_notes.txt
#   output/figures/fig8_bla_gap_matrix.png
# ============================================================================

suppressMessages({ library(dplyr); library(tidyr); library(ggplot2); library(readr) })

dir.create("output/tables",  showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# 1. Load existing comparator instrument table (context / cross-check)
# ---------------------------------------------------------------------------
comparators_path <- "output/tables/table6b_instrument_comparison.csv"
if (!file.exists(comparators_path)) {
  stop("Expected ", comparators_path, " — run 06_eps_mou_analysis.R first.")
}
comparators <- read_csv(comparators_path, show_col_types = FALSE)
cat("Loaded", nrow(comparators), "rows from table6b_instrument_comparison.csv\n\n")

# ---------------------------------------------------------------------------
# 2. Nepal BLA comparison table
# ---------------------------------------------------------------------------
nepal_bla_comparison <- tribble(
  ~partner_country, ~mou_year, ~total_paragraphs, ~remittance_provisions,
  ~payment_channel_clause, ~financial_literacy_clause, ~monitoring_clause, ~notes,
  "Korea (EPS)",        2007L, 21L, FALSE, FALSE, FALSE, FALSE,
    "Confirmed: EPS MOU (23 Jul 2007), 21 paragraphs, zero remittance provisions",
  "Gulf (UAE proxy)",   2007L, NA_integer_, NA, NA, NA, NA,
    "# PENDING: desk research — scan MOU text for remittance provisions",
  "Malaysia",           2003L, NA_integer_, NA, NA, NA, NA,
    "# PENDING: desk research — scan MOU text for remittance provisions (updated 2018)",
  "Japan",              NA_integer_, NA_integer_, NA, NA, NA, NA,
    "# PENDING: desk research — scan MOU text for remittance provisions"
)

write.csv(nepal_bla_comparison, "output/tables/table7_bla_comparison.csv", row.names = FALSE)
cat("Saved output/tables/table7_bla_comparison.csv\n\n")

# ---------------------------------------------------------------------------
# 3. Plain-text summary
# ---------------------------------------------------------------------------
summary_text <- paste(
  "This table compares payment-related provisions across Nepal's bilateral labour",
  "agreements (BLAs). The Korea EPS MOU (2007, 21 paragraphs) is fully coded from",
  "the published MOU text: none of the four provision types (remittance disclosure,",
  "payment channel, financial literacy, or cost monitoring) appear in any paragraph.",
  "Rows for Gulf (UAE proxy), Malaysia, and Japan are pending desk research — MOU",
  "text must be scanned to determine whether equivalent clauses exist. The gap",
  "matrix visualisation uses green for present provisions, red for confirmed gaps,",
  "and grey for partners not yet coded.",
  sep = " "
)
write(summary_text, "output/tables/table7_bla_comparison_notes.txt")
cat("Saved output/tables/table7_bla_comparison_notes.txt\n\n")

# ---------------------------------------------------------------------------
# 4. Gap matrix figure (same layout as fig6_eps_gap_matrix)
# ---------------------------------------------------------------------------
provision_cols <- c(
  "remittance_provisions",
  "payment_channel_clause",
  "financial_literacy_clause",
  "monitoring_clause"
)

provision_labels <- c(
  remittance_provisions = "Remittance provisions",
  payment_channel_clause = "Payment channel clause",
  financial_literacy_clause = "Financial literacy clause",
  monitoring_clause = "Monitoring clause"
)

gap_long <- nepal_bla_comparison %>%
  select(partner_country, all_of(provision_cols)) %>%
  pivot_longer(
    cols = all_of(provision_cols),
    names_to = "provision",
    values_to = "present"
  ) %>%
  mutate(
    provision = recode(provision, !!!provision_labels),
    status = case_when(
      is.na(present) ~ "Pending",
      present ~ "Present",
      !present ~ "Absent"
    ),
    status = factor(status, levels = c("Absent", "Pending", "Present"))
  )

p_bla_gap <- ggplot(gap_long, aes(x = provision, y = partner_country, fill = status)) +
  geom_tile(color = "white", linewidth = 0.8) +
  scale_fill_manual(
    values = c("Absent" = "#c0392b", "Pending" = "#b0b0b0", "Present" = "#27ae60"),
    labels = c("Absent (gap)", "Pending desk research", "Present")
  ) +
  labs(
    title = "BLA payment-provision gap matrix",
    subtitle = "Nepal bilateral labour agreements — Korea confirmed; Gulf/Malaysia/Japan pending",
    x = NULL, y = NULL, fill = NULL
  ) +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 35, hjust = 1),
    legend.position = "bottom"
  )

ggsave("output/figures/fig8_bla_gap_matrix.png", p_bla_gap, width = 8, height = 5, dpi = 300)
cat("Saved output/figures/fig8_bla_gap_matrix.png\n\n")
cat("07_bla_comparative_analysis.R complete.\n")
