# Step 6: Building the Regulatory Reporting Layer

**Estimated time: 25 minutes**

This step creates three FCA/PRA regulatory reporting views in the REPORTING schema. These views read from the STAGING layer and produce compliance metrics that a UK retail bank must report to regulators.

Open your `05_REPORTING` worksheet and work through `scripts/05_reporting_layer.sql`.

## Report 1: Liquidity Coverage Ratio (LCR)

The LCR ensures a bank holds enough high-quality liquid assets (HQLA) to survive a 30-day stress scenario.

**Formula:** `LCR = Total HQLA / Net Cash Outflows (30-day stress) x 100`

**Regulatory minimum**: 100% (PRA post-Brexit maintained from CRD IV)

- **Numerator:** Sum of HQLA Level 1 + Level 2A account balances
- **Denominator:** Gross outflows (weighted by run-off rates) minus inflows (capped at 75% of outflows)

The `V_LCR_COMPONENTS` view uses a multi-CTE structure to calculate LCR in stages. The key join to the reference data loaded in Step 4:
```sql
LEFT JOIN runoff_rates_dedup r
    ON a.lcr_liability_category = r.liability_category
```

This is why storing run-off rates as a table matters — if the PRA updates the rates, you reload the CSV and every LCR calculation immediately reflects the new rates, without changing a single line of SQL.

Run the LCR view and check the output:
```sql
SELECT
    reporting_date,
    ROUND(total_hqla_gbp / 1000000, 2)       AS hqla_millions_gbp,
    ROUND(net_outflows_30d_gbp / 1000000, 2) AS net_outflows_millions_gbp,
    lcr_ratio_pct,
    lcr_status
FROM REPORTING.V_LCR_COMPONENTS;
```

## Report 2: Capital Adequacy Ratio (CAR)

The CAR measures whether a bank has enough capital to absorb losses from its loan book.

**Formula:** `Tier 1 Capital Ratio = Tier 1 Capital / Risk-Weighted Assets x 100`

**Regulatory minimum**: Tier 1 >= 6.0%, Total Capital >= 8.0% (plus PRA buffers)

- **RWA:** Each loan's outstanding balance multiplied by its Basel III risk weight
- **Tier 1 Capital proxy:** Aggregate BOND account balances
- **Regulatory minimums:** CET1 >= 4.5%, Tier 1 >= 6.0%, Total Capital >= 8.0%

The `V_CAPITAL_ADEQUACY` view aggregates risk-weighted assets from the staged loan book. Risk weights are defined in the PRODUCTS table per Basel III standardised approach:
- Residential mortgages: **35%**
- Buy-to-let mortgages: **50%**
- Personal / auto loans: **75%**

Run and check:
```sql
SELECT
    tier1_ratio_pct,
    tier1_status,
    ROUND(total_rwa_gbp / 1000000, 2) AS rwa_millions_gbp
FROM REPORTING.V_CAPITAL_ADEQUACY;
```

## Report 3: Large Exposures Register

The PRA mandates that no single counterparty exposure may exceed 25% of Tier 1 capital.

**Rule:** `Exposure per customer = Loan balances + Deposit balances`

PRA Rulebook — Large Exposures 4.1. No single exposure may exceed **25% of Tier 1 capital**.

The `V_LARGE_EXPOSURES` view aggregates per-customer exposure across all products:
```sql
COALESCE(l.loan_exposure_gbp, 0) +
    COALESCE(d.deposit_exposure_gbp, 0) AS total_exposure_gbp
```

And flags breaches:
```sql
CASE
    WHEN (total_exposure_gbp / tier1_capital_gbp) > 0.25 THEN 'BREACH'
    WHEN (total_exposure_gbp / tier1_capital_gbp) > 0.20 THEN 'WARNING'
    ELSE 'OK'
END  AS large_exposure_flag
```

The 20% threshold creates a warning buffer — giving the risk team visibility of customers approaching the regulatory limit before a breach occurs.

Customers exceeding 25% are flagged as BREACH; those above 20% are flagged as WARNING.

Run and check for any breaches:
```sql
SELECT large_exposure_flag, COUNT(*) AS customer_count
FROM REPORTING.V_LARGE_EXPOSURES
GROUP BY large_exposure_flag;
```

> With synthetic random data, you may see a small number of breaches — this is expected and realistic. In a real bank, breaches would trigger an immediate escalation to the risk team.

## Run the Full Script

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Step 6 - Regulatory Reporting Layer
--
-- This script builds three FCA/PRA regulatory reporting views:
--
--   1. V_LCR_COMPONENTS     — Liquidity Coverage Ratio (Basel III / CRD IV)
--   2. V_CAPITAL_ADEQUACY   — Capital Adequacy Report (Basel III Pillar 1)
--   3. V_LARGE_EXPOSURES    — Large Exposures Register (PRA 25% capital limit)
--
-- These views sit in the REPORTING schema and read from STAGING views,
-- joining to the LCR run-off rates reference table loaded in Step 4.
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- REPORT 1: LIQUIDITY COVERAGE RATIO (LCR)
--
-- LCR = High Quality Liquid Assets (HQLA) / Net Cash Outflows (30-day stress)
--
-- Regulatory minimum: 100% (PRA requirement, post-Brexit maintained)
--
-- Components:
--   NUMERATOR   : HQLA stock — Level 1 + Level 2A (capped at 40%) + Level 2B (capped at 15%)
--   DENOMINATOR : Net cash outflows = Gross outflows − min(inflows, 75% of outflows)
--
-- Simplified approach for this lab:
--   - HQLA: sum of HQLA_L1 and HQLA_L2A account balances
--   - Net outflows: sum of CLEARED debit transactions in rolling 30 days,
--     multiplied by run-off rate for the account's liability category
--   - Inflows: sum of CLEARED credit transactions in rolling 30 days x 100%
-- =============================================================================
CREATE OR REPLACE VIEW REPORTING.V_LCR_COMPONENTS
COMMENT = 'Liquidity Coverage Ratio components — Basel III / CRD IV. Regulatory minimum: LCR >= 100%'
AS
WITH

hqla_stock AS (
    SELECT
        a.lcr_liability_category,
        a.lcr_category,
        SUM(a.balance_gbp)                                  AS balance_gbp
    FROM STAGING.STG_ACCOUNTS_V  a
    WHERE a.lcr_category IN ('HQLA_L1', 'HQLA_L2A')
    GROUP BY a.lcr_liability_category, a.lcr_category
),

hqla_summary AS (
    SELECT
        SUM(CASE WHEN lcr_category = 'HQLA_L1'  THEN balance_gbp ELSE 0 END) AS hqla_l1_gbp,
        SUM(CASE WHEN lcr_category = 'HQLA_L2A' THEN balance_gbp ELSE 0 END) AS hqla_l2a_gbp
    FROM hqla_stock
),

runoff_rates_dedup AS (
    SELECT
        liability_category,
        MAX(run_off_rate_pct) AS run_off_rate_pct
    FROM RAW.LCR_RUNOFF_RATES
    WHERE sub_category NOT IN ('FIXED_TERM_RESIDUAL_GT_30D')
    GROUP BY liability_category
),

gross_outflows AS (
    SELECT
        a.lcr_liability_category,
        r.run_off_rate_pct,
        SUM(t.amount_gbp)                                   AS gross_outflow_gbp,
        SUM(t.amount_gbp * (COALESCE(r.run_off_rate_pct, 10) / 100)) AS weighted_outflow_gbp
    FROM STAGING.STG_TRANSACTIONS_V  t
    JOIN STAGING.STG_ACCOUNTS_V      a ON t.account_id = a.account_id
    LEFT JOIN runoff_rates_dedup     r
        ON a.lcr_liability_category = r.liability_category
    WHERE t.debit_credit       = 'DEBIT'
      AND t.transaction_date   >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY a.lcr_liability_category, r.run_off_rate_pct
),

gross_inflows AS (
    SELECT
        SUM(t.amount_gbp)                                   AS gross_inflow_gbp
    FROM STAGING.STG_TRANSACTIONS_V  t
    JOIN STAGING.STG_ACCOUNTS_V      a ON t.account_id = a.account_id
    WHERE t.debit_credit       = 'CREDIT'
      AND t.transaction_date   >= DATEADD('day', -30, CURRENT_DATE())
),

outflow_summary AS (
    SELECT SUM(weighted_outflow_gbp) AS total_weighted_outflow_gbp FROM gross_outflows
),

lcr_calc AS (
    SELECT
        h.hqla_l1_gbp,
        h.hqla_l2a_gbp,
        h.hqla_l1_gbp + h.hqla_l2a_gbp                    AS total_hqla_gbp,
        o.total_weighted_outflow_gbp                        AS gross_outflows_gbp,
        i.gross_inflow_gbp,
        -- Net outflows = gross outflows minus inflows (capped at 75% of outflows)
        o.total_weighted_outflow_gbp -
            LEAST(i.gross_inflow_gbp, o.total_weighted_outflow_gbp * 0.75) AS net_outflows_gbp
    FROM hqla_summary   h
    CROSS JOIN outflow_summary o
    CROSS JOIN gross_inflows   i
)
SELECT
    CURRENT_DATE()                                          AS reporting_date,
    ROUND(hqla_l1_gbp, 2)                                  AS hqla_level1_gbp,
    ROUND(hqla_l2a_gbp, 2)                                 AS hqla_level2a_gbp,
    ROUND(total_hqla_gbp, 2)                               AS total_hqla_gbp,
    ROUND(gross_outflows_gbp, 2)                           AS gross_outflows_30d_gbp,
    ROUND(gross_inflow_gbp, 2)                             AS gross_inflows_30d_gbp,
    ROUND(net_outflows_gbp, 2)                             AS net_outflows_30d_gbp,
    CASE
        WHEN net_outflows_gbp > 0
        THEN ROUND((total_hqla_gbp / net_outflows_gbp) * 100, 2)
        ELSE NULL
    END                                                    AS lcr_ratio_pct,
    CASE
        WHEN net_outflows_gbp > 0 AND (total_hqla_gbp / net_outflows_gbp) >= 1.0
        THEN 'COMPLIANT'
        ELSE 'BREACH'
    END                                                    AS lcr_status,
    100.00                                                 AS regulatory_minimum_pct,
    'Basel III / CRD IV — PRA maintained post-Brexit'      AS regulatory_basis
FROM lcr_calc;

-- =============================================================================
-- REPORT 2: CAPITAL ADEQUACY REPORT (CAR)
--
-- CAR = Tier 1 Capital / Risk-Weighted Assets (RWA) x 100
--
-- Regulatory minimums (Basel III / CRR2):
--   Total Capital Ratio : >= 8.0%
--   Tier 1 Capital Ratio: >= 6.0%
--   CET1 Ratio          : >= 4.5%
--   (Plus PRA buffers — capital conservation buffer 2.5%)
--
-- Simplified approach for this lab:
--   - RWA: sum of loan book risk-weighted assets (outstanding balance x risk weight %)
--   - Tier 1 Capital proxy: aggregate of BOND account balances (internal capital held)
-- =============================================================================
CREATE OR REPLACE VIEW REPORTING.V_CAPITAL_ADEQUACY
COMMENT = 'Capital Adequacy Report — Basel III Pillar 1. CET1 minimum 4.5%, Tier 1 minimum 6.0%, Total Capital minimum 8.0%'
AS
WITH

rwa_by_type AS (
    SELECT
        l.loan_type,
        l.product_name,
        l.risk_weight_pct,
        COUNT(*)                                                    AS loan_count,
        ROUND(SUM(l.outstanding_balance_gbp), 2)                   AS total_outstanding_gbp,
        ROUND(SUM(l.risk_weighted_asset_gbp), 2)                   AS risk_weighted_assets_gbp
    FROM STAGING.STG_LOANS_V l
    WHERE l.status != 'DEFAULT'
    GROUP BY l.loan_type, l.product_name, l.risk_weight_pct
),

total_rwa AS (
    SELECT SUM(risk_weighted_assets_gbp) AS total_rwa_gbp FROM rwa_by_type
),

tier1_capital AS (
    SELECT SUM(balance_gbp) AS tier1_capital_gbp
    FROM STAGING.STG_ACCOUNTS_V a
    WHERE a.account_type = 'BOND'
),

car_calc AS (
    SELECT
        t1.tier1_capital_gbp,
        rwa.total_rwa_gbp,
        ROUND((t1.tier1_capital_gbp / NULLIF(rwa.total_rwa_gbp, 0)) * 100, 4) AS tier1_ratio_pct
    FROM tier1_capital t1
    CROSS JOIN total_rwa rwa
)
SELECT
    CURRENT_DATE()                                      AS reporting_date,
    c.tier1_capital_gbp,
    c.total_rwa_gbp,
    c.tier1_ratio_pct,
    CASE
        WHEN c.tier1_ratio_pct >= 6.0 THEN 'COMPLIANT'
        ELSE 'BREACH'
    END                                                 AS tier1_status,
    6.00                                                AS tier1_minimum_pct,
    8.00                                                AS total_capital_minimum_pct,
    'Basel III Pillar 1 / CRR2 / PRA Rulebook'         AS regulatory_basis,

    -- Breakdown of RWA by loan type (using OBJECT_CONSTRUCT for a summary)
    (SELECT OBJECT_AGG(loan_type::VARCHAR, risk_weighted_assets_gbp::VARIANT)
     FROM rwa_by_type)                                  AS rwa_breakdown
FROM car_calc c;

-- Supporting detail view — useful for drill-down analysis
CREATE OR REPLACE VIEW REPORTING.V_CAPITAL_ADEQUACY_DETAIL
COMMENT = 'Capital Adequacy detail — RWA by loan type and risk weight'
AS
SELECT
    l.loan_type,
    l.product_name,
    l.risk_weight_pct,
    COUNT(*)                                                    AS loan_count,
    ROUND(SUM(l.outstanding_balance_gbp), 2)                   AS total_outstanding_gbp,
    ROUND(SUM(l.risk_weighted_asset_gbp), 2)                   AS risk_weighted_assets_gbp,
    l.status                                                    AS loan_status
FROM STAGING.STG_LOANS_V l
GROUP BY l.loan_type, l.product_name, l.risk_weight_pct, l.status
ORDER BY risk_weighted_assets_gbp DESC;

-- =============================================================================
-- REPORT 3: LARGE EXPOSURES REGISTER
--
-- PRA Rule: No single exposure to a counterparty may exceed 25% of
-- the institution's Tier 1 capital (PRA Rulebook — Large Exposures 4.1)
--
-- Exposure = outstanding loan balances + deposit account balances per customer
-- =============================================================================
CREATE OR REPLACE VIEW REPORTING.V_LARGE_EXPOSURES
COMMENT = 'Large Exposures Register — PRA rule: single counterparty exposure must not exceed 25% of Tier 1 capital'
AS
WITH

tier1_capital AS (
    SELECT SUM(a.balance_gbp) AS tier1_capital_gbp
    FROM STAGING.STG_ACCOUNTS_V a
    WHERE a.account_type = 'BOND'
),

loan_exposure AS (
    SELECT
        customer_id,
        ROUND(SUM(outstanding_balance_gbp), 2) AS loan_exposure_gbp
    FROM STAGING.STG_LOANS_V
    WHERE status != 'DEFAULT'
    GROUP BY customer_id
),

deposit_exposure AS (
    SELECT
        customer_id,
        ROUND(SUM(balance_gbp), 2) AS deposit_exposure_gbp
    FROM STAGING.STG_ACCOUNTS_V
    GROUP BY customer_id
),

total_exposure AS (
    SELECT
        c.customer_id,
        c.full_name                            AS customer_name,
        c.segment,
        c.risk_rating,
        COALESCE(l.loan_exposure_gbp, 0)       AS loan_exposure_gbp,
        COALESCE(d.deposit_exposure_gbp, 0)    AS deposit_exposure_gbp,
        COALESCE(l.loan_exposure_gbp, 0) +
            COALESCE(d.deposit_exposure_gbp, 0) AS total_exposure_gbp
    FROM STAGING.STG_CUSTOMERS_V    c
    LEFT JOIN loan_exposure    l ON c.customer_id = l.customer_id
    LEFT JOIN deposit_exposure d ON c.customer_id = d.customer_id
    WHERE COALESCE(l.loan_exposure_gbp, 0) + COALESCE(d.deposit_exposure_gbp, 0) > 0
)
SELECT
    te.customer_id,
    te.customer_name,
    te.segment,
    te.risk_rating,
    te.loan_exposure_gbp,
    te.deposit_exposure_gbp,
    te.total_exposure_gbp,
    t1.tier1_capital_gbp,
    ROUND((te.total_exposure_gbp / NULLIF(t1.tier1_capital_gbp, 0)) * 100, 4) AS exposure_as_pct_of_capital,
    CASE
        WHEN (te.total_exposure_gbp / NULLIF(t1.tier1_capital_gbp, 0)) > 0.25 THEN 'BREACH'
        WHEN (te.total_exposure_gbp / NULLIF(t1.tier1_capital_gbp, 0)) > 0.20 THEN 'WARNING'
        ELSE 'OK'
    END                                                 AS large_exposure_flag,
    te.total_exposure_gbp * 0.25                        AS pra_25pct_limit_gbp,
    CURRENT_DATE()                                      AS reporting_date,
    'PRA Rulebook — Large Exposures 4.1 (25% Tier 1 Capital)' AS regulatory_basis
FROM total_exposure te
CROSS JOIN tier1_capital t1
ORDER BY te.total_exposure_gbp DESC;

-- =============================================================================
-- VALIDATE THE REPORTING VIEWS
-- =============================================================================

-- LCR summary
SELECT
    reporting_date,
    ROUND(total_hqla_gbp / 1000000, 2)     AS hqla_millions_gbp,
    ROUND(net_outflows_30d_gbp / 1000000, 2) AS net_outflows_millions_gbp,
    lcr_ratio_pct                           AS lcr_pct,
    lcr_status,
    regulatory_minimum_pct
FROM REPORTING.V_LCR_COMPONENTS;

-- Capital adequacy summary
SELECT
    reporting_date,
    ROUND(tier1_capital_gbp / 1000000, 2)  AS tier1_capital_millions_gbp,
    ROUND(total_rwa_gbp / 1000000, 2)      AS rwa_millions_gbp,
    tier1_ratio_pct                        AS tier1_ratio_pct,
    tier1_status,
    tier1_minimum_pct
FROM REPORTING.V_CAPITAL_ADEQUACY;

-- Top 20 exposures — how many are in breach?
SELECT
    customer_id,
    customer_name,
    segment,
    risk_rating,
    ROUND(total_exposure_gbp / 1000000, 4) AS total_exposure_millions_gbp,
    ROUND(exposure_as_pct_of_capital, 4)   AS exposure_pct_of_capital,
    large_exposure_flag
FROM REPORTING.V_LARGE_EXPOSURES
LIMIT 20;

-- Count breaches and warnings
SELECT
    large_exposure_flag,
    COUNT(*) AS customer_count
FROM REPORTING.V_LARGE_EXPOSURES
GROUP BY large_exposure_flag
ORDER BY large_exposure_flag;
```
