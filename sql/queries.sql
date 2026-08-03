-- queries.sql

-- 1. Top 5 funds by AUM (from fact_performance snapshot)
SELECT f.scheme_name, f.fund_house, p.aum_crore
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
ORDER BY p.aum_crore DESC
LIMIT 5;

-- 2. Average NAV per month, per fund
SELECT f.scheme_name, d.year, d.month, AVG(n.nav) AS avg_nav
FROM fact_nav n
JOIN dim_date d ON d.date_id = n.date_id
JOIN dim_fund f ON f.amfi_code = n.amfi_code
GROUP BY f.scheme_name, d.year, d.month
ORDER BY f.scheme_name, d.year, d.month;

-- 3. SIP transactions by state
SELECT state, COUNT(*) AS n_sip_txns, SUM(amount_inr) AS total_sip_amount
FROM fact_transactions
WHERE transaction_type = 'SIP'
GROUP BY state
ORDER BY total_sip_amount DESC;

-- 4. Transactions by state (all types)
SELECT state, transaction_type, COUNT(*) AS n_txns, SUM(amount_inr) AS total_amount
FROM fact_transactions
GROUP BY state, transaction_type
ORDER BY state, total_amount DESC;

-- 5. Funds with expense_ratio < 1%
SELECT scheme_name, fund_house, expense_ratio_pct
FROM dim_fund
WHERE expense_ratio_pct < 1.0
ORDER BY expense_ratio_pct;

-- 6. Category-wise average 1yr and 3yr returns
SELECT f.category, AVG(p.return_1yr_pct) AS avg_1yr, AVG(p.return_3yr_pct) AS avg_3yr
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
GROUP BY f.category
ORDER BY avg_3yr DESC;

-- 7. Redemption-to-SIP ratio per fund (funds losing money relative to inflows)
SELECT amfi_code,
       SUM(CASE WHEN transaction_type = 'Redemption' THEN amount_inr ELSE 0 END) AS redemptions,
       SUM(CASE WHEN transaction_type = 'SIP' THEN amount_inr ELSE 0 END) AS sip_inflows,
       ROUND(1.0 * SUM(CASE WHEN transaction_type = 'Redemption' THEN amount_inr ELSE 0 END)
             / NULLIF(SUM(CASE WHEN transaction_type = 'SIP' THEN amount_inr ELSE 0 END), 0), 2) AS redemption_ratio
FROM fact_transactions
GROUP BY amfi_code
ORDER BY redemption_ratio DESC;

-- 8. Investor activity by age group and KYC status
SELECT age_group, kyc_status, COUNT(*) AS n_txns, AVG(amount_inr) AS avg_txn_size
FROM fact_transactions
GROUP BY age_group, kyc_status
ORDER BY age_group;

-- 9. Best risk-adjusted funds (Sharpe ratio, requires morningstar_rating >= 4)
SELECT f.scheme_name, p.sharpe_ratio, p.sortino_ratio, p.morningstar_rating
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
WHERE p.morningstar_rating >= 4
ORDER BY p.sharpe_ratio DESC
LIMIT 10;

-- 10. Month-over-month AUM growth by fund house
SELECT fund_house, date_id,
       aum_crore,
       aum_crore - LAG(aum_crore) OVER (PARTITION BY fund_house ORDER BY date_id) AS mom_change
FROM fact_aum
ORDER BY fund_house, date_id;