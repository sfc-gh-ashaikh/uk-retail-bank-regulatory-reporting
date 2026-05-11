# Step 9: Clean Up

Remove all lab objects from your Snowflake account. Run the following in a Snowsight worksheet:

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Teardown
-- Removes all lab objects from your Snowflake account
-- =============================================================================

USE ROLE SYSADMIN;

-- Suspend tasks before dropping (required — active tasks block database drop)
ALTER TASK IF EXISTS NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE   SUSPEND;
ALTER TASK IF EXISTS NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_STAGING   SUSPEND;
ALTER TASK IF EXISTS NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_REPORTING SUSPEND;

-- Drop all lab objects
DROP DATABASE  IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```
