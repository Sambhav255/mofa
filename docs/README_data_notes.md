# Nepal Remittance Corridor Data — Collection Notes
Collection date: 2026-06-24. Prepared for the MOFA Korea–Nepal remittance corridor brief.

This package contains three datasets. Every figure below was pulled from a live primary
source on the collection date; nothing is fabricated. Where a value could not be obtained,
the cell is left blank and the reason is recorded in a notes column. Read the limitations
for each dataset before citing.

---

## 1. Korea → Nepal operator fees — `korea_nepal_operator_fees.csv`

**Mid-market benchmark:** XE.com, 1 KRW = 0.0982839 NPR (Jun 24 2026, 05:35 UTC).

**What was obtained:** Published flat transfer fees (KRW) for the operators that publish them.
Columns are the ones you specified plus a `notes` column.

**Critical limitation — FX margins were NOT captured.** None of these operators publish a live
KRW→NPR exchange rate on the open web; the rate is shown only inside the logged-in app or
calculator. No browser session was available to drive those calculators in this run, so the
`fx_margin_pct` column is blank for every operator and `total_cost_pct` reflects the flat fee
ONLY (a lower bound). To complete the FX margin you (or a follow-up run with the Claude-in-Chrome
extension connected) must read each operator's quoted NPR rate for a KRW 500,000 and KRW 1,000,000
send and compute (mid − quoted)/mid.

**Flat fees and their status:**
- Rupeesend — 5,000 KRW flat, confirmed on rupeesend.co.kr (pays out in NPR; 50% student discount).
- Hanpass — 5,000 KRW to Nepal, per Hanpass notice/FAQ.
- GME — published "from 5,000 KRW"; runs zero-fee Nepal promotions.
- WireBarley — advertises **zero fee** to Nepal (eSewa wallet payout); generic SWIFT-SHA fee is
  3,000 KRW (<3M won) per its KR help article. Recorded as 0 with note.
- Sentbe — ~5,000 KRW cited for comparable corridors; Nepal-specific fee not separately published (unconfirmed).
- SBI Cosmoney — single-fee model, ~3,000 KRW to US; Nepal fee not published (unconfirmed).
- E9pay — no public flat fee for KRW→NPR found (app-gated); left blank.
- KB Kookmin (bank) — internet TT ≈ 8,000 KRW (remittance fee 3,000 + cable fee 5,000); USD-routed.
- **Korea Post (bank) — does NOT serve Nepal.** Its Eurogiro service covers only Japan, Mongolia,
  Philippines, Sri Lanka, Switzerland and Thailand. No KRW→NPR corridor exists. Rows left blank.

The Monito aggregator was checked and does **not** cover any of these Korean MTOs for KRW→NPR
(its only listed provider pays out in USD), so it could not supply per-operator margins.

---

## 2. World Bank RPW Nepal corridors — `rpw_nepal_corridors.csv`

**Headline finding for your brief:** The World Bank Remittance Prices Worldwide database does **NOT
cover the Korea → Nepal corridor.** Korea (Korea, Rep.) appears as a *sending* country to other
destinations, but there is no Korea→Nepal corridor in any quarter 2011–Q3 2025. This is the gap your
primary operator data fills.

**Source / access process (your Step 2):** The data-download page offers an **instant, no-registration
Excel download** — no form, no email. The current public link on the page points to the
World Bank Data Catalog file (dataset 0037898), the *complete dataset* covering 2011–Q3 2025
(50 MB, `rpw_dataset_2011_2025_q3.xlsx`). It downloaded directly. (The DataBank corridor portal in
Step 3 was therefore not needed — the full firm-level dataset already contains every Nepal corridor.)

**What the CSV contains:** Corridor averages I computed from the firm-level dataset for the latest
available quarter (**2025 Q3**) at both the USD 200 and USD 500 send amounts, for the four corridors
you asked about (Saudi Arabia, UAE, Qatar, Malaysia → Nepal). `total_cost_pct` = mean total cost
across transparent services; `mto_cost_pct` / `bank_cost_pct` = means within firm type (Qatar and
Malaysia have no banks in-sample, so bank cost is blank). `pct_digital` is an approximation
(digital access point + non-cash funding). All four corridors are covered; India, Oman, UK and US →
Nepal are also in the dataset if you want them later.

---

## 3. NRB monthly remittance series — `nrb_remit_monthly_real.csv`

**Source:** NRB "Current Macroeconomic and Financial Situation (English)" reports, parsed from the
official PDFs. Each report states cumulative (year-to-date from mid-July) remittance, and recent
reports also state the single most-recent month directly.

**Coverage obtained:** 13 report cut-off months spanning FY2021/22 to FY2025/26. FX reserves (USD bn)
were extracted for all 13; cumulative remittance for 12; single-month remittance for 6 (4 stated
directly, 1 = month-1 cumulative, 1 computed by differencing consecutive cumulatives); labour permits
(first-time approval, YTD) for the recent reports. `month` is the Gregorian first-of-month of the
Nepali month the data covers; `bs_month` gives the Bikram Sambat year + Nepali month. Convention:
Shrawan→Jul, Bhadra→Aug, … Ashadh→Jun; BS year rolls at Baishakh. Every cell's provenance is in
`data_notes` (extracted vs computed vs cumulative-only).

**Limitation — this is not yet a continuous monthly series.** NRB gates each report's PDF link behind
JavaScript, so the ~130 monthly PDFs (2011–present) cannot be bulk-downloaded by script. I retrieved a
representative scatter by resolving direct PDF URLs through search. `nrb_report_inventory.csv` (and
`all_cmes_report_urls.txt`) catalogue the full English report archive so the series can be completed —
either by connecting the Claude-in-Chrome extension (which renders the gated links) or by resolving
the remaining months the same way. `labor_permits_new` currently holds the YTD cumulative first-time
approval count, not a monthly-new figure, except where noted.

---

## Files
- `korea_nepal_operator_fees.csv` — operator flat fees (FX margin pending app access)
- `rpw_nepal_corridors.csv` — World Bank corridor averages, 2025 Q3
- `nrb_remit_monthly_real.csv` — NRB remittance / FX reserves / permits
- `nrb_report_inventory.csv` — catalogue of NRB English report URLs (FY2011/12+)
- `all_cmes_report_urls.txt` — full raw list of all CMES report permalinks (760)
- `rpw_dataset_2011_2025_q3.xlsx` — the complete World Bank RPW source file (50 MB)
