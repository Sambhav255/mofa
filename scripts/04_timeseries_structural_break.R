# ============================================================================
# 04_timeseries_structural_break.R
# ============================================================================

suppressMessages({
  library(dplyr)
  library(zoo)
  library(strucchange)
  library(tseries)
  library(forecast)
  library(ggplot2)
})

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

NRB_FILE <- if (exists("USE_REAL_DATA") && isTRUE(USE_REAL_DATA)) {
  "data/raw/nrb_remit_monthly_real.csv"
} else {
  "data/raw/nrb_remit_monthly_demo.csv"
}

nrb <- read.csv(NRB_FILE, stringsAsFactors = FALSE)
nrb$month <- as.Date(nrb$month)
nrb <- nrb %>% arrange(month)


select_consecutive_block <- function(df, min_months = 36L) {
  df <- df %>% filter(!is.na(remit_npr_bn)) %>% arrange(month)
  if (nrow(df) < min_months) return(df)
  gap <- c(FALSE, as.numeric(diff(df$month)) > 32)
  run_id <- cumsum(gap)
  run_tab <- tapply(seq_len(nrow(df)), run_id, length)
  pick <- as.integer(names(run_tab)[which.max(run_tab)])
  block <- df[run_id == pick, , drop = FALSE]
  if (nrow(block) > min_months) block <- tail(block, min_months)
  block
}
nrb_ts_all <- nrb %>%
  filter(!is.na(remit_npr_bn)) %>%
  arrange(month)

nrb_ts <- select_consecutive_block(nrb_ts_all, 36L)
cat(sprintf("Using %d consecutive months (%s to %s) for STL/ADF.

",
            nrow(nrb_ts), format(min(nrb_ts$month), "%Y-%m"), format(max(nrb_ts$month), "%Y-%m")))

if (nrow(nrb_ts) < 12) {
  warning("Only ", nrow(nrb_ts), " months with remit_npr_bn — time-series tests may be unreliable.")
}

ts_remit <- ts(
  nrb_ts$remit_npr_bn,
  start = c(as.integer(format(min(nrb_ts$month), "%Y")),
            as.integer(format(min(nrb_ts$month), "%m"))),
  frequency = 12
)

adf_level <- tryCatch(adf.test(ts_remit), error = function(e) list(statistic = NA, p.value = NA))
adf_diff  <- tryCatch(adf.test(diff(ts_remit)), error = function(e) list(statistic = NA, p.value = NA))

cat("=================================================================\n")
cat("1. AUGMENTED DICKEY-FULLER UNIT ROOT TEST\n")
cat("=================================================================\n")
cat(sprintf("  Levels:           Dickey-Fuller = %.3f, p = %.3f\n",
            adf_level$statistic, adf_level$p.value))
cat(sprintf("  First difference: Dickey-Fuller = %.3f, p = %.3f\n\n",
            adf_diff$statistic, adf_diff$p.value))

if (length(ts_remit) >= 36) {
  stl_fit <- stl(ts_remit, s.window = "periodic")
  png("output/figures/fig3_stl_decomposition.png", width = 1400, height = 900, res = 200)
  plot(stl_fit, main = "STL decomposition of NRB monthly remittance inflows")
  dev.off()
  cat("Saved output/figures/fig3_stl_decomposition.png\n\n")
} else {
  cat("STL decomposition skipped: fewer than 24 months with remit_npr_bn.\n\n")
}

if (nrow(nrb_ts) >= 10) {
  bp <- breakpoints(remit_npr_bn ~ 1, data = nrb_ts, h = 0.10)
  bp_dates <- nrb_ts$month[bp$breakpoints]
} else {
  bp_dates <- as.Date(character(0))
  cat("Structural break detection skipped: insufficient monthly observations.\n\n")
}

cat("=================================================================\n")
cat("2. ENDOGENOUS STRUCTURAL BREAK DETECTION\n")
cat("=================================================================\n")
print(bp_dates)
cat("\n")

png("output/figures/fig4_structural_breaks.png", width = 1400, height = 800, res = 200)
plot(nrb_ts$month, nrb_ts$remit_npr_bn, type = "l", col = "#13315c", lwd = 1.5,
     xlab = NULL, ylab = "Remittance inflow (NPR billion/month)",
     main = "NRB monthly remittance inflows with detected structural breaks")
if (length(bp_dates) > 0) {
  abline(v = bp_dates, col = "#b3001b", lty = 2, lwd = 1.5)
}
dev.off()
cat("Saved output/figures/fig4_structural_breaks.png\n\n")

run_its_chow <- function(data, event_date, label) {
  data <- data %>% filter(!is.na(remit_npr_bn))
  d <- data %>%
    mutate(t = as.numeric(month - min(month)) / 30.44,
           post = as.integer(month >= as.Date(event_date)),
           t_post = post * (as.numeric(month - as.Date(event_date)) / 30.44))

  event_idx <- which(d$month >= as.Date(event_date))[1]
  n_post <- sum(d$post, na.rm = TRUE)

  if (is.na(event_idx) || n_post < 6) {
    cat(sprintf("--- ITS model + Chow test: %s (%s) ---\n", label, event_date))
    if (label == "upi_npi") {
      cat("UPI-NPI break test skipped: fewer than 6 post-event observations available.\n")
      cat("Report qualitatively.\n\n")
    } else {
      cat(sprintf("  SKIPPED: only %d month(s) of post-event data available.\n\n", n_post))
    }
    return(list(model = NULL, chow = NULL, skipped = TRUE, n_post = n_post))
  }

  its_model <- lm(remit_npr_bn ~ t + post + t_post, data = d)

  chow <- tryCatch(
    sctest(remit_npr_bn ~ t, data = d, type = "Chow", point = event_idx),
    error = function(e) {
      cat(sprintf("Chow test failed for %s: %s\n", label, conditionMessage(e)))
      NULL
    }
  )

  cat(sprintf("--- ITS model + Chow test: %s (%s) ---\n", label, event_date))
  print(summary(its_model)$coefficients)
  if (!is.null(chow)) {
    cat(sprintf("Chow test: F = %.3f, p = %.4f\n\n", chow$statistic, chow$p.value))
  } else {
    cat("Chow test: skipped (inadmissible change point for this sparse series).\n\n")
  }

  list(model = its_model, chow = chow, skipped = FALSE, n_post = n_post)
}

events <- list(
  covid    = "2020-03-01",
  fatf     = "2025-02-01",
  upi_npi  = "2026-06-01"
)

cat("=================================================================\n")
cat("3. INTERRUPTED TIME SERIES + CHOW TEST AT NAMED EVENT DATES\n")
cat("=================================================================\n")
results <- lapply(names(events), function(nm) run_its_chow(nrb_ts, events[[nm]], nm))
names(results) <- names(events)

chow_summary <- do.call(rbind, lapply(names(events), function(nm) {
  r <- results[[nm]]
  if (isTRUE(r$skipped)) {
    data.frame(event = nm, date = events[[nm]],
               chow_F = NA, chow_p = NA,
               note = paste0("skipped - only ", r$n_post, " post-event month(s) of data"))
  } else {
    data.frame(event = nm, date = events[[nm]],
               chow_F = if (!is.null(r$chow)) round(r$chow$statistic, 3) else NA,
               chow_p = if (!is.null(r$chow)) round(r$chow$p.value, 4) else NA,
               note = if (is.null(r$chow)) "chow test failed" else "")
  }
}))
write.csv(chow_summary, "output/tables/table4_chow_test_summary.csv", row.names = FALSE)

cat("04_timeseries_structural_break.R complete.\n")
