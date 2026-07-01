# ============================================================================
# 07_bla_comparative_analysis.R
#
# PURPOSE
#   Comparative gap matrix for Nepal's bilateral labour agreements (BLAs),
#   extending the EPS MOU case study to Gulf, Malaysia, and Japan partners.
#   Korea row is confirmed from pipeline data (published MOU text, clause-
#   coded in 06_eps_mou_analysis.R). Qatar/UAE/Saudi Arabia/Malaysia/Japan/
#   Bahrain/Jordan rows are populated from a July 1, 2026 desk-research pass
#   (see notes column per row) — PROVISIONAL pending independent verification
#   against primary MOU text at archive.ceslam.org/governance/bilateral-
#   arrangements and ilo.org/media/439831/download. Do not cite these rows
#   as "confirmed from primary text" the way the Korea row is until that
#   verification pass happens.
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
  ~partner_country, ~instrument, ~mou_year, ~total_paragraphs, ~remittance_provisions,
  ~payment_channel_clause, ~financial_literacy_clause, ~monitoring_clause, ~amendment_mechanism, ~notes,

  "Korea (EPS)", "MOU (G2G)", 2007L, 21L, FALSE, FALSE, FALSE, FALSE,
    "Paragraph 20",
    "CONFIRMED from published MOU text (06_eps_mou_analysis.R): signed 23 Jul 2007, 21 paragraphs, zero remittance provisions.",

  "Qatar", "Agreement on Nepali Manpower Employment", 2005L, NA_integer_, FALSE, FALSE, FALSE, FALSE,
    "Joint Committee",
    "PROVISIONAL (1 Jul 2026 desk research, primary MOU text not yet independently verified): signed 21 Mar 2005. No remittance or payment-channel clause identified.",

  "UAE", "MOU", 2007L, NA_integer_, FALSE, FALSE, FALSE, FALSE,
    NA_character_,
    "PROVISIONAL (1 Jul 2026 desk research, primary MOU text not yet independently verified): signed 2007. No remittance provisions. Closest clause is 'zero cost' recruitment + transparency language, which is recruitment-cost related, not a remittance/payment-channel clause — coded FALSE.",

  "Saudi Arabia", "Bilateral Labour Agreement", 2026L, NA_integer_, FALSE, TRUE, FALSE, FALSE,
    "Joint Technical Committee",
    "PROVISIONAL (1 Jul 2026 desk research, primary MOU text not yet independently verified): signed 26 Jan 2026 — Nepal's newest BLA. No remittance-cost provisions, but requires salary payment via bank accounts in the worker's own name — the single nearest payment-channel clause found across all Nepal BLAs reviewed in this pass.",

  "Malaysia", "MOU", 2018L, NA_integer_, FALSE, FALSE, FALSE, FALSE,
    NA_character_,
    "PROVISIONAL (1 Jul 2026 desk research, primary MOU text not yet independently verified): signed 2003, updated 29 Oct 2018. No remittance or payment-channel clause. Strong recruitment-cost obligations (employer-paid) exist but are a recruitment-cost clause, not remittance/payment-channel — coded FALSE.",

  "Japan", "Memorandum of Cooperation (SSW)", 2019L, NA_integer_, FALSE, FALSE, FALSE, FALSE,
    "Information partnership framework",
    "PROVISIONAL (1 Jul 2026 desk research, primary MOU text not yet independently verified): signed 25 Mar 2019, updated 1 Jan 2024. No remittance, payment-channel, financial-literacy, or monitoring clause identified.",

  "Bahrain", "MOU", 2008L, NA_integer_, FALSE, FALSE, FALSE, FALSE,
    NA_character_,
    "PROVISIONAL (1 Jul 2026 desk research, primary MOU text not yet independently verified): signed 2008. No remittance or payment-channel clause identified.",

  "Jordan", "General Agreement in the Field of Manpower", 2017L, NA_integer_, FALSE, FALSE, FALSE, FALSE,
    NA_character_,
    "PROVISIONAL (1 Jul 2026 desk research, primary MOU text not yet independently verified): signed 18 Oct 2017. No remittance or payment-channel clause identified."
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
  "The remaining seven rows (Qatar, UAE, Saudi Arabia, Malaysia, Japan, Bahrain,",
  "Jordan) were populated from a 1 July 2026 desk-research pass and are PROVISIONAL —",
  "primary MOU text has not yet been independently verified against",
  "archive.ceslam.org/governance/bilateral-arrangements or the ILO bilateral",
  "agreements study (ilo.org/media/439831/download). Do not cite these seven rows",
  "with the same confidence as the Korea row until that verification happens.",
  "Finding across all eight instruments reviewed: zero have a remittance-cost or",
  "remittance-disclosure provision. The Saudi Arabia BLA (26 Jan 2026, Nepal's",
  "newest) is the only one with any payment-channel clause at all — salary must be",
  "paid into a bank account in the worker's own name — which is read as evidence",
  "that Nepal is diplomatically willing to include financial-channel governance in",
  "new agreements, supporting the feasibility case for the proposed EPS clause.",
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
    labels = c("Absent" = "Absent (gap)", "Pending" = "Pending desk research", "Present" = "Present")
  ) +
  labs(
    title = "BLA payment-provision gap matrix",
    subtitle = "8 Nepal bilateral labour agreements — Korea confirmed from MOU text; others provisional (desk research, 1 Jul 2026)",
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
