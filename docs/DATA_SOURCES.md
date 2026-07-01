# Data Sources & Citations

Single citation-ready reference list for every data source and literature figure used in
this pipeline / the Cluster 10 brief. Built 2026-07-01 for paper writing — pull directly
from the "Suggested citation" line for each source rather than re-deriving it from scripts.

For **detailed provenance** (exactly which cells were extracted vs. computed, what's
unconfirmed) see [`README_data_notes.md`](README_data_notes.md). For **open/pending
requests**, see [`../data_gaps_tracker.md`](../data_gaps_tracker.md). This file is the
index between the two — start here, drill into those two for the rest.

Two source categories below: **(A) primary datasets** pulled directly into the pipeline
with a script and an output file, and **(B) literature figures** hardcoded as constants
in the analysis (survey estimates, secondary studies) that need a full citation completed
before the paper is submitted — several are currently incomplete, flagged explicitly.

---

## A. Primary datasets (pulled into the pipeline)

### A1. World Bank Remittance Prices Worldwide (RPW)

- **Publisher:** World Bank Group
- **Dataset:** Remittance Prices Worldwide, complete firm-level dataset, dataset ID 0037898
- **Coverage:** 2011–Q3 2025, quarterly, all corridors (Gulf/Nepal corridors used here)
- **URL:** https://remittanceprices.worldbank.org/data-download
- **Accessed:** 2026-06-24
- **Local file:** `data/raw/rpw_dataset_2011_2025_q3.xlsx` (source) → `scripts/00b_reshape_rpw_excel.R` → `data/raw/rpw_real.csv` → `scripts/01_load_clean_rpw.R` → `data/processed/rpw_panel_clean.csv`
- **Feeds:** table1, table2, table3a/3b, fig1, fig2
- **Key finding to cite:** the Korea→Nepal corridor does **not** appear in RPW in any
  quarter 2011–Q3 2025 — confirmed by direct inspection of the corridor page and the full
  firm-level file. This is the empirical basis for the "invisible corridor" framing.
- **Suggested citation:** World Bank Group. (2025). *Remittance Prices Worldwide* [Dataset
  0037898]. Retrieved June 24, 2026, from https://remittanceprices.worldbank.org/data-download

### A2. Nepal Rastra Bank — Current Macroeconomic and Financial Situation (CMES) reports

- **Publisher:** Nepal Rastra Bank (NRB), Research Department
- **What:** Monthly remittance inflow, FX reserves, and labour-permit figures, transcribed
  from PDF report text (NRB does not publish these as a bulk downloadable series)
- **Coverage obtained:** 13 report cut-off months, FY2021/22–FY2025/26 (scattered, not
  continuous — see limitation below)
- **URL (report index):** https://www.nrb.org.np/category/monthly-statistics/ and
  individual report permalinks under https://www.nrb.org.np/red/ — full catalogue of 224
  identified report URLs in `data/raw/collected/nrb_report_inventory.csv`, raw list of 760
  permalinks in `data/raw/collected/all_cmes_report_urls.txt`
- **Accessed:** 2026-06-24 (ongoing — `scripts/00c_ingest_nrb_real.R` fetches additional
  PDFs on each pipeline run, capped per run)
- **Local file:** `data/raw/collected/nrb_remit_monthly_real.csv` (seed) →
  `scripts/00c_ingest_nrb_real.R` → `data/raw/nrb_remit_monthly_real.csv`
- **Feeds:** table4, fig3, fig4
- **Limitation to cite:** this is a scatter of report cut-off months, not a continuous
  monthly time series — NRB gates the full ~130-report archive behind JavaScript, so it
  could not be bulk-downloaded. Treat structural-break results (table4) as indicative.
- **Suggested citation:** Nepal Rastra Bank. (2021–2026). *Current Macroeconomic and
  Financial Situation* [Monthly reports, various fiscal years]. Retrieved June 24, 2026,
  from https://www.nrb.org.np/category/monthly-statistics/

### A3. Korea MTO / bank operator fee schedules

- **Publisher:** Individual money transfer operators — Rupeesend, Hanpass, GME,
  WireBarley, Sentbe, SBI Cosmoney, E9pay, KB Kookmin (bank), Korea Post (bank; confirmed
  does **not** serve the Nepal corridor)
- **What:** Published flat transfer fees (KRW) for a KRW 500,000 / KRW 1,000,000 send
- **Mid-market FX benchmark:** XE.com, 1 KRW = 0.0982839 NPR (2026-06-24, 05:35 UTC)
- **Accessed:** 2026-06-24
- **Local file:** `data/raw/collected/korea_nepal_operator_fees.csv` (seed) →
  `scripts/00d_ingest_korea_fees_real.R` → `data/raw/korea_mto_fees_real.csv`
- **Feeds:** table_korea_mto_costs_500k, table_korea_mto_costs_1m,
  table_korea_vs_gulf_comparison, fig_korea_operator_costs.png
- **Critical limitation to cite:** `total_cost_pct` for Korea is a **fee-only lower bound**
  (0.77% average). No operator publishes its live KRW→NPR exchange-rate margin on the open
  web — it's gated behind logged-in apps/calculators. Closing this (data gap #1, see
  tracker) would convert the figure to a real total-cost estimate.
- **Suggested citation:** cite each operator individually if quoting its specific fee, e.g.
  WireBarley. (2026). *Transfer fee schedule* [Website]. Retrieved June 24, 2026, from
  the operator's published fee page. Full per-operator notes in `README_data_notes.md` §1.

### A4. Nepal–Korea EPS MOU (2007)

- **Publisher:** Governments of Nepal and the Republic of Korea (Employment Permit System
  MOU, signed 2007)
- **Archive:** archive.ceslam.org (Centre for the Study of Labour and Mobility / Social
  Science Baha)
- **URL:** https://archive.ceslam.org
- **What:** Full MOU text, manually clause-coded (21 paragraphs)
- **Local file:** clause coding embedded in `scripts/06_eps_mou_analysis.R` →
  table6a_eps_mou_clause_mapping, table6b_instrument_comparison, table6c, fig6
- **Key finding to cite:** zero remittance or payment-channel provisions across all 21
  paragraphs — the EPS MOU is silent on cost/payment-channel matters entirely.
- **Suggested citation:** Government of Nepal & Government of the Republic of Korea.
  (2007). *Memorandum of Understanding on the Sending of Workers under the Employment
  Permit System*. Archived at Centre for the Study of Labour and Mobility,
  https://archive.ceslam.org

### A5. Nepal BLA comparator instruments (Qatar, UAE, Saudi Arabia, Malaysia, Japan, Bahrain, Jordan)

- **Status: provisionally populated (2026-07-01), primary-text verification pending.**
  `scripts/07_bla_comparative_analysis.R` extends A4's clause coding to 7 more Nepal BLA
  partners from a desk-research pass. **Do not cite these 7 rows with the same confidence
  as the Korea row** — the primary MOU text has not yet been independently checked against
  the sources below. See data gap #5 in the tracker.
- **Sources to verify against:** archive.ceslam.org/governance/bilateral-arrangements
  (Nepal BLA archive); ilo.org/media/439831/download (ILO bilateral labour-migration
  agreements study)
- **What was found (all provisional):** Qatar — Agreement on Nepali Manpower Employment,
  21 Mar 2005; UAE — MOU, 2007; Saudi Arabia — Bilateral Labour Agreement, 26 Jan 2026;
  Malaysia — MOU, 2003, updated 29 Oct 2018; Japan — Memorandum of Cooperation (Specified
  Skilled Worker), 25 Mar 2019, updated 1 Jan 2024; Bahrain — MOU, 2008; Jordan — General
  Agreement in the Field of Manpower, 18 Oct 2017.
- **Key finding:** zero remittance provisions across all 8 instruments reviewed (Korea +
  7). Saudi Arabia's BLA is the only one with any payment-channel clause at all — salary
  must be paid into a bank account in the worker's own name.
- **Local file:** `output/tables/table7_bla_comparison.csv`, `output/figures/fig8_bla_gap_matrix.png`
- **Suggested citation (once verified):** cite each instrument individually by its full
  name/date above, sourced to its primary MOU/agreement text or the CESLAM/ILO archive
  entry — not to this repo's summary table.

---

## B. Literature figures (hardcoded constants — citations incomplete)

These numbers appear in `scripts/05_monte_carlo_retention.R` and the README's "Confirmed
numbers" table as sourced constants, but **this repo does not hold the full bibliographic
reference** for any of them (no author, exact report title, or page/table number was
recorded when they were collected). **Do not submit the paper without completing these
citations** — pull the primary report and cite it properly rather than citing this repo's
placeholder label.

| Figure | Value | Placeholder label in code | What's missing |
|---|---|---|---|
| Korea corridor total remittance volume | USD 484M/year | `"NLSS IV 2022/23"` (`scripts/05_monte_carlo_retention.R:16`) | Full NLSS IV report citation (National Statistics Office, Government of Nepal) + table/page number for the corridor breakdown |
| Saudi corridor total remittance volume | USD 1,020M/year | `"NLSS IV 2022/23"` | Same as above |
| Korea informal-channel share (historical) | ~80% | `"IOM Seoul / Kathmandu Post ~2017"` | Exact IOM Seoul report title/author, or the specific Kathmandu Post article date/byline |
| Korea informal-channel share (current estimate) | ~45–65% (script uses ~55%) | `"Literature triangulation"` | Not a single citable source — document the triangulation method if used in the paper |
| Nepal FATF grey-listing | February 2025; still listed as of the 19 June 2026 FATF plenary | (README only, no script constant) | FATF plenary outcome statement — exact date and URL from fatf-gafi.org, for both the Feb 2025 listing and the June 2026 plenary confirmation |
| APG review deadline | September 2026 (hawala/hundi control specifically cited) | not yet in repo | Exact Asia/Pacific Group on Money Laundering (APG) mutual evaluation follow-up document and URL |
| KNOMAD bilateral remittance matrix | vintage ~2021 | referenced in `docs/cursor_consolidate_r_project_files.md` | https://data360.worldbank.org/en/indicator/WB_KNOMAD_BRE — modeled, not measured; cross-check against NRB BoP figures before citing as a standalone number |
| Active EPS workers in Korea | ~60,000–61,000 | `"DoFE, August 2025"` | Exact DoFE Statistics Section report/bulletin title and URL. Note: distinct from data gap #2 (the year-by-year 2007–2025 series requested 1 Jul 2026) — this is a single topline figure only |
| New labour permits (Korea) FY2024/25 | 14,224 | `"DoFE"` | Exact DoFE bulletin/report title and URL |
| NZ Recognised Seasonal Employer (RSE) scheme | Comparator: employers legally required to give workers MTO information | `"MFAT"` (New Zealand Ministry of Foreign Affairs and Trade) | Specific MFAT/Immigration NZ policy document and URL — currently only cited generically |
| BOK–NRB Korea Payment Project (KPP) | Bilateral technical cooperation channel, Feb 2025 report | `"NRB/BOK"` | Exact NRB or Bank of Korea report title and URL — grounds EPS clause sub-clause (d) in the model clause text |
| UPI–NPI cross-border payment link launch | 6 June 2026 | `"NRB / RBI"` | Exact NRB or Reserve Bank of India press release/announcement URL |
| SDG 10.c remittance-cost target | 3.0% by 2030 | — | Well-established, citable directly: UN General Assembly, *Transforming Our World: The 2030 Agenda for Sustainable Development*, Target 10.c |
| G20 "5x5" remittance-cost objective | 5.0% | — | Well-established, citable directly: G20, *Los Cabos Leaders' Declaration* (June 2012) / G20 Global Partnership for Financial Inclusion National Remittance Plans |
| BSP MORB Section 298 (Philippines) | Correct comparator for Recommendation 3 | see A1 above | **Not** "BSP Circular 1238" — that citation was a factual error, corrected 2026-07-01 in `scripts/06_eps_mou_analysis.R` (see `data_gaps_tracker.md` notes). If it appears in any slide deck outside this repo, replace it. |

**Why this matters:** the NLSS IV and IOM figures are the only quantitative grounding for
Korea's total corridor volume and the formalization-value Monte Carlo (table5) — if the
paper cites "NLSS IV 2022/23" without the full reference, a reviewer can't verify it. Data
gaps #2–#4 in the tracker (DoFE worker counts, NRB RSP volume, IOM post-2020 survey — all
formally requested 2026-07-01) would let these move from "cited literature estimate" to
"pipeline-verified figure."

---

## Superseded / do-not-cite

`archive/legacy_scripts/collect_real_data.R` and its outputs in
`archive/legacy_scripts/stale_collected_outputs/` contain **placeholder, demo-calibrated
values** from an early exploratory pass (2026-06-23), before the real ingestion scripts
existed. They share similar filenames to the real data in `data/raw/collected/` — if a
number looks off, check which directory it came from. See
`archive/legacy_scripts/README.md` for detail.
