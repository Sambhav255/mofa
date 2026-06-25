# One-shot patch: rewrite 00c_ingest_nrb_real.R with corrected PDF regex + interpolation
out <- "scripts/00c_ingest_nrb_real.R"
lines <- readLines("scripts/00c_ingest_nrb_real.R")
# Replace MAX_NEW
lines <- gsub("^MAX_NEW      <- 20L", "MAX_NEW   <- 80L", lines)
lines <- gsub("^MAX_NEW   <- 20L", "MAX_NEW   <- 80L", lines)

# Inject MIN_MONTHS after PDF_CACHE line
if (!any(grepl("MIN_MONTHS_FOR_TS", lines))) {
  idx <- grep("^PDF_CACHE", lines)[1]
  lines <- c(lines[1:idx], "MIN_MONTHS_FOR_TS <- 24L", lines[(idx + 1):length(lines)])
}

# Replace extract_pdf_values function entirely
start <- grep("^extract_pdf_values", lines)[1]
end <- grep("^if \\(!requireNamespace\\(\"pdftools\"", lines)[1] - 1
new_extract <- c(
  'extract_pdf_values <- function(text) {',
  '  text1 <- gsub("[\\r\\n]+", " ", text)',
  '  text1 <- gsub("\\\\s+", " ", text1)',
  '  pull_num <- function(x) as.numeric(gsub(",", "", x))',
  '  fx_usd <- NA_real_',
  '  for (pat in c("remained\\\\s+([0-9,]+\\\\.[0-9]+)\\\\s*billion in USD terms",',
  '                "Gross foreign exchange reserves[^0-9]{0,80}?([0-9,]+\\\\.[0-9]+)\\\\s*billion\\\\s+in\\\\s+USD")) {',
  '    m <- stringr::str_match(text1, stringr::regex(pat, ignore_case = TRUE))',
  '    if (!is.na(m[1, 2])) { fx_usd <- pull_num(m[1, 2]); break }',
  '  }',
  '  remit_month <- NA_real_',
  '  for (pat in c("remittance inflows stood at Rs\\\\.?\\\\s*([0-9,]+\\\\.[0-9]+)\\\\s*billion",',
  '                "During mid-[^.]{5,120}?remittance inflows stood at Rs\\\\.?\\\\s*([0-9,]+\\\\.[0-9]+)\\\\s*billion")) {',
  '    m <- stringr::str_match(text1, stringr::regex(pat, ignore_case = TRUE))',
  '    if (!is.na(m[1, 2])) { remit_month <- pull_num(m[1, 2]); break }',
  '  }',
  '  remit_ytd <- NA_real_',
  '  for (pat in c("Remittance inflows increased [0-9.]+%? to Rs\\\\.?\\\\s*([0-9,]+\\\\.[0-9]+)\\\\s*billion in the",',
  '                "Remittance inflows increased [0-9.]+%? to Rs\\\\.?\\\\s*([0-9,]+\\\\.[0-9]+)\\\\s*billion in the")) {',
  '    m <- stringr::str_match(text1, stringr::regex(pat, ignore_case = TRUE))',
  '    if (!is.na(m[1, 2])) { remit_ytd <- pull_num(m[1, 2]); break }',
  '  }',
  '  if (is.na(remit_ytd)) {',
  '    tbl <- stringr::str_match(text1, "Remittance inflows\\\\s+([0-9,]+\\\\.[0-9]+)\\\\s+([0-9,]+\\\\.[0-9]+)")',
  '    if (!is.na(tbl[1, 3])) remit_ytd <- pull_num(tbl[1, 3])',
  '  }',
  '  list(fx_reserve_usd_bn = fx_usd, remit_ytd_npr_bn = remit_ytd, remit_npr_bn = remit_month,',
  '       matched_month = !is.na(remit_month), matched_ytd = !is.na(remit_ytd), matched_fx = !is.na(fx_usd))',
  '}'
)
lines <- c(lines[1:(start - 1)], new_extract, lines[(end + 1):length(lines)])

# Insert helper functions before pdftools if missing
if (!any(grepl("^compute_ytd_diffs", lines))) {
  idx <- grep("^if \\(!requireNamespace\\(\"pdftools\"", lines)[1] - 1
  helpers <- c(
    '',
    'compute_ytd_diffs <- function(df) {',
    '  df <- df %>% arrange(fiscal_year, as.integer(months_of_fy))',
    '  for (i in seq_len(nrow(df))) {',
    '    if (!is.na(df$remit_npr_bn[i])) next',
    '    if (is.na(df$remit_ytd_npr_bn[i])) next',
    '    prev <- df[df$fiscal_year == df$fiscal_year[i] &',
    '                 as.integer(df$months_of_fy) == as.integer(df$months_of_fy[i]) - 1L, ]',
    '    if (nrow(prev) == 1 && !is.na(prev$remit_ytd_npr_bn[1])) {',
    '      df$remit_npr_bn[i] <- df$remit_ytd_npr_bn[i] - prev$remit_ytd_npr_bn[1]',
    '      df$data_notes[i] <- "computed_ytd_diff"',
    '    }',
    '  }',
    '  df',
    '}',
    '',
    'interpolate_nrb_series <- function(df, min_months = MIN_MONTHS_FOR_TS) {',
    '  anchors <- df %>% filter(!is.na(remit_npr_bn), source != "interpolated")',
    '  if (nrow(anchors) < 3L) return(df)',
    '  if (sum(!is.na(df$remit_npr_bn)) >= min_months) return(df)',
    '  sw <- anchors %>% mutate(cal_m = as.integer(format(month, "%m"))) %>%',
    '    group_by(cal_m) %>% summarise(w = mean(remit_npr_bn), .groups = "drop")',
    '  sw$share <- sw$w / sum(sw$w)',
    '  level <- mean(anchors$remit_npr_bn) / mean(sw$share[match(as.integer(format(anchors$month, "%m")), sw$cal_m)])',
    '  grid <- sort(seq(max(df$month, na.rm = TRUE), by = "-1 month", length.out = min_months))',
    '  interp <- data.frame(month = grid, cal_m = as.integer(format(grid, "%m")),',
    '    remit_npr_bn = level * sw$share[match(cal_m, sw$cal_m)],',
    '    source = "interpolated", data_notes = "seasonal_interpolation_from_anchors", stringsAsFactors = FALSE)',
    '  cat(sprintf("Interpolation: %d months from %d anchors (level %.1f bn NPR/mo).\\n",',
    '              min_months, nrow(anchors), level))',
    '  df %>% full_join(interp %>% rename(remit_npr_bn_interp = remit_npr_bn, source_interp = source, notes_interp = data_notes), by = "month") %>%',
    '    mutate(remit_npr_bn = coalesce(remit_npr_bn, remit_npr_bn_interp),',
    '           source = coalesce(source, source_interp),',
    '           data_notes = coalesce(data_notes, notes_interp)) %>%',
    '    select(-remit_npr_bn_interp, -source_interp, -notes_interp) %>% arrange(month)',
    '}'
  )
  lines <- c(lines[1:idx], helpers, lines[(idx + 1):length(lines)])
}

# Insert compute_ytd + interpolate calls before final write.csv
widx <- grep("^write\\.csv\\(nrb, OUT_CSV", lines)[1]
if (!any(grepl("compute_ytd_diffs\\(nrb\\)", lines))) {
  pre <- c(
    'nrb <- compute_ytd_diffs(nrb)',
    'if (sum(!is.na(nrb$remit_npr_bn)) < MIN_MONTHS_FOR_TS) nrb <- interpolate_nrb_series(nrb, MIN_MONTHS_FOR_TS)'
  )
  lines <- c(lines[1:(widx - 1)], pre, lines[widx:length(lines)])
}

writeLines(lines, out)
cat("Patched", out, "\n")
