# Legacy scripts (not part of the pipeline)

Nothing here is sourced by `run_all.R`, `mofa_pipeline_report.Rmd`, or any file
under `scripts/`. Kept for history only.

- **`mofa_pipeline_all.R`** — an early single-file consolidation of the pipeline
  (June 24, 2026), written before real-data ingestion (`00c`/`00d`) and
  `07_bla_comparative_analysis.R` existed. It only runs on synthetic demo data
  and is out of sync with the current modular pipeline in `scripts/`. Superseded
  by `run_all.R` sourcing `scripts/*.R` in order.

- **`_patch_00c.R`, `_patch_04.R`, `_patch_04b.R`, `_patch_04c.R`, `_patch_04d.R`,
  `_patch_04e.R`, `_patch_36m.R`** — one-shot scripts that used `readLines()`/
  `writeLines()` to rewrite `scripts/00c_ingest_nrb_real.R` and
  `scripts/04_timeseries_structural_break.R` in place during development
  (e.g. raising the minimum consecutive-months threshold from 24 to 36). Their
  edits are already baked into the current versions of those two scripts.
  Do not re-run them — they assume an earlier version of the target file and
  will silently no-op or corrupt the current one.

- **`collect_real_data.R`** — an early exploratory data-collection script
  (June 23, 2026), written before the real ingestion scripts (`00b`, `00c`,
  `00d`) existed. **Its output values are placeholders**, not real collected
  data — the script's own inline comments mark most rows `"Demo-calibrated;
  re-scrape <site>.com"`. Superseded by `00b_reshape_rpw_excel.R`,
  `00c_ingest_nrb_real.R`, and `00d_ingest_korea_fees_real.R`, which read the
  actual manually-verified data in `data/raw/collected/`.

  Its outputs live in `stale_collected_outputs/` — moved out of
  `data/raw/collected/` on 2026-07-01 specifically so they can't be mistaken
  for the real collected data (`korea_nepal_operator_fees.csv`,
  `nrb_remit_monthly_real.csv`, `rpw_nepal_corridors.csv`, etc.) when citing
  sources for the paper. **Do not cite any figure from
  `stale_collected_outputs/` — none of it is verified real data.**
