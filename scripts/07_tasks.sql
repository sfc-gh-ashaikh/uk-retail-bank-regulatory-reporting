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
