# ============================================================================
# 00b_reshape_rpw_excel.R
#
# Reshape World Bank RPW firm-level Excel into corridor-quarter panel
# expected by the pipeline (data/raw/rpw_real.csv).
# ============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(readxl)
  library(stringr)
})

RAW_XLSX <- "data/raw/rpw_dataset_2011_2025_q3.xlsx"
SRC_XLSX <- "data/raw/rpw_dataset_2011_2025_q3.xlsx"
OUT_CSV  <- "data/raw/rpw_real.csv"

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)

if (!file.exists(RAW_XLSX) && file.exists(SRC_XLSX)) {
  file.copy(SRC_XLSX, RAW_XLSX, overwrite = TRUE)
  cat("Copied source Excel to", RAW_XLSX, "\n")
}

if (!file.exists(RAW_XLSX)) {
  stop("RPW Excel not found at ", RAW_XLSX, " or ", SRC_XLSX)
}

sheet_names <- excel_sheets(RAW_XLSX)
cat("Excel sheet names:\n")
print(sheet_names)
cat("\nNOTE: This vintage uses two period-split dataset sheets (not separate $200/$500\n")
cat("sheets). cc1 = USD 200 send; cc2 = USD 500 send within each sheet.\n\n")

data_sheets <- sheet_names[grepl("^Dataset", sheet_names)]
if (length(data_sheets) < 2) {
  stop("Expected two 'Dataset' sheets; found: ", paste(data_sheets, collapse = ", "))
}

read_rpw_sheet <- function(sheet) {
  cat("Reading sheet:", sheet, "...\n")
  d <- read_excel(RAW_XLSX, sheet = sheet)
  cat("  Column names:\n")
  print(names(d))
  cat("\n")
  names(d) <- make.names(names(d))
  d
}

raw_list <- lapply(data_sheets, read_rpw_sheet)
raw <- bind_rows(raw_list)

recv_filter <- c("Nepal", "Bangladesh", "Philippines", "India")
pakistan_present <- "Pakistan" %in% raw$destination_name
cat("Pakistan in full RPW data:", ifelse(pakistan_present, "YES (excluded from panel per spec)", "ABSENT — flag for comparators"), "\n\n")

is_transparent <- function(x) tolower(as.character(x)) == "yes"

is_mto_firm <- function(ft) {
  ft %in% c("Money Transfer Operator", "Mobile Operator")
}

is_bank_firm <- function(ft) {
  ft == "Bank"
}

is_digital <- function(access_point, pick_up) {
  ap <- ifelse(is.na(access_point), "", access_point)
  pm <- ifelse(is.na(pick_up), "", pick_up)
  grepl("Internet|Mobile", ap, ignore.case = TRUE) |
    grepl("Mobile", pm, ignore.case = TRUE)
}

parse_period_vec <- function(period) {
  m <- str_match(period, "^([0-9]{4})_([1-4])Q$")
  quarter <- ifelse(is.na(m[, 1]), NA_character_, paste0(m[, 2], "Q", m[, 3]))
  month_start <- (as.integer(m[, 3]) - 1L) * 3L + 1L
  quarter_date <- as.Date(
    ifelse(is.na(m[, 1]), NA, sprintf("%s-%02d-01", m[, 2], month_start))
  )
  data.frame(quarter = quarter, quarter_date = quarter_date, stringsAsFactors = FALSE)
}

aggregate_amount <- function(d, amount_usd, total_col, fx_col) {
  d %>%
    filter(is_transparent(transparent), !is.na(.data[[total_col]])) %>%
    mutate(
      quarter = parse_period_vec(period_raw)$quarter,
      quarter_date = parse_period_vec(period_raw)$quarter_date,
      amount_usd = amount_usd,
      total_cost_pct = .data[[total_col]],
      fx_margin_pct_row = .data[[fx_col]],
      fee_pct_row = .data[[total_col]] - .data[[fx_col]],
      cost_row = .data[[total_col]],
      digital = is_digital(
        if ("access.point" %in% names(d)) access.point else NA_character_,
        if ("pick.up.method" %in% names(d)) pick.up.method else NA_character_
      )
    ) %>%
    filter(!is.na(quarter)) %>%
    group_by(quarter, quarter_date, receiving_country, sending_country, amount_usd) %>%
    summarise(
      total_cost_pct = mean(cost_row, na.rm = TRUE),
      mto_cost_pct   = mean(cost_row[is_mto_firm(firm_type)], na.rm = TRUE),
      bank_cost_pct  = mean(cost_row[is_bank_firm(firm_type)], na.rm = TRUE),
      fee_pct        = mean(fee_pct_row, na.rm = TRUE),
      fx_margin_pct  = mean(fx_margin_pct_row, na.rm = TRUE),
      num_services   = n(),
      pct_digital    = mean(digital, na.rm = TRUE),
      .groups = "drop"
    )
}

d_norm <- raw %>%
  rename(
    receiving_country = destination_name,
    sending_country = source_name,
    period_raw = period
  ) %>%
  filter(receiving_country %in% recv_filter)

total_200 <- "cc1.total.cost.."
fx_200    <- "cc1.fx.margin"
total_500 <- "cc2.total.cost.."
fx_500    <- "cc2.fx.margin"

panel_200 <- aggregate_amount(d_norm, 200L, total_200, fx_200)
panel_500 <- aggregate_amount(d_norm, 500L, total_500, fx_500) %>%
  select(quarter, quarter_date, receiving_country, sending_country,
         total_cost_pct_500 = total_cost_pct)

rpw_panel <- panel_200 %>%
  left_join(
    panel_500,
    by = c("quarter", "quarter_date", "receiving_country", "sending_country")
  ) %>%
  mutate(
    across(c(total_cost_pct, mto_cost_pct, bank_cost_pct, fee_pct, fx_margin_pct,
             total_cost_pct_500, pct_digital),
           ~ round(.x, 3)),
    pct_digital = round(pct_digital * 100, 1)
  ) %>%
  select(
    quarter, quarter_date, receiving_country, sending_country, amount_usd,
    total_cost_pct, mto_cost_pct, bank_cost_pct, fee_pct, fx_margin_pct,
    total_cost_pct_500, num_services, pct_digital
  ) %>%
  arrange(quarter_date, receiving_country, sending_country)

korea_nepal <- rpw_panel %>%
  filter(receiving_country == "Nepal", grepl("Korea", sending_country))
if (nrow(korea_nepal) == 0) {
  cat("CONFIRMED: Korea -> Nepal corridor is ABSENT from RPW data.\n")
  cat("This gap is filled by the manually collected Korea operator fee data.\n\n")
} else {
  warning("Unexpected Korea -> Nepal rows found: ", nrow(korea_nepal))
}

write.csv(rpw_panel, OUT_CSV, row.names = FALSE)
cat("Wrote", nrow(rpw_panel), "rows to", OUT_CSV, "\n")
cat("Quarters:", n_distinct(rpw_panel$quarter),
    "| Corridors:", n_distinct(paste(rpw_panel$sending_country, rpw_panel$receiving_country)),
    "| Receiving countries:", paste(unique(rpw_panel$receiving_country), collapse = ", "), "\n")
