# Data Dictionary — Bluestock MF Analytics Platform

This document describes every table in `bluestock_mf.db`: what each column means, its
data type, and where the underlying data originally came from. The database follows a
star schema (see `sql/schema.sql`): two dimension tables (`dim_fund`, `dim_date`)
describe "who/what/when", and four fact tables (`fact_nav`, `fact_transactions`,
`fact_performance`, `fact_aum`) hold the measurable events/numbers, each referencing
the dimensions by key rather than repeating descriptive text.

---

## dim_fund
One row per mutual fund scheme. Primary key: `amfi_code`.

| Column | Type | Description | Source |
|---|---|---|---|
| amfi_code | INTEGER (PK) | AMFI-assigned unique identifier for the scheme | 01_fund_master.csv |
| fund_house | TEXT | Asset Management Company (AMC) that manages the fund, e.g. "SBI Mutual Fund" | 01_fund_master.csv |
| scheme_name | TEXT | Full official name of the scheme, including plan/option | 01_fund_master.csv |
| category | TEXT | Broad SEBI category, e.g. Equity, Debt | 01_fund_master.csv |
| sub_category | TEXT | Finer category, e.g. Large Cap, Small Cap, Gilt | 01_fund_master.csv |
| plan | TEXT | Regular or Direct plan | 01_fund_master.csv |
| launch_date | DATE | Date the scheme was first launched | 01_fund_master.csv |
| benchmark | TEXT | Index this fund is measured against, e.g. "NIFTY 100 TRI" | 01_fund_master.csv |
| expense_ratio_pct | REAL | Annual fee charged as % of AUM | 01_fund_master.csv |
| exit_load_pct | REAL | Penalty % charged for early redemption | 01_fund_master.csv |
| min_sip_amount | INTEGER | Minimum monthly SIP investment allowed (INR) | 01_fund_master.csv |
| min_lumpsum_amount | INTEGER | Minimum one-time lumpsum investment allowed (INR) | 01_fund_master.csv |
| fund_manager | TEXT | Name of the person managing the scheme | 01_fund_master.csv |
| risk_category | TEXT | SEBI risk label, e.g. Moderate, Very High | 01_fund_master.csv |
| sebi_category_code | TEXT | SEBI's own scheme classification code, e.g. "EC01" | 01_fund_master.csv |

---

## dim_date
One row per calendar day from 2022-01-01 to 2026-12-31, generated in code
(`load_to_sqlite.py`), not sourced from a raw CSV. Primary key: `date_id`.

| Column | Type | Description | Source |
|---|---|---|---|
| date_id | INTEGER (PK) | Date encoded as YYYYMMDD, e.g. 20240115 for 2024-01-15 | Generated |
| full_date | DATE | The actual calendar date | Generated |
| year | INTEGER | Calendar year | Generated |
| month | INTEGER | Month number (1-12) | Generated |
| month_name | TEXT | Month name, e.g. "January" | Generated |
| quarter | INTEGER | Calendar quarter (1-4) | Generated |
| day_of_week | TEXT | Day name, e.g. "Monday" | Generated |
| is_weekend | INTEGER | 0/1 flag — 1 if Saturday or Sunday (SQLite has no native boolean type) | Generated |

---

## fact_nav
One row per (fund, date) NAV observation. Grain: one row per `amfi_code` per day.

| Column | Type | Description | Source |
|---|---|---|---|
| nav_id | INTEGER (PK, autoincrement) | Surrogate key, no business meaning | Generated |
| amfi_code | INTEGER (FK -> dim_fund) | Which fund this NAV belongs to | 02_nav_history.csv |
| date_id | INTEGER (FK -> dim_date) | Which date this NAV was recorded on | 02_nav_history.csv |
| nav | REAL | Net Asset Value — price per unit of the fund on that date | 02_nav_history.csv |

**Cleaning applied (Task 1):** parsed dates, sorted by amfi_code+date, removed
(amfi_code, date) duplicates, dropped NAV <= 0, forward-filled NAV across weekends/
holidays by reindexing each fund to a full daily calendar. See
`notebooks/01_day2_cleaning_and_loading.ipynb` for the code and print-output proof
(counts found at each step).

---

## fact_transactions
One row per investor transaction. Grain: one row per transaction event.

| Column | Type | Description | Source |
|---|---|---|---|
| transaction_id | INTEGER (PK, autoincrement) | Surrogate key, no business meaning | Generated |
| investor_id | TEXT | Unique investor identifier (repeats across multiple transactions per investor) | 08_investor_transactions.csv |
| amfi_code | INTEGER (FK -> dim_fund) | Which fund the transaction was made against | 08_investor_transactions.csv |
| date_id | INTEGER (FK -> dim_date) | Date the transaction occurred | 08_investor_transactions.csv |
| transaction_type | TEXT | SIP, Lumpsum, or Redemption | 08_investor_transactions.csv |
| amount_inr | INTEGER | Transaction amount in INR | 08_investor_transactions.csv |
| state | TEXT | Investor's state | 08_investor_transactions.csv |
| city | TEXT | Investor's city | 08_investor_transactions.csv |
| city_tier | TEXT | City tier classification, e.g. "T30" | 08_investor_transactions.csv |
| age_group | TEXT | Investor's age bracket, e.g. "18-25" | 08_investor_transactions.csv |
| gender | TEXT | Investor's gender | 08_investor_transactions.csv |
| annual_income_lakh | REAL | Investor's self-reported annual income, in lakh INR | 08_investor_transactions.csv |
| payment_mode | TEXT | How the transaction was paid, e.g. UPI | 08_investor_transactions.csv |
| kyc_status | TEXT | Verified or Pending | 08_investor_transactions.csv |

**Design note:** investor demographic columns (state, city, age_group, gender, income)
are kept flat inside this fact table rather than normalized into a separate
`dim_investor` table, even though `investor_id` repeats (5,000 unique investors
across 32,778 transactions). This was a scope decision — the brief specified exactly
these 6 tables. A purer star schema would pull investor attributes into their own
dimension table to remove repetition and support investor-level analysis independent
of individual transactions.

**Cleaning applied (Task 2):** standardised `transaction_type` casing, validated
`amount_inr > 0`, coerced unparseable dates to NaT and dropped them, checked
`kyc_status` against the {Verified, Pending} enum, removed exact duplicate rows.

---

## fact_performance
One row per fund — a single performance snapshot, not a time series. Primary key:
`amfi_code` (no surrogate key needed since there's no repeating grain).

| Column | Type | Description | Source |
|---|---|---|---|
| amfi_code | INTEGER (PK, FK -> dim_fund) | Which fund this snapshot belongs to | 07_scheme_performance.csv |
| return_1yr_pct | REAL | Trailing 1-year return, % | 07_scheme_performance.csv |
| return_3yr_pct | REAL | Trailing 3-year annualised return, % | 07_scheme_performance.csv |
| return_5yr_pct | REAL | Trailing 5-year annualised return, % | 07_scheme_performance.csv |
| benchmark_3yr_pct | REAL | The fund's benchmark's 3-year return, % (for comparison) | 07_scheme_performance.csv |
| alpha | REAL | Excess return vs benchmark after adjusting for risk (Jensen's Alpha) | 07_scheme_performance.csv |
| beta | REAL | Fund's volatility relative to the benchmark (1.0 = moves with the market) | 07_scheme_performance.csv |
| sharpe_ratio | REAL | Return earned per unit of total risk (see below) | 07_scheme_performance.csv |
| sortino_ratio | REAL | Return earned per unit of *downside* risk only (see below) | 07_scheme_performance.csv |
| std_dev_ann_pct | REAL | Annualised standard deviation of returns — a volatility measure | 07_scheme_performance.csv |
| max_drawdown_pct | REAL | Largest peak-to-trough loss the fund has experienced, % (negative) | 07_scheme_performance.csv |
| aum_crore | INTEGER | Assets Under Management for this fund, in INR crore | 07_scheme_performance.csv |
| expense_ratio_pct | REAL | Annual fee as % of AUM (duplicated from dim_fund at time of performance snapshot) | 07_scheme_performance.csv |
| morningstar_rating | INTEGER | Star rating, 1-5 | 07_scheme_performance.csv |
| risk_grade | TEXT | Qualitative risk label, e.g. Moderate, Very High | 07_scheme_performance.csv |

**Concepts, explained from scratch:**
- **Sharpe ratio** = (fund return - risk-free rate) / standard deviation of fund
  returns. It answers: "for the total risk (volatility) I took on, how much extra
  return did I get over a safe investment?" Higher is better. It penalises *all*
  volatility, including upside surprises, which is its main criticism.
- **Sortino ratio** = same idea as Sharpe, but the denominator only counts
  *downside* volatility (returns below a target, usually 0 or the risk-free rate).
  It answers the same question but doesn't punish a fund for occasionally
  overperforming — only for the risk of losing money. Generally considered a fairer
  risk-adjusted measure than Sharpe for this reason.
- **Alpha** = how much better (or worse) the fund did than its benchmark, after
  accounting for the risk (beta) it took on. Positive alpha = the fund manager added
  value beyond what you'd expect just from market exposure.
- **Beta** = how much the fund moves relative to its benchmark. Beta of 1.2 means
  the fund tends to move 20% more than the benchmark in either direction (more
  volatile); beta of 0.8 means it's less volatile than the benchmark.
- **Max drawdown** = the worst-case peak-to-trough decline in the fund's value over
  the observed period — a plain "how bad could it get" number, independent of
  Sharpe/Sortino's averaging.

**Cleaning applied (Task 3):** coerced all numeric columns with `pd.to_numeric`,
flagged (not dropped) rows with a positive max_drawdown_pct or negative std_dev,
flagged rows with expense_ratio_pct outside 0.1-2.5%. Flag columns
(`flag_bad_drawdown`, `flag_bad_stddev`, `flag_expense_out_of_range`) exist in
`data/processed/scheme_performance_clean.csv` for manual review, but are dropped
before loading into `fact_performance` since they're a QA artifact, not part of the
fact table's schema.

---

## fact_aum
One row per (fund house, date) AUM snapshot. Grain: one row per `fund_house` per
reporting date.

| Column | Type | Description | Source |
|---|---|---|---|
| aum_id | INTEGER (PK, autoincrement) | Surrogate key, no business meaning | Generated |
| date_id | INTEGER (FK -> dim_date) | Reporting date for this AUM snapshot | 03_aum_by_fund_house.csv |
| fund_house | TEXT | Asset Management Company name | 03_aum_by_fund_house.csv |
| aum_lakh_crore | REAL | Total AUM in lakh-crore INR (1 lakh crore = 10^12 INR) | 03_aum_by_fund_house.csv |
| aum_crore | INTEGER | Total AUM in crore INR (1 crore = 10^7 INR) | 03_aum_by_fund_house.csv |
| num_schemes | INTEGER | Number of schemes this fund house offers as of this date | 03_aum_by_fund_house.csv |

---

## Row counts (verified at load time, `load_to_sqlite.py` output)

| Table | Row count |
|---|---|
| dim_date | 1,826 |
| dim_fund | 40 |
| fact_nav | 64,320 |
| fact_transactions | 32,778 |
| fact_performance | 40 |
| fact_aum | 90 |

All counts matched their source dataframe row counts exactly at load time (no rows
silently dropped or duplicated during the `to_sql` insert).
