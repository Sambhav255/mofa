# MoFA Cluster 10 — R Statistical Pipeline
### Remittance-cost diagnostic for "Beyond Aid and FDI"

This project is a **tested, working** R pipeline (every script has been run end-to-end with `Rscript` and produces correct output with no errors) for the quantitative analysis behind the Cluster 10 research brief. It currently runs on **synthetic demo data** calibrated to match the real, sourced figures in the research handbook — so you can trust the code now, and simply swap in real files as they arrive.

## Quick start
```r
# from this folder, in R or RStudio:
source("run_all.R")
```
This generates demo data (if real files aren't present yet), then runs all five analysis scripts in order. Outputs land in `output/tables/` (CSV) and `output/figures/` (PNG).

## What each script does and which part of the brief it feeds

| Script | What it does | Feeds into |
|---|---|---|
| `00_generate_demo_data.R` | Creates synthetic RPW-style and NRB-style data so the pipeline runs before real downloads arrive. **Delete or ignore once real data is in place.** | — |
| `01_load_clean_rpw.R` | Loads, validates, and tidies the corridor-quarter panel. | Data integrity footnote |
| `02_corridor_diagnostics.R` | Fee vs FX-margin decomposition, $200 vs $500 small-transfer penalty, benchmark vs SDG 3%/G20 5%, raw cross-country comparison, time trend chart. | **Analysis** + **Key Findings** sections |
| `03_panel_regression.R` | Fixed-effects panel regression (competition, digital share → cost) and a literature-grounded cross-country regression with Nepal as reference category. | **Analysis** section — the "why" behind the numbers |
| `04_timeseries_structural_break.R` | ADF stationarity test, STL decomposition, endogenous break detection, and an Interrupted-Time-Series + Chow test at named event dates (COVID, FATF grey-listing, UPI–NPI launch). | **Analysis** + supports the "why now" framing |
| `05_monte_carlo_retention.R` | Monte Carlo simulation of the value at stake under (1) cost convergence to 3% and (2) partial formalization of informal flows — reported as a credible range, not a point estimate. | **Key Findings** headline number + **Recommendation** justification |

## Swapping in real data

### RPW corridor data
1. Go to `remittanceprices.worldbank.org/data-download`, submit the access-request form (this is NOT instant — an email with a link follows, so do this in Week 1).
2. Alternative, often faster: `databank.worldbank.org/source/remittance-prices-worldwide-(corridors)` lets you query/export without the request-form step.
3. The bulk file is an Excel workbook with two data sheets (one per send amount: $200 and $500). Reshape to corridor-quarter rows with these exact column names (see the detailed mapping comment at the top of `01_load_clean_rpw.R`):
   `quarter, quarter_date, receiving_country, sending_country, amount_usd, total_cost_pct, fee_pct, fx_margin_pct, total_cost_pct_500, num_services, pct_digital, dominant_service_type`
4. Save as `data/raw/rpw_real.csv`, then change the `RPW_FILE` line at the top of `01_load_clean_rpw.R`.

### NRB monthly series
1. Pull monthly remittance inflow (and FX reserves, labour permits if available) from `nrb.org.np/category/monthly-statistics` (Current Macroeconomic and Financial Situation reports) — these are PDFs; transcribe the relevant table rows into a CSV.
2. Columns needed: `month` (YYYY-MM-01), `remit_npr_bn`, `fx_reserve_usd_bn`, `labor_permits_new`.
3. Save as `data/raw/nrb_remit_monthly_real.csv` and update the `NRB_FILE` line in `04_timeseries_structural_break.R`.

### Weighting corridors by volume (important — currently a placeholder)
`02_corridor_diagnostics.R` currently uses **equal weights** across corridors to compute the "volume-weighted average." This is a placeholder. Replace with real weights from either:
- NRB's own corridor/country breakdown (if published in the annual report), or
- The KNOMAD/World Bank bilateral remittance matrix, now hosted at `data360.worldbank.org/en/indicator/WB_KNOMAD_BRE` (the old knomad.org links largely redirect or are stale — use Data360). **Caveat: the most recent vintage is 2021** — it is a modeled estimate (Ratha–Shaw methodology), not a measured flow, and UN DESA's November 2025 monthly briefing confirms bilateral data are "not available beyond 2021." Say so explicitly wherever you use it.

### Comparator countries (Bangladesh, Pakistan, Philippines, India)
Filter the same RPW bulk file for these `receiving_country` values — no separate source needed.

## Honest limitations to carry into the brief
- The cross-country regression in `03_panel_regression.R` (Model B) runs on a small cross-section (~19 corridors in the demo; likely 40-60+ once you pull the full real RPW corridor set for five countries). Treat p-values as indicative.
- The UPI–NPI event-study in `04` is built to gracefully report "insufficient post-event data" rather than crash — because the link only launched 6 June 2026, you likely will not have enough post-launch months for a real Chow test by the time you draft the brief. Report that event qualitatively (mechanism + the Bangladesh comparator's effect size as a benchmark), not as a Nepal-specific estimated effect, unless you genuinely have 6+ months of post-launch data.
- The Monte Carlo scenarios in `05` depend on assumed parameters (the 20-30% informal-share range, an assumed partial-formalization rate). These are explicitly modeled as *uncertain*, not point facts — keep the credible-range framing in the brief rather than collapsing to a single number.
- KNOMAD/bilateral remittance estimates are themselves modeled, not measured — always triangulate with NRB's own balance-of-payments figures.

## Required R packages
```r
install.packages(c("dplyr","tidyr","ggplot2","readxl","stringr","plm",
                    "lmtest","sandwich","broom","zoo","strucchange",
                    "tseries","forecast"))
```
(All of these were verified to install and run correctly during development of this pipeline.)
