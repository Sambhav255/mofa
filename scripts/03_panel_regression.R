# ============================================================================
# 03_panel_regression.R
#
# PURPOSE
#   Fixed-effects panel regression of remittance cost on corridor
#   characteristics, replicating (in spirit) the specification used in:
#     - Beck, T. & Martinez Peria, M.S. (2011), "What Determines the Price
#       of Remittances? Evidence from a Cross-Country Series of Surveys",
#       World Bank Economic Review.
#     - Freund, C. & Spatafora, N. (2008), "Remittances, transaction costs,
#       and informality", Journal of Development Economics.
#     - Ardic, O. et al, "Determinants of Remittance Prices: An Econometric
#       Analysis" (BIS CPMI proceedings), which runs this exact regression
#       directly on RPW data with corridor-level controls.
#
#   Two models are estimated:
#     MODEL A (within-Nepal): does competition (num_services) and digital
#       adoption (pct_digital) explain cost variation ACROSS Nepal's own
#       corridors and over time, controlling for corridor and quarter fixed
#       effects? This is the model most directly usable in the brief because
#       every variable is something MoFA can plausibly influence (encourage
#       more RSPs to enter a corridor; push digital adoption).
#
#     MODEL B (cross-country): pooled regression across Nepal + comparators
#       (Bangladesh, Pakistan, Philippines, India), with receiving-country
#       fixed effects, answering: "is Nepal's cost different from
#       comparators AFTER controlling for corridor composition (sending
#       country, competition, digital share)?" -- this is the literature-
#       grounded version of the "Table 2" comparison in script 02, and is
#       the number a skeptical reviewer will trust more.
#
#   Standard errors are clustered by corridor (Beck & Martinez Peria do the
#   same) to avoid overstating significance from within-corridor
#   autocorrelation.
# ============================================================================

suppressMessages({
  library(dplyr)
  library(plm)
  library(lmtest)
  library(sandwich)
  library(broom)
})

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

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
