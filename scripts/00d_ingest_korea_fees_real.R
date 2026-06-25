# ============================================================================
# 00d_ingest_korea_fees_real.R
#
# Copy and enrich Korea operator fee collection for the pipeline.
# ============================================================================

suppressMessages(library(dplyr))

SRC <- "korea_nepal_operator_fees.csv"
OUT <- "data/raw/korea_mto_fees_real.csv"

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)

if (!file.exists(OUT) && file.exists(SRC)) {
  file.copy(SRC, OUT, overwrite = TRUE)
  cat("Copied", SRC, "->", OUT, "\n")
}

if (!file.exists(OUT)) {
  stop("Korea fees file not found at ", OUT, " or ", SRC)
}

korea <- read.csv(OUT, stringsAsFactors = FALSE, na.strings = c("", "NA"))

cat("Korea MTO fees — column names:\n")
print(names(korea))
cat("\nAll rows:\n")
print(korea, row.names = FALSE)
cat("\n")

blank_num <- function(x) is.na(x) | trimws(as.character(x)) == ""

korea <- korea %>%
  mutate(
    fx_margin_pct = ifelse(blank_num(fx_margin_pct), NA_real_, as.numeric(fx_margin_pct)),
    total_cost_pct = ifelse(blank_num(total_cost_pct), NA_real_, as.numeric(total_cost_pct)),
    flat_fee_krw = ifelse(blank_num(flat_fee_krw), NA_real_, as.numeric(flat_fee_krw)),
    transfer_krw = as.numeric(transfer_krw),
    cost_is_lower_bound = is.na(fx_margin_pct),
    serves_nepal = !grepl("Korea Post", operator, ignore.case = TRUE),
    fx_benchmark_krw_npr = 0.0982839,
    fx_benchmark_date = "2026-06-24"
  )

fee_only_idx <- is.na(korea$total_cost_pct) & !is.na(korea$flat_fee_krw) & korea$flat_fee_krw > 0
korea$total_cost_pct[fee_only_idx] <-
  (korea$flat_fee_krw[fee_only_idx] / korea$transfer_krw[fee_only_idx]) * 100
korea$cost_is_lower_bound[fee_only_idx] <- TRUE

write.csv(korea, OUT, row.names = FALSE)
cat("Wrote enriched Korea fees to", OUT, "\n")
cat("Rows with cost_is_lower_bound=TRUE:", sum(korea$cost_is_lower_bound), "\n")
cat("Operators not serving Nepal (excluded from averages):",
    paste(unique(korea$operator[!korea$serves_nepal]), collapse = ", "), "\n")
