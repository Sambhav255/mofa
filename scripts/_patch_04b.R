f <- readLines("scripts/04_timeseries_structural_break.R")
if (!any(grepl("nrb_ts <- select_consecutive_block", f))) {
  idx <- grep("^  arrange\\(month\\)$", f)[1]
  ins <- c(
    "",
    "nrb_ts <- select_consecutive_block(nrb_ts_all, 24L)",
    'cat(sprintf("Using %d consecutive months (%s to %s) for STL/ADF.\n\n",',
    '            nrow(nrb_ts), format(min(nrb_ts$month), "%Y-%m"), format(max(nrb_ts$month), "%Y-%m")))'
  )
  f <- c(f[1:idx], ins, f[(idx + 1):length(f)])
  writeLines(f, "scripts/04_timeseries_structural_break.R")
  cat("Inserted nrb_ts block selection\n")
} else {
  cat("Already patched\n")
}
