-- =============================================================================
-- NorthBridge Bank HOL: Step 5 - Core Data Engineering: Tables, Views & Staging
--
-- This script builds the STAGING layer:
--   - Staging tables with explicit DDL
--   - Cleansing views over raw tables
--   - Zero-Copy Clone demonstration
--
-- The staging layer sits between RAW and REPORTING and is responsible for:
--   * Data type enforcement
--   * PII masking (NI numbers)
--   * Standardisation (postcodes, sort codes)
--   * Filtering invalid/rejected records
--   * Enrichment (joining products to accounts)
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PART A: STAGING TABLES
-- Physical tables in the STAGING schema that act as cleansed snapshots
-- Populated by stored procedures (Step 7)
-- =============================================================================

-- A1: Staging customers table
CREATE OR REPLACE TABLE STAGING.STG_CUSTOMERS (
    customer_id         NUMBER          NOT NULL,
    first_name          VARCHAR(50)     NOT NULL,
    last_name           VARCHAR(50)     NOT NULL,
    full_name           VARCHAR(101),
    date_of_birth       DATE            NOT NULL,
    age_years           NUMBER(3),
    email               VARCHAR(150),
    phone               VARCHAR(20),
    address_line1       VARCHAR(100),
    city                VARCHAR(50),
    postcode_raw        VARCHAR(10),
    postcode_formatted  VARCHAR(10),
    ni_number_masked    VARCHAR(13)     NOT NULL,
    kyc_status          VARCHAR(20)     NOT NULL,
    kyc_verified_date   DATE,
    risk_rating         VARCHAR(10)     NOT NULL,
    customer_since      DATE            NOT NULL,
    customer_tenure_days NUMBER,
    is_active           BOOLEAN,
    segment             VARCHAR(30)     NOT NULL,
    stg_loaded_at       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- A2: Staging accounts table
CREATE OR REPLACE TABLE STAGING.STG_ACCOUNTS (
    account_id              NUMBER          NOT NULL,
    customer_id             NUMBER          NOT NULL,
    product_id              NUMBER          NOT NULL,
    product_code            VARCHAR(20),
    product_name            VARCHAR(100),
    account_type            VARCHAR(30)     NOT NULL,
    sort_code               VARCHAR(8)      NOT NULL,
    account_number          VARCHAR(8)      NOT NULL,
    masked_account_number   VARCHAR(8),
    balance_gbp             NUMBER(15,2)    NOT NULL,
    opened_date             DATE            NOT NULL,
    closed_date             DATE,
    status                  VARCHAR(20)     NOT NULL,
    lcr_liability_category  VARCHAR(50)     NOT NULL,
    lcr_category            VARCHAR(20),
    overdraft_limit_gbp     NUMBER(10,2),
    interest_rate_pct       NUMBER(6,4),
    stg_loaded_at           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- A3: Staging transactions table
CREATE OR REPLACE TABLE STAGING.STG_TRANSACTIONS (
    transaction_id      VARCHAR(20)     NOT NULL,
    account_id          NUMBER          NOT NULL,
    transaction_date    DATE            NOT NULL,
    transaction_time    TIME            NOT NULL,
    transaction_type    VARCHAR(20)     NOT NULL,
    debit_credit        VARCHAR(1)      NOT NULL,
    amount_gbp          NUMBER(12,2)    NOT NULL,
    description         VARCHAR(200),
    merchant_name       VARCHAR(100),
    merchant_category   VARCHAR(50),
    reference           VARCHAR(50),
    channel             VARCHAR(20)     NOT NULL,
    status              VARCHAR(20)     NOT NULL,
    stg_loaded_at       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- A4: Staging loans table
CREATE OR REPLACE TABLE STAGING.STG_LOANS (
    loan_id                 NUMBER          NOT NULL,
    customer_id             NUMBER          NOT NULL,
    product_id              NUMBER          NOT NULL,
    product_name            VARCHAR(100),
    loan_type               VARCHAR(30)     NOT NULL,
    original_amount_gbp     NUMBER(15,2)    NOT NULL,
    outstanding_balance_gbp NUMBER(15,2)    NOT NULL,
    interest_rate_pct       NUMBER(6,4)     NOT NULL,
    term_months             NUMBER(3)       NOT NULL,
    start_date              DATE            NOT NULL,
    maturity_date           DATE            NOT NULL,
    months_remaining        NUMBER,
    monthly_payment_gbp     NUMBER(10,2)    NOT NULL,
    risk_weight_pct         NUMBER(5,2)     NOT NULL,
    risk_weighted_asset_gbp NUMBER(15,2),
    collateral_type         VARCHAR(50),
    collateral_value_gbp    NUMBER(15,2),
    ltv_ratio_pct           NUMBER(6,2),
    status                  VARCHAR(20)     NOT NULL,
    arrears_days            NUMBER(3),
    stg_loaded_at           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- PART B: CLEANSING VIEWS
-- Views apply transformations at query time — always read the latest raw data
-- =============================================================================

-- B1: STG_CUSTOMERS_V — customer data with PII masking and derived fields
CREATE OR REPLACE VIEW STAGING.STG_CUSTOMERS_V
COMMENT = 'Cleansed customer view: NI numbers masked, postcodes standardised, tenure derived'
AS
SELECT
    customer_id,
    first_name,
    last_name,
    TRIM(first_name) || ' ' || TRIM(last_name)                  AS full_name,
    date_of_birth,
    DATEDIFF('year', date_of_birth, CURRENT_DATE())             AS age_years,
    LOWER(TRIM(email))                                          AS email,
    REGEXP_REPLACE(phone, '[^0-9+]', '')                        AS phone,
    address_line1,
    city,
    postcode                                                    AS postcode_raw,
    UPPER(TRIM(postcode))                                       AS postcode_formatted,

    -- NI number masking: show first 2 chars and last char only (e.g. AB ** ** ** D)
    SUBSTRING(ni_number, 1, 2) || ' ** ** ** ' ||
        SUBSTRING(ni_number, LENGTH(ni_number), 1)              AS ni_number_masked,

    kyc_status,
    kyc_verified_date,
    risk_rating,
    customer_since,
    DATEDIFF('day', customer_since, CURRENT_DATE())             AS customer_tenure_days,
    is_active,
    segment,
    CURRENT_TIMESTAMP()                                         AS stg_loaded_at
FROM RAW.CUSTOMERS
WHERE is_active = TRUE;

-- B2: STG_ACCOUNTS_V — enriched account view with product details
CREATE OR REPLACE VIEW STAGING.STG_ACCOUNTS_V
COMMENT = 'Enriched account view: product details joined, account number masked, active accounts only'
AS
SELECT
    a.account_id,
    a.customer_id,
    a.product_id,
    p.product_code,
    p.product_name,
    a.account_type,
    a.sort_code,
    a.account_number,
    -- Mask last 4 digits of account number for display
    SUBSTRING(a.account_number, 1, 4) || 'XXXX'                AS masked_account_number,
    a.balance_gbp,
    a.opened_date,
    a.closed_date,
    a.status,
    a.lcr_liability_category,
    p.lcr_category,
    a.overdraft_limit_gbp,
    a.interest_rate_pct,
    CURRENT_TIMESTAMP()                                         AS stg_loaded_at
FROM RAW.ACCOUNTS  a
JOIN RAW.PRODUCTS  p ON a.product_id = p.product_id
WHERE a.status IN ('ACTIVE', 'DORMANT');

-- B3: STG_TRANSACTIONS_V — filtered to cleared transactions only
CREATE OR REPLACE VIEW STAGING.STG_TRANSACTIONS_V
COMMENT = 'Transaction view: only CLEARED transactions, amounts cast and validated'
AS
SELECT
    transaction_id,
    account_id,
    transaction_date,
    transaction_time,
    transaction_type,
    debit_credit,
    ROUND(amount_gbp::NUMBER(12,2), 2)                          AS amount_gbp,
    TRIM(description)                                           AS description,
    TRIM(merchant_name)                                         AS merchant_name,
    merchant_category,
    reference,
    channel,
    status,
    CURRENT_TIMESTAMP()                                         AS stg_loaded_at
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND amount_gbp > 0
  AND amount_gbp < 10000000;

-- B4: STG_LOANS_V — loan view with derived risk and LTV metrics
CREATE OR REPLACE VIEW STAGING.STG_LOANS_V
COMMENT = 'Loan view with risk-weighted asset calculation, LTV ratio and months remaining'
AS
SELECT
    l.loan_id,
    l.customer_id,
    l.product_id,
    p.product_name,
    l.loan_type,
    l.original_amount_gbp,
    l.outstanding_balance_gbp,
    l.interest_rate_pct,
    l.term_months,
    l.start_date,
    l.maturity_date,
    GREATEST(0, DATEDIFF('month', CURRENT_DATE(), l.maturity_date)) AS months_remaining,
    l.monthly_payment_gbp,
    l.risk_weight_pct,
    -- Risk-Weighted Asset = Outstanding Balance x Risk Weight
    ROUND(l.outstanding_balance_gbp * (l.risk_weight_pct / 100), 2) AS risk_weighted_asset_gbp,
    l.collateral_type,
    l.collateral_value_gbp,
    -- Loan-to-Value ratio (only applicable where collateral exists)
    CASE
        WHEN l.collateral_value_gbp > 0
        THEN ROUND((l.outstanding_balance_gbp / l.collateral_value_gbp) * 100, 2)
        ELSE NULL
    END                                                         AS ltv_ratio_pct,
    l.status,
    l.arrears_days,
    CURRENT_TIMESTAMP()                                         AS stg_loaded_at
FROM RAW.LOANS   l
JOIN RAW.PRODUCTS p ON l.product_id = p.product_id;

-- =============================================================================
-- PART C: VALIDATE THE VIEWS
-- =============================================================================

-- Check customer masking is working correctly
SELECT
    customer_id,
    full_name,
    postcode_formatted,
    ni_number_masked,
    kyc_status,
    risk_rating,
    segment
FROM STAGING.STG_CUSTOMERS_V
LIMIT 10;

-- Check account enrichment
SELECT
    account_id,
    customer_id,
    product_name,
    account_type,
    sort_code,
    masked_account_number,
    balance_gbp,
    lcr_liability_category
FROM STAGING.STG_ACCOUNTS_V
LIMIT 10;

-- Transaction count — should be ~92% of raw (CLEARED only)
SELECT
    status,
    COUNT(*)        AS txn_count,
    SUM(amount_gbp) AS total_amount_gbp
FROM RAW.TRANSACTIONS
GROUP BY status
ORDER BY status;

-- Loan risk metrics
SELECT
    loan_type,
    COUNT(*)                                    AS loan_count,
    ROUND(SUM(outstanding_balance_gbp), 0)     AS total_outstanding_gbp,
    ROUND(SUM(risk_weighted_asset_gbp), 0)     AS total_rwa_gbp,
    ROUND(AVG(ltv_ratio_pct), 2)               AS avg_ltv_pct
FROM STAGING.STG_LOANS_V
GROUP BY loan_type
ORDER BY total_outstanding_gbp DESC;

-- =============================================================================
-- PART D: ZERO-COPY CLONE
-- Create a development copy of the transactions table instantly, with no
-- additional storage cost (until data diverges). Ideal for testing pipeline
-- changes without touching production data.
-- =============================================================================
CREATE TABLE IF NOT EXISTS RAW.TRANSACTIONS_DEV
    CLONE RAW.TRANSACTIONS;

-- Verify the clone has the same row count
SELECT
    'RAW.TRANSACTIONS'     AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'RAW.TRANSACTIONS_DEV' AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_DEV;

-- Key point: modifying TRANSACTIONS_DEV does NOT affect TRANSACTIONS
-- DELETE FROM RAW.TRANSACTIONS_DEV WHERE status = 'REJECTED';  -- safe to run on dev clone
