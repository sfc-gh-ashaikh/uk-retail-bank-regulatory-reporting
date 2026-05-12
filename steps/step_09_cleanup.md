# Step 9: Clean Up
**Duration: 5 minutes**

Congratulations — you have built a complete regulatory reporting pipeline for NorthBridge Bank.

## What You Delivered

- **For the Regulator**: Three automated regulatory reports — LCR, Capital Adequacy and Large Exposures — built on Snowflake and scheduled to run daily at 06:00 UTC
- **For the Risk team**: A staging layer with PII masking (NI numbers, account numbers), data quality filters and enriched views ready for downstream consumption
- **For the CFO**: Reporting views that calculate Liquidity Coverage Ratio, Tier 1 capital ratios and single-counterparty exposure against PRA thresholds — refreshed automatically
- **For the Data Engineering team**: A three-layer pipeline (RAW → STAGING → REPORTING) with stored procedures, exception handling, audit logging and a Task DAG that orchestrates the full refresh
- **For yourself**: A production-ready Snowflake workflow covering ingest, transformation, orchestration and AI-assisted development

## What You Learned

- **Snowsight UI**: Navigating the interface, using worksheets and folders as a development workspace
- **Databases, Schemas and Roles**: Three-schema architecture (RAW, STAGING, REPORTING), RBAC context switching with USE ROLE
- **File-Based Ingest**: Internal stages, file formats, COPY INTO for CSV loading
- **Tables and Views**: Explicit DDL for staging tables, cleansing views that transform at query time
- **PII Masking**: NI number and account number masking in staging views
- **Zero-Copy Cloning**: Instant sandbox creation with no additional storage cost
- **Warehouse Scaling**: Instant resize with ALTER WAREHOUSE, benchmarking X-SMALL vs MEDIUM
- **Reporting Views**: Building regulatory calculations (LCR, CAR, Large Exposures) from staging views
- **Stored Procedures**: Snowflake Scripting with EXECUTE IMMEDIATE, SQLROWCOUNT, SQLERRM, exception handling and audit logging
- **Task Orchestration**: Task DAGs with CRON scheduling, predecessor chains and leaf-to-root resume ordering
- **Cortex Code**: Generate, explain, refactor and extend SQL using AI assistance

## Teardown

To remove all lab objects from your Snowflake account:

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

## Related Resources

- [Snowflake SQL Reference](https://docs.snowflake.com/en/sql-reference)
- [Snowflake Scripting](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/index)
- [Tasks and Task DAGs](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Understanding Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui)
- [Cloning Considerations](https://docs.snowflake.com/en/user-guide/object-clone)
- [Understanding Warehouse Sizing](https://docs.snowflake.com/en/user-guide/warehouses-overview)
- [Cortex Code Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code)
- [PRA LCR Rulebook](https://www.bankofengland.co.uk/prudential-regulation/rulebook/made-rules/liquidity)
- [Basel III LCR (BIS)](https://www.bis.org/publ/bcbs238.htm)
