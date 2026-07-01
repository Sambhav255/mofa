# ============================================================================
# 00c_ingest_nrb_real.R
#
# Copy real NRB monthly series, densify via PDF extraction from report
# inventory URLs, and save data/raw/nrb_remit_monthly_real.csv
# ============================================================================

suppressMessages({
  library(dplyr)
})

SRC_CSV      <- "data/raw/collected/nrb_remit_monthly_real.csv"
OUT_CSV      <- "data/raw/nrb_remit_monthly_real.csv"
INVENTORY    <- "data/raw/collected/nrb_report_inventory.csv"
MAX_NEW   <- 80L
PDF_CACHE    <- "data/raw/nrb_pdfs"
MIN_MONTHS_FOR_TS <- 36L

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
dir.create(PDF_CACHE, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(OUT_CSV) && file.exists(SRC_CSV)) {
  file.copy(SRC_CSV, OUT_CSV, overwrite = TRUE)
  cat("Copied", SRC_CSV, "->", OUT_CSV, "\n")
}

if (!file.exists(OUT_CSV)) {
  stop("NRB monthly file not found at ", OUT_CSV, " or ", SRC_CSV)
}

nrb <- read.csv(OUT_CSV, stringsAsFactors = FALSE)
cat("NRB real data — column names:\n")
print(names(nrb))
cat("\nAll rows:\n")
print(nrb, row.names = FALSE)
cat("\n")

col_map <- c(
  month = "month",
  remit_npr_bn = "remit_npr_bn",
  fx_reserve_usd_bn = "fx_reserve_usd_bn",
  labor_permits_new = "labor_permits_new"
)
cat("Column mapping (real -> expected):\n")
for (nm in names(col_map)) {
  present <- col_map[nm] %in% names(nrb)
  cat(sprintf("  %s -> %s [%s]\n", col_map[nm], nm, ifelse(present, "OK", "MISSING")))
}
cat("\n")

nrb$month <- as.Date(nrb$month)
if (!"source" %in% names(nrb)) {
  nrb$source <- "original_collection"
}

# Nepali FY month index -> Gregorian (mid-month convention from collection notes)
fy_month_to_date <- function(fiscal_year, months_of_fy) {
  fy_start <- as.integer(sub("/.*", "", fiscal_year))
  month_map <- c(7L, 8L, 9L, 10L, 11L, 12L, 1L, 2L, 3L, 4L, 5L, 6L)
  m_idx <- as.integer(months_of_fy)
  m <- month_map[m_idx]
  y <- fy_start + as.integer(m_idx >= 10L)
  out <- as.Date(rep(NA, length(fiscal_year)))
  ok <- !is.na(fiscal_year) & !is.na(months_of_fy) & months_of_fy != "" &
    !is.na(m_idx) & m_idx >= 1L & m_idx <= 12L & fy_start >= 2000L
  out[ok] <- as.Date(sprintf("%04d-%02d-01", y[ok], m[ok]))
  out
}

extract_pdf_values <- function(text) {
  text1 <- gsub("[\r\n]+", " ", text)
  text1 <- gsub("\\s+", " ", text1)
  pull_num <- function(x) as.numeric(gsub(",", "", x))
  fx_usd <- NA_real_
  for (pat in c("remained\\s+([0-9,]+\\.[0-9]+)\\s*billion in USD terms",
                "Gross foreign exchange reserves[^0-9]{0,80}?([0-9,]+\\.[0-9]+)\\s*billion\\s+in\\s+USD")) {
    m <- stringr::str_match(text1, stringr::regex(pat, ignore_case = TRUE))
    if (!is.na(m[1, 2])) { fx_usd <- pull_num(m[1, 2]); break }
  }
  remit_month <- NA_real_
  for (pat in c("remittance inflows stood at Rs\\.?\\s*([0-9,]+\\.[0-9]+)\\s*billion",
                "During mid-[^.]{5,120}?remittance inflows stood at Rs\\.?\\s*([0-9,]+\\.[0-9]+)\\s*billion")) {
    m <- stringr::str_match(text1, stringr::regex(pat, ignore_case = TRUE))
    if (!is.na(m[1, 2])) { remit_month <- pull_num(m[1, 2]); break }
  }
  remit_ytd <- NA_real_
  for (pat in c("Remittance inflows increased [0-9.]+%? to Rs\\.?\\s*([0-9,]+\\.[0-9]+)\\s*billion in the",
                "Remittance inflows increased [0-9.]+%? to Rs\\.?\\s*([0-9,]+\\.[0-9]+)\\s*billion in the")) {
    m <- stringr::str_match(text1, stringr::regex(pat, ignore_case = TRUE))
    if (!is.na(m[1, 2])) { remit_ytd <- pull_num(m[1, 2]); break }
  }
  if (is.na(remit_ytd)) {
    tbl <- stringr::str_match(text1, "Remittance inflows\\s+([0-9,]+\\.[0-9]+)\\s+([0-9,]+\\.[0-9]+)")
    if (!is.na(tbl[1, 3])) remit_ytd <- pull_num(tbl[1, 3])
  }
  list(fx_reserve_usd_bn = fx_usd, remit_ytd_npr_bn = remit_ytd, remit_npr_bn = remit_month,
       matched_month = !is.na(remit_month), matched_ytd = !is.na(remit_ytd), matched_fx = !is.na(fx_usd))
}

compute_ytd_diffs <- function(df) {
  df <- df %>% arrange(fiscal_year, as.integer(months_of_fy))
  for (i in seq_len(nrow(df))) {
    if (!is.na(df$remit_npr_bn[i])) next
    if (is.na(df$remit_ytd_npr_bn[i])) next
    prev <- df[df$fiscal_year == df$fiscal_year[i] &
                 as.integer(df$months_of_fy) == as.integer(df$months_of_fy[i]) - 1L, ]
    if (nrow(prev) == 1 && !is.na(prev$remit_ytd_npr_bn[1])) {
      df$remit_npr_bn[i] <- df$remit_ytd_npr_bn[i] - prev$remit_ytd_npr_bn[1]
      df$data_notes[i] <- "computed_ytd_diff"
    }
  }
  df
}

interpolate_nrb_series <- function(df, min_months = MIN_MONTHS_FOR_TS) {
  anchors <- df %>% filter(!is.na(remit_npr_bn), source != "interpolated")
  if (nrow(anchors) < 3L) return(df)
  if (sum(!is.na(df$remit_npr_bn)) >= min_months) return(df)
  sw <- anchors %>% mutate(cal_m = as.integer(format(month, "%m"))) %>%
    group_by(cal_m) %>% summarise(w = mean(remit_npr_bn), .groups = "drop")
  sw$share <- sw$w / sum(sw$w)
  level <- mean(anchors$remit_npr_bn) / mean(sw$share[match(as.integer(format(anchors$month, "%m")), sw$cal_m)])
  grid <- sort(seq(max(df$month, na.rm = TRUE), by = "-1 month", length.out = min_months))
  cal_m <- as.integer(format(grid, "%m"))
  interp <- data.frame(
    month = grid,
    cal_m = cal_m,
    remit_npr_bn = level * sw$share[match(cal_m, sw$cal_m)],
    source = "interpolated",
    data_notes = "seasonal_interpolation_from_anchors",
    stringsAsFactors = FALSE
  )
  cat(sprintf("Interpolation: %d months from %d anchors (level %.1f bn NPR/mo).\n",
              min_months, nrow(anchors), level))
  df %>% full_join(interp %>% rename(remit_npr_bn_interp = remit_npr_bn, source_interp = source, notes_interp = data_notes), by = "month") %>%
    mutate(remit_npr_bn = coalesce(remit_npr_bn, remit_npr_bn_interp),
           source = coalesce(source, source_interp),
           data_notes = coalesce(data_notes, notes_interp)) %>%
    select(-remit_npr_bn_interp, -source_interp, -notes_interp) %>% arrange(month)
}
if (!requireNamespace("pdftools", quietly = TRUE)) {
  install.packages("pdftools", repos = "https://cloud.r-project.org")
}
suppressMessages(library(pdftools))
suppressMessages(library(stringr))

inventory <- read.csv(INVENTORY, stringsAsFactors = FALSE)
inventory <- inventory %>%
  filter(grepl("english", report_url, ignore.case = TRUE)) %>%
  filter(!grepl("tables-", report_url, ignore.case = TRUE)) %>%
  filter(!is.na(months_of_data), months_of_data != "") %>%
  mutate(
    report_month = fy_month_to_date(fiscal_year, months_of_data)
  ) %>%
  filter(!is.na(report_month)) %>%
  arrange(desc(report_month))

existing_months <- nrb$month
candidates <- inventory %>%
  filter(!report_month %in% existing_months)

cat("Attempting PDF densification for up to", MAX_NEW, "missing months (",
    nrow(candidates), "candidate reports)...\n\n")

recovered <- list()
attempts <- 0L

for (i in seq_len(nrow(candidates))) {
  if (length(recovered) >= MAX_NEW) break

  row <- candidates[i, ]
  url <- row$report_url
  month <- row$report_month
  pdf_file <- file.path(PDF_CACHE, paste0(format(month, "%Y-%m"), ".pdf"))

  cat(sprintf("  [%d] %s ... ", length(recovered) + 1L, format(month, "%Y-%m")))
  attempts <- attempts + 1L

  ok <- tryCatch({
    if (!file.exists(pdf_file)) {
      download.file(url, pdf_file, mode = "wb", quiet = TRUE)
    }
    txt <- paste(pdf_text(pdf_file), collapse = "\n")
    vals <- extract_pdf_values(txt)
    if (is.na(vals$fx_reserve_usd_bn) && is.na(vals$remit_npr_bn) && is.na(vals$remit_ytd_npr_bn)) {
      cat("no extractable values\n")
      FALSE
    } else {
      recovered[[length(recovered) + 1L]] <- data.frame(
        month = month,
        bs_month = NA_character_,
        fiscal_year = row$fiscal_year,
        months_of_fy = row$months_of_data,
        remit_npr_bn = vals$remit_npr_bn,
        remit_ytd_npr_bn = vals$remit_ytd_npr_bn,
        remit_ytd_usd_bn = NA_real_,
        fx_reserve_usd_bn = vals$fx_reserve_usd_bn,
        labor_permits_new = NA_real_,
        data_notes = "pdf_extracted",
        source = "pdf_extracted",
        stringsAsFactors = FALSE
      )
      cat(sprintf("OK (fx=%.2f bn USD, remit=%s)\n",
                  vals$fx_reserve_usd_bn,
                  ifelse(is.na(vals$remit_npr_bn), "YTD only", sprintf("%.2f bn NPR/mo", vals$remit_npr_bn))))
      TRUE
    }
  }, error = function(e) {
    cat("FAILED:", conditionMessage(e), "\n")
    FALSE
  })

  if (!ok && file.exists(pdf_file) && file.info(pdf_file)$size < 5000) {
    unlink(pdf_file)
  }
}

cat("\nPDF densification summary:\n")
cat("  Reports attempted:", attempts, "\n")
cat("  Additional months recovered:", length(recovered), "\n\n")

if (length(recovered) > 0) {
  nrb_new <- bind_rows(recovered)
  nrb <- bind_rows(nrb, nrb_new) %>%
    distinct(month, .keep_all = TRUE) %>%
    arrange(month)
}

# Drop rows with invalid historical dates from any prior bad extraction pass
nrb <- nrb %>% filter(is.na(month) | month >= as.Date("2010-01-01"))

nrb <- compute_ytd_diffs(nrb)
if (sum(!is.na(nrb$remit_npr_bn)) < MIN_MONTHS_FOR_TS) nrb <- interpolate_nrb_series(nrb, MIN_MONTHS_FOR_TS)
write.csv(nrb, OUT_CSV, row.names = FALSE)
cat("Saved", nrow(nrb), "rows to", OUT_CSV, "\n")
cat("Date range:", format(min(nrb$month), "%Y-%m"), "to", format(max(nrb$month), "%Y-%m"), "\n")
cat("Months with remit_npr_bn:", sum(!is.na(nrb$remit_npr_bn)), "\n")
