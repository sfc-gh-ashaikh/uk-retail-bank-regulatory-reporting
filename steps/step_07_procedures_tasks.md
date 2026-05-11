# Step 7: Stored Procedures and Task Orchestration

**Estimated time: 30 minutes**

This step automates the regulatory reporting pipeline using stored procedures and Snowflake Tasks. You will:

- **Part A:** Create two stored procedures that refresh the staging and reporting layers
- **Part B:** Build a Task DAG (Directed Acyclic Graph) to orchestrate daily execution

## Part A: Stored Procedures

Stored procedures encapsulate multi-step logic with error handling and audit logging. Snowflake Scripting uses SQL-native syntax: `DECLARE ... BEGIN ... EXCEPTION ... END`.

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Step 7 - Stored Procedures
--
-- Two stored procedures written in Snowflake Scripting (SQL-based):
--
--   SP_REFRESH_STAGING()    — Reloads all staging tables from RAW layer
--                             Logs row counts to STAGING.AUDIT_LOG
--                             Handles exceptions gracefully
--
--   SP_REFRESH_REPORTING()  — Refreshes materialised reporting snapshots
--                             Used by the daily task DAG
--
-- Snowflake Scripting uses SQL-native syntax:
--   DECLARE ... BEGIN ... EXCEPTION ... END
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PROCEDURE 1: SP_REFRESH_STAGING
--
-- Truncates and reloads each staging table from the corresponding
-- STAGING view (which reads from RAW). Logs each step to AUDIT_LOG.
-- =============================================================================
CREATE OR REPLACE PROCEDURE STAGING.SP_REFRESH_STAGING()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Refreshes all staging tables from RAW layer. Logs row counts to AUDIT_LOG.'
EXECUTE AS CALLER
AS
$$
DECLARE
    v_proc_name     VARCHAR DEFAULT 'SP_REFRESH_STAGING';
    v_rows_affected NUMBER  DEFAULT 0;
    v_total_rows    NUMBER  DEFAULT 0;
    v_start_time    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_error_msg     VARCHAR;
BEGIN

    -- -----------------------------------------------------------------------
    -- Log procedure start
    -- -----------------------------------------------------------------------
    INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
    VALUES (:v_proc_name, 'PROCEDURE_START', 0, 'SUCCESS');

    -- -----------------------------------------------------------------------
    -- Step 1: Refresh STG_CUSTOMERS
    -- -----------------------------------------------------------------------
    BEGIN
        TRUNCATE TABLE STAGING.STG_CUSTOMERS;

        INSERT INTO STAGING.STG_CUSTOMERS
        SELECT
            customer_id, first_name, last_name, full_name, date_of_birth,
            age_years, email, phone, address_line1, city, postcode_raw,
            postcode_formatted, ni_number_masked, kyc_status, kyc_verified_date,
            risk_rating, customer_since, customer_tenure_days, is_active,
            segment, stg_loaded_at
        FROM STAGING.STG_CUSTOMERS_V;

        v_rows_affected := SQLROWCOUNT;
        v_total_rows    := v_total_rows + v_rows_affected;

        INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
        VALUES (:v_proc_name, 'REFRESH_STG_CUSTOMERS', :v_rows_affected, 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            v_error_msg := 'STG_CUSTOMERS failed: ' || SQLERRM;
            INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status, error_message)
            VALUES (:v_proc_name, 'REFRESH_STG_CUSTOMERS', 0, 'FAILED', :v_error_msg);
            RETURN 'FAILED at STG_CUSTOMERS: ' || v_error_msg;
    END;

    -- -----------------------------------------------------------------------
    -- Step 2: Refresh STG_ACCOUNTS
    -- -----------------------------------------------------------------------
    BEGIN
        TRUNCATE TABLE STAGING.STG_ACCOUNTS;

        INSERT INTO STAGING.STG_ACCOUNTS
        SELECT
            account_id, customer_id, product_id, product_code, product_name,
            account_type, sort_code, account_number, masked_account_number,
            balance_gbp, opened_date, closed_date, status,
            lcr_liability_category, lcr_category, overdraft_limit_gbp,
            interest_rate_pct, stg_loaded_at
        FROM STAGING.STG_ACCOUNTS_V;

        v_rows_affected := SQLROWCOUNT;
        v_total_rows    := v_total_rows + v_rows_affected;

        INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
        VALUES (:v_proc_name, 'REFRESH_STG_ACCOUNTS', :v_rows_affected, 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            v_error_msg := 'STG_ACCOUNTS failed: ' || SQLERRM;
            INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status, error_message)
            VALUES (:v_proc_name, 'REFRESH_STG_ACCOUNTS', 0, 'FAILED', :v_error_msg);
            RETURN 'FAILED at STG_ACCOUNTS: ' || v_error_msg;
    END;

    -- -----------------------------------------------------------------------
    -- Step 3: Refresh STG_TRANSACTIONS
    -- -----------------------------------------------------------------------
    BEGIN
        TRUNCATE TABLE STAGING.STG_TRANSACTIONS;

        INSERT INTO STAGING.STG_TRANSACTIONS
        SELECT
            transaction_id, account_id, transaction_date, transaction_time,
            transaction_type, debit_credit, amount_gbp, description,
            merchant_name, merchant_category, reference, channel, status,
            stg_loaded_at
        FROM STAGING.STG_TRANSACTIONS_V;

        v_rows_affected := SQLROWCOUNT;
        v_total_rows    := v_total_rows + v_rows_affected;

        INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
        VALUES (:v_proc_name, 'REFRESH_STG_TRANSACTIONS', :v_rows_affected, 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            v_error_msg := 'STG_TRANSACTIONS failed: ' || SQLERRM;
            INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status, error_message)
            VALUES (:v_proc_name, 'REFRESH_STG_TRANSACTIONS', 0, 'FAILED', :v_error_msg);
            RETURN 'FAILED at STG_TRANSACTIONS: ' || v_error_msg;
    END;

    -- -----------------------------------------------------------------------
    -- Step 4: Refresh STG_LOANS
    -- -----------------------------------------------------------------------
    BEGIN
        TRUNCATE TABLE STAGING.STG_LOANS;

        INSERT INTO STAGING.STG_LOANS
        SELECT
            loan_id, customer_id, product_id, product_name, loan_type,
            original_amount_gbp, outstanding_balance_gbp, interest_rate_pct,
            term_months, start_date, maturity_date, months_remaining,
            monthly_payment_gbp, risk_weight_pct, risk_weighted_asset_gbp,
            collateral_type, collateral_value_gbp, ltv_ratio_pct,
            status, arrears_days, stg_loaded_at
        FROM STAGING.STG_LOANS_V;

        v_rows_affected := SQLROWCOUNT;
        v_total_rows    := v_total_rows + v_rows_affected;

        INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
        VALUES (:v_proc_name, 'REFRESH_STG_LOANS', :v_rows_affected, 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            v_error_msg := 'STG_LOANS failed: ' || SQLERRM;
            INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status, error_message)
            VALUES (:v_proc_name, 'REFRESH_STG_LOANS', 0, 'FAILED', :v_error_msg);
            RETURN 'FAILED at STG_LOANS: ' || v_error_msg;
    END;

    -- -----------------------------------------------------------------------
    -- Log completion
    -- -----------------------------------------------------------------------
    LET v_duration VARCHAR := 'PROCEDURE_COMPLETE — duration: ' ||
        DATEDIFF('second', :v_start_time, CURRENT_TIMESTAMP())::VARCHAR || 's';

    INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
    VALUES (
        :v_proc_name,
        :v_duration,
        :v_total_rows,
        'SUCCESS'
    );

    RETURN 'SUCCESS — ' || v_total_rows::VARCHAR || ' rows refreshed across all staging tables.';

END;
$$;

-- =============================================================================
-- PROCEDURE 2: SP_REFRESH_REPORTING
--
-- Creates point-in-time materialised snapshots of the three regulatory
-- reporting views. Snapshots are date-partitioned for historical analysis.
-- Logs execution to AUDIT_LOG.
-- =============================================================================
CREATE OR REPLACE PROCEDURE STAGING.SP_REFRESH_REPORTING()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Refreshes regulatory reporting snapshots (LCR, CAR, Large Exposures). Logs to AUDIT_LOG.'
EXECUTE AS CALLER
AS
$$
DECLARE
    v_proc_name     VARCHAR DEFAULT 'SP_REFRESH_REPORTING';
    v_rows_affected NUMBER  DEFAULT 0;
    v_total_rows    NUMBER  DEFAULT 0;
    v_start_time    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_report_date   DATE    DEFAULT CURRENT_DATE();
    v_error_msg     VARCHAR;
BEGIN

    INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
    VALUES (:v_proc_name, 'PROCEDURE_START', 0, 'SUCCESS');

    -- -----------------------------------------------------------------------
    -- Create snapshot tables if they don't exist
    -- -----------------------------------------------------------------------
    CREATE TABLE IF NOT EXISTS REPORTING.SNAP_LCR_COMPONENTS (
        snapshot_date           DATE,
        reporting_date          DATE,
        hqla_level1_gbp         NUMBER(20,2),
        hqla_level2a_gbp        NUMBER(20,2),
        total_hqla_gbp          NUMBER(20,2),
        gross_outflows_30d_gbp  NUMBER(20,2),
        gross_inflows_30d_gbp   NUMBER(20,2),
        net_outflows_30d_gbp    NUMBER(20,2),
        lcr_ratio_pct           NUMBER(12,4),
        lcr_status              VARCHAR(20),
        regulatory_minimum_pct  NUMBER(5,2),
        regulatory_basis        VARCHAR(100),
        loaded_at               TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    CREATE TABLE IF NOT EXISTS REPORTING.SNAP_CAPITAL_ADEQUACY (
        snapshot_date           DATE,
        reporting_date          DATE,
        tier1_capital_gbp       NUMBER(20,2),
        total_rwa_gbp           NUMBER(20,2),
        tier1_ratio_pct         NUMBER(8,4),
        tier1_status            VARCHAR(20),
        tier1_minimum_pct       NUMBER(5,2),
        total_capital_min_pct   NUMBER(5,2),
        regulatory_basis        VARCHAR(100),
        loaded_at               TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    CREATE TABLE IF NOT EXISTS REPORTING.SNAP_LARGE_EXPOSURES (
        snapshot_date               DATE,
        customer_id                 NUMBER,
        customer_name               VARCHAR(101),
        segment                     VARCHAR(30),
        risk_rating                 VARCHAR(10),
        loan_exposure_gbp           NUMBER(20,2),
        deposit_exposure_gbp        NUMBER(20,2),
        total_exposure_gbp          NUMBER(20,2),
        tier1_capital_gbp           NUMBER(20,2),
        exposure_as_pct_of_capital  NUMBER(8,4),
        large_exposure_flag         VARCHAR(10),
        pra_25pct_limit_gbp         NUMBER(20,2),
        reporting_date              DATE,
        loaded_at                   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    -- -----------------------------------------------------------------------
    -- Step 1: Snapshot LCR components
    -- -----------------------------------------------------------------------
    BEGIN
        DELETE FROM REPORTING.SNAP_LCR_COMPONENTS WHERE snapshot_date = :v_report_date;

        INSERT INTO REPORTING.SNAP_LCR_COMPONENTS (
            snapshot_date, reporting_date, hqla_level1_gbp, hqla_level2a_gbp,
            total_hqla_gbp, gross_outflows_30d_gbp, gross_inflows_30d_gbp,
            net_outflows_30d_gbp, lcr_ratio_pct, lcr_status,
            regulatory_minimum_pct, regulatory_basis
        )
        SELECT
            :v_report_date, reporting_date, hqla_level1_gbp, hqla_level2a_gbp,
            total_hqla_gbp, gross_outflows_30d_gbp, gross_inflows_30d_gbp,
            net_outflows_30d_gbp, lcr_ratio_pct, lcr_status,
            regulatory_minimum_pct, regulatory_basis
        FROM REPORTING.V_LCR_COMPONENTS;

        v_rows_affected := SQLROWCOUNT;
        v_total_rows    := v_total_rows + v_rows_affected;

        INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
        VALUES (:v_proc_name, 'SNAP_LCR_COMPONENTS', :v_rows_affected, 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            v_error_msg := 'SNAP_LCR_COMPONENTS failed: ' || SQLERRM;
            INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status, error_message)
            VALUES (:v_proc_name, 'SNAP_LCR_COMPONENTS', 0, 'FAILED', :v_error_msg);
            RETURN 'FAILED at SNAP_LCR_COMPONENTS: ' || v_error_msg;
    END;

    -- -----------------------------------------------------------------------
    -- Step 2: Snapshot capital adequacy
    -- -----------------------------------------------------------------------
    BEGIN
        DELETE FROM REPORTING.SNAP_CAPITAL_ADEQUACY WHERE snapshot_date = :v_report_date;

        INSERT INTO REPORTING.SNAP_CAPITAL_ADEQUACY (
            snapshot_date, reporting_date, tier1_capital_gbp, total_rwa_gbp,
            tier1_ratio_pct, tier1_status, tier1_minimum_pct,
            total_capital_min_pct, regulatory_basis
        )
        SELECT
            :v_report_date, reporting_date, tier1_capital_gbp, total_rwa_gbp,
            tier1_ratio_pct, tier1_status, tier1_minimum_pct,
            total_capital_minimum_pct, regulatory_basis
        FROM REPORTING.V_CAPITAL_ADEQUACY;

        v_rows_affected := SQLROWCOUNT;
        v_total_rows    := v_total_rows + v_rows_affected;

        INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
        VALUES (:v_proc_name, 'SNAP_CAPITAL_ADEQUACY', :v_rows_affected, 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            v_error_msg := 'SNAP_CAPITAL_ADEQUACY failed: ' || SQLERRM;
            INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status, error_message)
            VALUES (:v_proc_name, 'SNAP_CAPITAL_ADEQUACY', 0, 'FAILED', :v_error_msg);
            RETURN 'FAILED at SNAP_CAPITAL_ADEQUACY: ' || v_error_msg;
    END;

    -- -----------------------------------------------------------------------
    -- Step 3: Snapshot large exposures
    -- -----------------------------------------------------------------------
    BEGIN
        DELETE FROM REPORTING.SNAP_LARGE_EXPOSURES WHERE snapshot_date = :v_report_date;

        INSERT INTO REPORTING.SNAP_LARGE_EXPOSURES (
            snapshot_date, customer_id, customer_name, segment, risk_rating,
            loan_exposure_gbp, deposit_exposure_gbp, total_exposure_gbp,
            tier1_capital_gbp, exposure_as_pct_of_capital, large_exposure_flag,
            pra_25pct_limit_gbp, reporting_date
        )
        SELECT
            :v_report_date, customer_id, customer_name, segment, risk_rating,
            loan_exposure_gbp, deposit_exposure_gbp, total_exposure_gbp,
            tier1_capital_gbp, exposure_as_pct_of_capital, large_exposure_flag,
            pra_25pct_limit_gbp, reporting_date
        FROM REPORTING.V_LARGE_EXPOSURES;

        v_rows_affected := SQLROWCOUNT;
        v_total_rows    := v_total_rows + v_rows_affected;

        INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
        VALUES (:v_proc_name, 'SNAP_LARGE_EXPOSURES', :v_rows_affected, 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            v_error_msg := 'SNAP_LARGE_EXPOSURES failed: ' || SQLERRM;
            INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status, error_message)
            VALUES (:v_proc_name, 'SNAP_LARGE_EXPOSURES', 0, 'FAILED', :v_error_msg);
            RETURN 'FAILED at SNAP_LARGE_EXPOSURES: ' || v_error_msg;
    END;

    -- -----------------------------------------------------------------------
    -- Log completion
    -- -----------------------------------------------------------------------
    LET v_duration VARCHAR := 'PROCEDURE_COMPLETE — duration: ' ||
        DATEDIFF('second', :v_start_time, CURRENT_TIMESTAMP())::VARCHAR || 's';

    INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
    VALUES (
        :v_proc_name,
        :v_duration,
        :v_total_rows,
        'SUCCESS'
    );

    RETURN 'SUCCESS — ' || v_total_rows::VARCHAR || ' snapshot rows written for ' || v_report_date::VARCHAR;

END;
$$;

-- =============================================================================
-- TEST THE PROCEDURES
-- =============================================================================

-- Test SP_REFRESH_STAGING
CALL STAGING.SP_REFRESH_STAGING();

-- Test SP_REFRESH_REPORTING
CALL STAGING.SP_REFRESH_REPORTING();

-- Check the audit log to confirm everything ran successfully
SELECT
    audit_id,
    procedure_name,
    step_name,
    rows_processed,
    status,
    error_message,
    executed_at
FROM STAGING.AUDIT_LOG
ORDER BY executed_at DESC
LIMIT 20;

-- Verify snapshot tables were created and populated
SELECT 'SNAP_LCR_COMPONENTS'  AS snapshot, COUNT(*) AS "rows" FROM REPORTING.SNAP_LCR_COMPONENTS  UNION ALL
SELECT 'SNAP_CAPITAL_ADEQUACY' AS snapshot, COUNT(*) AS "rows" FROM REPORTING.SNAP_CAPITAL_ADEQUACY UNION ALL
SELECT 'SNAP_LARGE_EXPOSURES'  AS snapshot, COUNT(*) AS "rows" FROM REPORTING.SNAP_LARGE_EXPOSURES;
```

## Part B: Task Orchestration

Tasks automate execution on a schedule or in response to predecessor task completion. The DAG below runs daily at 06:00 UTC:

```
TASK_INGEST_COMPLETE (root — scheduled daily at 06:00 UTC)
    └── TASK_REFRESH_STAGING (calls SP_REFRESH_STAGING)
             └── TASK_REFRESH_REPORTING (calls SP_REFRESH_REPORTING)
```

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Step 7 - Task Orchestration
--
-- This script creates a Task DAG (Directed Acyclic Graph) to automate the
-- daily regulatory reporting pipeline:
--
--   TASK_INGEST_COMPLETE           (root — scheduled daily at 06:00 UTC)
--        └── TASK_REFRESH_STAGING  (calls SP_REFRESH_STAGING)
--                 └── TASK_REFRESH_REPORTING (calls SP_REFRESH_REPORTING)
--
-- Tasks in Snowflake:
--   - Are defined with SQL or a stored procedure call
--   - Can be scheduled (CRON or interval) or triggered by a predecessor task
--   - Must be RESUMED to become active (default state is SUSPENDED)
--   - Can be monitored in Snowsight > Monitoring > Task History
--
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- STEP 1: Create the root task (TASK_INGEST_COMPLETE)
--
-- This task represents the completion of the upstream data ingest process.
-- In production, this would be triggered by your ingest pipeline tool.
-- For this lab, it is scheduled at 06:00 UTC daily — simulating a bank's
-- pre-market regulatory cut-off.
--
-- The root task runs a simple health-check query and logs to AUDIT_LOG.
-- =============================================================================
CREATE OR REPLACE TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE
    WAREHOUSE       = NORTHBRIDGE_WH
    SCHEDULE        = 'USING CRON 0 6 * * * UTC'
    COMMENT         = 'Root task: signals that daily data ingest is complete. Triggers the regulatory reporting pipeline.'
AS
INSERT INTO STAGING.AUDIT_LOG (procedure_name, step_name, rows_processed, status)
VALUES ('TASK_INGEST_COMPLETE', 'INGEST_SIGNAL_RECEIVED', 0, 'SUCCESS');

-- =============================================================================
-- STEP 2: Create the staging refresh task (TASK_REFRESH_STAGING)
--
-- This task runs AFTER TASK_INGEST_COMPLETE completes successfully.
-- It calls SP_REFRESH_STAGING to reload all staging tables from RAW.
-- =============================================================================
CREATE OR REPLACE TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_STAGING
    WAREHOUSE       = NORTHBRIDGE_WH
    COMMENT         = 'Refreshes all staging tables from RAW layer. Depends on: TASK_INGEST_COMPLETE'
    AFTER           NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE
AS
CALL STAGING.SP_REFRESH_STAGING();

-- =============================================================================
-- STEP 3: Create the reporting refresh task (TASK_REFRESH_REPORTING)
--
-- This task runs AFTER TASK_REFRESH_STAGING completes successfully.
-- It calls SP_REFRESH_REPORTING to materialise the three regulatory reports.
-- =============================================================================
CREATE OR REPLACE TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_REPORTING
    WAREHOUSE       = NORTHBRIDGE_WH
    COMMENT         = 'Materialises LCR, CAR and Large Exposures snapshots. Depends on: TASK_REFRESH_STAGING'
    AFTER           NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_STAGING
AS
CALL STAGING.SP_REFRESH_REPORTING();

-- =============================================================================
-- STEP 4: Show the task DAG before resuming
--
-- Tasks are created in SUSPENDED state by default.
-- Use SHOW TASKS to inspect the full DAG before enabling it.
-- =============================================================================
SHOW TASKS IN SCHEMA NORTHBRIDGE_BANK_HOL.STAGING;

-- =============================================================================
-- STEP 5: Resume tasks (order matters — leaf tasks first, then root)
--
-- Tasks must be resumed from the leaf (furthest downstream) back to the root.
-- If you resume the root first, it may trigger before its children are active.
-- =============================================================================
ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_REPORTING RESUME;
ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_STAGING    RESUME;
ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE    RESUME;

-- Confirm all tasks are now scheduled / running
SHOW TASKS IN SCHEMA NORTHBRIDGE_BANK_HOL.STAGING;

-- =============================================================================
-- STEP 6: Manually execute the pipeline for the lab
--
-- Rather than waiting for 06:00 UTC, manually trigger the root task.
-- Snowflake will execute the full DAG in dependency order.
-- =============================================================================
EXECUTE TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE;

-- =============================================================================
-- STEP 7: Monitor task execution in Snowsight
--
-- Navigate to: Monitoring > Task History in the Snowsight left navigation
-- You will see:
--   - Each task run with status (Succeeded / Failed / Running)
--   - Execution duration
--   - The DAG run graph showing dependency chain
--   - Error messages for any failed runs
--
-- You can also query task history programmatically:
-- =============================================================================
SELECT
    name           AS task_name,
    state          AS run_state,
    query_start_time,
    completed_time,
    DATEDIFF('second', query_start_time, completed_time) AS duration_seconds,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT               => 50
))
ORDER BY query_start_time DESC;

-- =============================================================================
-- STEP 8: Verify the full pipeline ran successfully
-- =============================================================================

-- Check audit log for all steps
SELECT
    procedure_name,
    step_name,
    rows_processed,
    status,
    error_message,
    executed_at
FROM STAGING.AUDIT_LOG
ORDER BY executed_at DESC
LIMIT 30;

-- Confirm the latest snapshot dates
SELECT 'LCR'             AS report, MAX(snapshot_date) AS latest_snapshot FROM REPORTING.SNAP_LCR_COMPONENTS  UNION ALL
SELECT 'CAPITAL_ADEQUACY',           MAX(snapshot_date)                    FROM REPORTING.SNAP_CAPITAL_ADEQUACY UNION ALL
SELECT 'LARGE_EXPOSURES',            MAX(snapshot_date)                    FROM REPORTING.SNAP_LARGE_EXPOSURES;

-- =============================================================================
-- CLEANUP (suspend tasks when lab is complete — avoids unnecessary compute)
-- =============================================================================

-- ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE    SUSPEND;
-- ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_STAGING    SUSPEND;
-- ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_REPORTING  SUSPEND;
```
