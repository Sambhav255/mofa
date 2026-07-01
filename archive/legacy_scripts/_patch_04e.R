f <- readLines("scripts/04_timeseries_structural_break.R")
f[43] <- "nrb_ts <- select_consecutive_block(nrb_ts_all, 36L)"
f[71] <- "if (length(ts_remit) >= 36) {"
writeLines(f, "scripts/04_timeseries_structural_break.R")
cat("Line 43 and 71 fixed\n")
