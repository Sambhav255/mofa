# MoFA Cluster 10 — R Statistical Pipeline
### Measuring the Invisible: The Korea EPS Corridor as a Case for Remittance Provisions in Nepal's Bilateral Labour Agreements

MoFA Nepal Summer Internship 2026 · Cluster 10: Development Finance and Investment Diplomacy

This repo is the **replication-ready** R pipeline behind a policy brief for Nepal's Ministry
of Foreign Affairs. It quantifies remittance costs on Nepal's labour-migration corridors —
using **Korea (EPS)** as the case study and the **Gulf corridors** as comparators — and turns
that evidence into a concrete recommendation: what payment-related provisions Nepal should
embed in its bilateral labour agreements (BLAs).

The pipeline is **11 scripts, run in order**, that go from raw source data (World Bank RPW
Excel, NRB PDF reports, Korea MTO fee schedules, EPS MOU text) to the tables and figures cited
in `mofa_pipeline_report.Rmd`, which renders to a PDF policy brief.

---

## Research question (locked June 25, 2026)

**What payment-related provisions should Nepal embed in its bilateral labour agreements to
reduce remittance costs and establish formal cost monitoring, and what does the Korea EPS
corridor reveal about the diplomatic case for doing so?**

Korea is the **case study**, not one of several co-equal corridors. Gulf comparators supply
benchmark context; the three resulting recommendations are meant to generalise to all of
Nepal's BLA partners (Gulf, Malaysia, Japan). This framing replaced an earlier, broader
five-corridor comparison — see `docs/TOPIC_FINALIZATION_PROMPT.md` and
`docs/cursor_consolidate_r_project_files.md` for that history if it's ever relevant again.

---

## What has been done

### 1. Data collection
- **World Bank Remittance Prices Worldwide (RPW)**, full 2011–Q3 2025 firm-level dataset
  (`data/raw/rpw_dataset_2011_2025_q3.xlsx`, 50MB) — reshaped into a corridor-quarter panel.
  **Finding:** RPW has no Korea→Nepal corridor in any quarter — the World Bank simply doesn't
  track this corridor, which is itself part of the "invisible corridor" argument in the brief.
- **NRB monthly series** — remittance inflows, FX reserves, labour permits — scraped from
  Nepal Rastra Bank's "Current Macroeconomic and Financial Situation" PDF reports
  (`scripts/00c_ingest_nrb_real.R` fetches missing PDFs live, up to a per-run cap). Coverage
  is a scatter of 13 report-cutoff months (FY2021/22–FY2025/26), not yet a continuous series —
  see `docs/README_data_notes.md` for exactly which fields are extracted vs. computed.
- **Korea MTO operator fees** — hand-collected flat transfer fees (KRW) for 9 Korean money
  transfer operators serving the Nepal corridor (Rupeesend, Hanpass, GME, WireBarley, etc.),
  `data/raw/collected/korea_nepal_operator_fees.csv`. FX margins were **not** obtainable from
  the open web (gated behind logged-in apps) — this is the single biggest open data gap.
- **EPS MOU (2007) text** — manually mapped clause-by-clause; confirmed **zero** remittance or
  payment-channel provisions in 21 paragraphs.

### 2. Analysis pipeline (`scripts/`, run by `run_all.R`)

| Script | What it does | Key output |
|---|---|---|
| `00b_reshape_rpw_excel.R` | World Bank RPW xlsx → corridor-quarter panel | `data/raw/rpw_real.csv` |
| `00c_ingest_nrb_real.R` | NRB PDF reports → monthly series (network: fetches missing PDFs) | `data/raw/nrb_remit_monthly_real.csv` |
| `00d_ingest_korea_fees_real.R` | Korea MTO fee seed → cleaned fee table | `data/raw/korea_mto_fees_real.csv` |
| `01_load_clean_rpw.R` | Validate/tidy the RPW panel | `data/processed/rpw_panel_clean.csv` |
| `02_corridor_diagnostics.R` | Gulf corridor fee vs. FX decomposition, benchmarks, trends | table1, table2, fig1, fig2 |
| `02b_korea_cost_reconstruction.R` | Korea MTO cost reconstruction (fee-only lower bound + Gulf-FX-proxy upper bound) | table_korea_*, fig_korea_operator_costs.png |
| `03_panel_regression.R` | FE/OLS panel regressions, within-Nepal and cross-country | table3a, table3b |
| `04_timeseries_structural_break.R` | NRB ADF, STL decomposition, Chow structural-break tests | table4, fig3, fig4 |
| `05_monte_carlo_retention.R` | Monte Carlo formalization-value scenarios | table5, fig5 |
| `06_eps_mou_analysis.R` | EPS MOU clause gap matrix, comparator instruments, model clause draft | table6a/b/c, fig6 |
| `07_bla_comparative_analysis.R` | Extends 06 into a full BLA gap matrix (Korea confirmed; Gulf/Malaysia/Japan scaffolded) | table7, fig8 |

`mofa_pipeline_report.Rmd` doesn't duplicate this logic — it sources the same scripts via a
`source_script()` wrapper and renders the resulting `output/tables/` and `output/figures/`
into a 9-part PDF brief (Introduction → Data prep → Gulf diagnostics → Korea cost
reconstruction → Panel regression → NRB time series → Monte Carlo → EPS MOU analysis → BLA
comparison → recommendations → appendices).

### 3. Confirmed numbers (pipeline run, 24 June 2026)

| Metric | Value |
|---|---|
| Korea corridor volume | USD 484M/year (NLSS IV 2022/23, survey estimate) |
| Korea → Nepal RPW coverage | **Absent** (0 corridors in any quarter 2011–Q3 2025) |
| Korea MTO fee-only average (KRW 500,000) | 0.77% (lower bound — FX margin not yet captured) |
| Korea upper bound (+ Gulf avg FX proxy) | 1.67% |
| Gulf corridor simple average | 3.59% |
| Nepal FATF grey-listed | February 2025 |
| EPS MOU (2007) | 21 paragraphs, zero remittance provisions |

### 4. Repo cleanup (this session, July 1 2026)
- Moved root-level seed/collected data files into `data/raw/collected/` and process notes into
  `docs/`, so the repo root only holds pipeline entry points and config.
- Archived one-off patch scripts (`_patch_*.R`) and the superseded monolithic
  `mofa_pipeline_all.R` into `archive/legacy_scripts/` (see its README for why each was
  superseded).
- Added `CLAUDE.md` as a technical map for AI coding assistants working in this repo.
- Added `07_bla_comparative_analysis.R`, `table7_bla_comparison.csv`, and
  `fig8_bla_gap_matrix.png` to extend the EPS-only gap matrix (06) into a full BLA comparison
  (07) — Gulf/Malaysia/Japan columns are scaffolded pending the desk-research gap below.

---

## Known issue — re-running does not currently reproduce committed numbers

Re-running `00b_reshape_rpw_excel.R` + `01_load_clean_rpw.R` against the current
`data/raw/rpw_dataset_2011_2025_q3.xlsx` does **not** reproduce the committed
`data/processed/rpw_panel_clean.csv` or `table1_*` — the corridor set and cost figures differ
materially (verified 2026-07-01). This is pre-existing, not caused by the repo reorganisation,
and needs deliberate investigation before a fresh full pipeline run should be trusted over the
numbers already cited in this README and the brief. **Don't silently regenerate `output/` or
`data/processed/` as a side effect of an unrelated change** — confirm with the project owner
first. See `CLAUDE.md` for more detail.

---

## Next steps

**Immediate — close the data gaps that are load-bearing for the brief** (see
[`data_gaps_tracker.md`](data_gaps_tracker.md) for full detail on each):

1. **Korea MTO FX margin** (critical) — get one live KRW 500,000 → NPR transfer quote from
   WireBarley or GME. This converts the Korea cost figure from a fee-only lower bound (0.77%)
   into a real total-cost estimate and is the single most impactful open gap.
2. **BLA comparison desk research** (load-bearing for the June 25 reframe) — scan the Gulf
   (2007), Malaysia (2003/2018), and Japan MOU texts for remittance/payment-channel clauses to
   populate the scaffolded columns in `table7_bla_comparison.csv` / `fig8_bla_gap_matrix.png`.
   Does not require new quantitative data, ~one afternoon of reading.
3. **DoFE EPS worker count by year** (2007–2025) — grounds the corridor volume estimate beyond
   the single NLSS IV survey figure.
4. **NRB Korea corridor RSP transaction volume** (FY2023/24–FY2024/25) — validates or
   challenges the survey-based volume estimate; request via IFA letterhead.
5. **IOM post-2020 formal-channel usage survey** — informs the informal-share assumption
   feeding the Monte Carlo formalization-value estimate.

**Before trusting a fresh full pipeline run:** investigate the RPW reproducibility issue above.

**Week 3 (brief drafting):** six sections, following the confirmed-numbers table above; the
back-of-envelope formalization value replaces the Monte Carlo distribution in the written
brief, and the panel regression / structural-break results are excluded from the brief itself
(insignificant / inconclusive) even though the pipeline still produces them for completeness.

---

## Quick start

```r
# from this folder, in R or RStudio:
source("run_all.R")
```

Or from the shell:

```bash
Rscript run_all.R
```

Outputs land in `output/tables/` (CSV, TXT) and `output/figures/` (PNG). The full PDF brief is
built with `rmarkdown::render("mofa_pipeline_report.Rmd")`.

Set `USE_REAL_DATA <- FALSE` at the top of `run_all.R` to run against synthetic demo data
(`scripts/00_generate_demo_data.R`) instead of the real ingestion scripts — useful for a quick
smoke test that doesn't hit the network or depend on the data gaps above.

**Caution:** `00c_ingest_nrb_real.R` makes live network calls to fetch missing NRB PDF reports.
Don't re-run the full real-data pipeline casually — see the known issue above.

## Required R packages

```r
install.packages(c("dplyr","tidyr","ggplot2","readxl","stringr","plm",
                    "lmtest","sandwich","broom","zoo","strucchange",
                    "tseries","forecast","knitr","rmarkdown","pdftools"))
```

## Repository layout

| Path | Purpose |
|---|---|
| `scripts/` | The pipeline, run in numeric order by `run_all.R` |
| `data/raw/` | Ingested source data (`*_real.csv`, NRB PDFs, RPW xlsx) |
| `data/raw/collected/` | Manually collected seed data, read by `00c`/`00d` before being processed into `data/raw/*_real.csv` |
| `data/processed/` | Cleaned analysis-ready panel (`rpw_panel_clean.csv`) |
| `output/tables/`, `output/figures/` | Everything the Rmd report cites |
| `mofa_pipeline_report.Rmd` / `.pdf` | The rendered policy-brief-support report |
| `docs/` | Background/process notes; **`docs/DATA_SOURCES.md`** is the citation-ready reference list for paper writing — not needed to run the pipeline |
| `archive/legacy_scripts/` | Superseded code, not sourced by anything; see its README before touching |
| `data_gaps_tracker.md` | Live tracker of open data gaps — check before assuming a figure is final |
| `tex/` | Vendored LaTeX packages the Rmd's YAML header points at, for PDF rendering |
| `CLAUDE.md` | Technical map for AI coding assistants working in this repo |

## Data sources

- **RPW:** `remittanceprices.worldbank.org` — instant Excel download (dataset 0037898)
- **NRB monthly:** `nrb.org.np/category/monthly-statistics` — PDF reports transcribed to CSV
- **Korea MTO fees:** Operator websites and published fee schedules (see `docs/README_data_notes.md`)
- **EPS MOU:** archive.ceslam.org (Social Science Baha)

For citation-ready references (publisher, URL, access date, what each source feeds in the
pipeline) see [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) — use that file, not this
list, when citing sources in the paper. It also flags which "confirmed numbers" (NLSS IV,
IOM 2017, FATF) still need their full bibliographic reference completed before submission.

## Honest limitations

- Korea `total_cost_pct` is a **lower bound** until FX margins are captured from live transfer
  quotes (data gap #1 above).
- KNOMAD bilateral remittance estimates are modeled (vintage 2021); triangulate with NRB BoP
  figures where possible.
- Cross-country regression sample is small; treat p-values as indicative, not confirmatory.
- UPI–NPI (Nepal's new instant payment rail) launched 6 June 2026 — insufficient post-event
  months exist yet for a Nepal-specific Chow structural-break test.
- See the "Known issue" section above: a fresh full pipeline re-run does not currently
  reproduce the committed numbers in this README.
