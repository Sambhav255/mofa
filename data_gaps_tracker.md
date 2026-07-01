# Data Gaps Tracker

MoFA Cluster 10 brief · Last updated: 1 July 2026

| # | Gap | Status | How to obtain | What it changes in the brief | Date obtained |
|---|---|---|---|---|---|
| 1 | **Korea MTO FX margin** — live KRW 500,000 → NPR quote (WireBarley or GME) | OPEN | One NRNA Korea member screenshots a transfer quote with date; post in NRNA Korea Facebook group | Replaces fee-only lower bound (0.77%) with a real total-cost figure; tightens Korea vs Gulf comparison | — |
| 2 | **DoFE EPS worker count by year** (2007–2025), active count + first-time departure approvals for Korea | **REQUESTED** (1 Jul 2026) | Formal request routed via Nikhil Sangroula / Institute of Foreign Affairs to DoFE Statistics Section | Grounds corridor volume beyond NLSS IV survey estimate (USD 484M/year); supports "invisible corridor" framing | — |
| 3 | **NRB Korea corridor RSP transaction volume** FY2023/24 and FY2024/25, plus monthly BoP remittance series FY2014/15–present | **REQUESTED** (1 Jul 2026) | Formal request routed via Nikhil Sangroula / Institute of Foreign Affairs to NRB (BoP Division / FEMD for the RSP volume; Research Department for the monthly series) | Validates or challenges survey-based volume; strengthens monitoring recommendation | — |
| 4 | **IOM post-2020 survey** on EPS worker formal remittance channel usage rate (baseline: IOM Seoul 2017, ~80% informal) | **REQUESTED** (1 Jul 2026) | Formal request routed via Nikhil Sangroula / Institute of Foreign Affairs to IOM Nepal MRIC, possibly forwarded to IOM Seoul | Informs informal-share assumption and formalization-value estimate | — |
| 5 | **BLA comparison** — Gulf MOU (2007), Malaysia MOU (2003/2018), Japan MOUs | OPEN | Desk research: scan MOU text for remittance, payment channel, or financial literacy clauses | Load-bearing for June 25 reframe; populates `table7_bla_comparison.csv` Gulf/Malaysia/Japan rows and `fig8_bla_gap_matrix.png` | — |

## Closed gaps

_None yet._

## Notes

- Gap 1 is **critical** — every Korea cost figure in the pipeline is a lower bound until FX margin is captured. It is the one gap with no formal request in flight (routed informally via NRNA Korea instead).
- Gaps 2–4 were formally requested on 1 July 2026 in a single email to Nikhil Sangroula (nsangroula379@gmail.com) at the Institute of Foreign Affairs, who is routing them internally to DoFE, NRB, and IOM Nepal respectively. Response not yet received — treat as pending, not confirmed.
- Gap 5 does not require new quantitative data; one afternoon of MOU text review closes the scaffold in `scripts/07_bla_comparative_analysis.R`.
- When a gap closes, update the Status column to CLOSED, fill in Date obtained, and re-run the relevant pipeline script if applicable.
