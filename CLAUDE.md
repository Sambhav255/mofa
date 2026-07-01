# Project Instructions

## What this is

A reproducible R data pipeline behind a Nepal MoFA (Ministry of Foreign Affairs)
policy brief: *"Measuring the Invisible: The Korea EPS Corridor as a Case for
Remittance Provisions in Nepal's Bilateral Labour Agreements"* (Cluster 10,
Summer Internship 2026). It quantifies remittance costs on Nepal's corridors
(Korea case study, Gulf/Malaysia as comparators) and evaluates what payment
provisions Nepal should embed in bilateral labour agreements. See `README.md`
for the research question and confirmed numbers, and `data_gaps_tracker.md`
for open data gaps.

## Tech stack

R (4.4.x), tidyverse-adjacent packages (`dplyr`, `tidyr`, `readxl`, `stringr`),
`plm`/`lmtest`/`sandwich`/`broom` for panel regression, `strucchange`/`tseries`/
`forecast`/`zoo` for time-series, `pdftools` for NRB PDF scraping, `knitr`/
`rmarkdown` (LaTeX/PDF output) for the final report. No package manager
(renv/packrat) — install via the list in `README.md`.

## How the pipeline runs

`run_all.R` sources every script in `scripts/` **in order**, in a shared R
session (`source(s, local = FALSE)`), and logs to `output/pipeline_run_log.txt`.
It is **file-based, not variable-based**: each script re-reads its inputs from
disk rather than relying on objects left behind by the previous script. The one
real cross-script variable is `USE_REAL_DATA` (set at the top of `run_all.R`),
which scripts 01, 02b, and 04 branch on to pick real vs. demo file paths.

```
scripts/00b_reshape_rpw_excel.R      World Bank RPW xlsx -> data/raw/rpw_real.csv
scripts/00c_ingest_nrb_real.R        NRB PDF reports -> data/raw/nrb_remit_monthly_real.csv (network: fetches missing PDFs into data/raw/nrb_pdfs)
scripts/00d_ingest_korea_fees_real.R Korea MTO fee seed -> data/raw/korea_mto_fees_real.csv
scripts/01_load_clean_rpw.R          -> data/processed/rpw_panel_clean.csv        [run before 02, 02b, 03, 05]
scripts/02_corridor_diagnostics.R    Gulf/comparator diagnostics -> table1/2, fig1/2
scripts/02b_korea_cost_reconstruction.R  Korea cost vs Gulf -> table_korea_*, fig_korea_operator_costs.png
scripts/03_panel_regression.R        FE/OLS regressions -> table3a/3b
scripts/04_timeseries_structural_break.R NRB ADF/STL/Chow -> table4, fig3/4
scripts/05_monte_carlo_retention.R   Formalization value -> table5, fig5
scripts/06_eps_mou_analysis.R        EPS MOU clause gap matrix -> table6a/b/c, fig6
scripts/07_bla_comparative_analysis.R  extends 06 -> table7, fig8   [run after 06 — reads its CSV output]
```

`mofa_pipeline_report.Rmd` does **not** duplicate this logic — it sources the
same `scripts/*.R` files via a `source_script()` wrapper, then renders the
resulting `output/tables`/`output/figures` into the PDF brief.

Set `USE_REAL_DATA <- FALSE` in `run_all.R` to run on synthetic demo data
(`scripts/00_generate_demo_data.R`) instead of real ingestion.

**Caution:** `00c_ingest_nrb_real.R` makes live network calls to fetch missing
NRB PDF reports (up to `MAX_NEW` per run). Don't re-run the full pipeline
casually — a partial/no-op run against already-generated outputs is usually
enough to sanity-check a change. See "Known issue" below before trusting a
fresh full re-run's numbers over what's already committed in `output/`.

## Known issue — re-running does not currently reproduce committed numbers

Re-running `scripts/00b_reshape_rpw_excel.R` + `01_load_clean_rpw.R` against
the current `data/raw/rpw_dataset_2011_2025_q3.xlsx` does **not** reproduce
the committed `data/processed/rpw_panel_clean.csv` or `output/tables/table1_*`
— the corridor set and cost figures differ materially (verified 2026-07-01).
This looks pre-existing (not caused by any path/reorg change) and needs
deliberate investigation before trusting a fresh full pipeline run over the
numbers already cited in `README.md` / the brief. Don't silently regenerate
and overwrite `output/` or `data/processed/` as a side effect of unrelated
changes — confirm with the project owner first.

## Repository layout

| Path | Purpose |
|---|---|
| `scripts/` | The pipeline, run in numeric order by `run_all.R` |
| `data/raw/` | Ingested source data (`*_real.csv`, NRB PDFs, RPW xlsx) |
| `data/raw/collected/` | Manually collected seed data, read by `00c`/`00d` before they're processed into `data/raw/*_real.csv` |
| `data/processed/` | Cleaned analysis-ready panel (`rpw_panel_clean.csv`) |
| `output/tables/`, `output/figures/` | Everything the Rmd report cites |
| `mofa_pipeline_report.Rmd` / `.pdf` | The rendered policy-brief-support report |
| `docs/` | Background/process notes; `docs/DATA_SOURCES.md` is the citation-ready source list (publisher, URL, access date) for paper writing — cross-reference it when a task touches sourcing/citations. Not needed to run the pipeline |
| `archive/legacy_scripts/` | Superseded code, not sourced by anything; see its README before touching |
| `data_gaps_tracker.md` | Live tracker of open data gaps — check before assuming a figure is final |
| `tex/` | Vendored LaTeX packages the Rmd's YAML header points at (`tex/preamble.tex`, `tex/latex`) for PDF rendering — intentional, not build cruft |

## Conventions

- Script filenames are execution order (`00b` < `00c` < `01` < `02` < `02b` < ...); a new pipeline step should get a number reflecting where it runs, not appended at the end.
- Every script writes real files to `output/tables/` or `output/figures/` with a name matching its table/figure number in the Rmd — keep that pairing when adding analysis.
- Real-data scripts write a fallback/seed check (`if (!file.exists(OUT) && file.exists(SRC))`) before failing loudly — follow this pattern for new ingestion scripts rather than assuming the seed file is already in place.
