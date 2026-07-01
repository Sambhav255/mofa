# Patch 04 to use longest consecutive monthly block for STL/ADF
f <- readLines("scripts/04_timeseries_structural_break.R")
insert <- c(
  '',
  'select_consecutive_block <- function(df, min_months = 24L) {',
  '  df <- df %>% filter(!is.na(remit_npr_bn)) %>% arrange(month)',
  '  if (nrow(df) < min_months) return(df)',
  '  grid <- seq(min(df$month), max(df$month), by = "1 month")',
  '  full <- data.frame(month = grid) %>%',
  '    left_join(df %>% select(month, remit_npr_bn, source), by = "month")',
  '  runs <- rle(!is.na(full$remit_npr_bn))',
  '  ends <- cumsum(runs$lengths)',
  '  starts <- ends - runs$lengths + 1L',
  '  ok <- which(runs$values & runs$lengths >= min_months)',
  '  if (length(ok) == 0) {',
  '    ok <- which(runs$values)',
  '    if (length(ok) == 0) return(df)',
  '    pick <- ok[which.max(runs$lengths[ok])]',
  '    return(full[starts[pick]:ends[pick], ] %>% filter(!is.na(remit_npr_bn)))',
  '  }',
  '  pick <- ok[length(ok)]',
  '  block <- full[starts[pick]:ends[pick], ] %>% filter(!is.na(remit_npr_bn))',
  '  if (nrow(block) > min_months) block <- tail(block, min_months)',
  '  block',
  '}',
  ''
)
idx <- grep("^nrb_ts <-", f)[1]
if (!any(grepl("select_consecutive_block", f))) {
  f <- c(f[1:(idx-1)], insert, f[idx:length(f)])
}
f <- gsub(
  "nrb_ts <- nrb %>%\n  filter\\(!is.na\\(remit_npr_bn\\)\\) %>%\n  arrange\\(month\\)",
  "nrb_ts_all <- nrb %>% filter(!is.na(remit_npr_bn)) %>% arrange(month)\nnrb_ts <- select_consecutive_block(nrb_ts_all, 24L)\ncat(sprintf(\"Using %d consecutive months (%s to %s) for STL/ADF.\\n\\n\",\n              nrow(nrb_ts), format(min(nrb_ts$month), \"%Y-%m\"), format(max(nrb_ts$month), \"%Y-%m\")))",
  f
)
f <- gsub(
  "if \\(length\\(ts_remit\\) >= 24\\) \\{\n  stl_fit <- stl\\(ts_remit, s.window = \"periodic\"\\)",
  "if (length(ts_remit) >= 24 && frequency(ts_remit) == 12) {\n  stl_fit <- stl(ts_remit, s.window = \"periodic\")",
  f
)
writeLines(f, "scripts/04_timeseries_structural_break.R")
cat("Patched 04_timeseries_structural_break.R\n")
