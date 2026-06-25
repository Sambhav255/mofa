f <- readLines("scripts/04_timeseries_structural_break.R")
start <- grep("^select_consecutive_block", f)[1]
end <- grep("^nrb_ts_all", f)[1] - 1
new_fn <- c(
  "select_consecutive_block <- function(df, min_months = 36L) {",
  "  df <- df %>% filter(!is.na(remit_npr_bn)) %>% arrange(month)",
  "  if (nrow(df) < min_months) return(df)",
  "  gap <- c(FALSE, as.numeric(diff(df$month)) > 32)",
  "  run_id <- cumsum(gap)",
  "  run_tab <- tapply(seq_len(nrow(df)), run_id, length)",
  "  pick <- as.integer(names(run_tab)[which.max(run_tab)])",
  "  block <- df[run_id == pick, , drop = FALSE]",
  "  if (nrow(block) > min_months) block <- tail(block, min_months)",
  "  block",
  "}"
)
f <- c(f[1:(start - 1)], new_fn, f[(end + 1):length(f)])
writeLines(f, "scripts/04_timeseries_structural_break.R")
cat("Fixed select_consecutive_block\n")
