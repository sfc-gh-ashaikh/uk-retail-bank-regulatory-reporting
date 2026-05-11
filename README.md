# NorthBridge Bank: Building a Regulatory Reporting Pipeline on Snowflake

A hands-on lab (~3 hours) for data engineers at UK retail banks. You play a data engineer at NorthBridge Bank — a mid-size UK retail bank regulated by the FCA and PRA — replacing a legacy reporting system with a modern pipeline on Snowflake that automates three critical regulatory reports: **LCR** (Basel III liquidity), **CAR** (Basel III capital adequacy) and **Large Exposures** (PRA 25% Tier 1 limit).

**Prerequisites**: Snowflake account with `SYSADMIN` access, a web browser, basic SQL familiarity. No prior Snowflake experience required.

---

## What You Will Learn and Build

A three-layer data pipeline (`RAW → STAGING → REPORTING`) automated by a Task DAG, covering: Snowsight UI navigation, worksheets and workspaces, databases/schemas/roles with RBAC, file-based ingest (stages, file formats, COPY INTO), tables vs views, PII masking, warehouse scaling, zero-copy cloning, Snowflake Scripting stored procedures, task orchestration (CRON + DAG), and Cortex Code for AI-assisted SQL development.

| Step | Topic | Duration |
|---|---|---|
| 1 | Getting Familiar with the Snowsight UI | 15 min |
| 2 | Using Workspaces for Code Development | 15 min |
| 3 | Understanding Databases, Schemas and Roles | 25 min |
| 4 | Loading Reference Data from a CSV File | 20 min |
| 5 | Core Data Engineering — Tables, Views and Staging | 30 min |
| 6 | Building the Regulatory Reporting Layer | 25 min |
| 7 | Stored Procedures and Task Orchestration | 30 min |
| 8 | Accelerating Development with Cortex Code | 15 min |

---

## Repository Structure

```
uk-retail-bank-regulatory-reporting/
├── README.md
├── LEGAL
├── LICENSE
├── uk-retail-bank-regulatory-reporting.md  ← Main guide (sfguides format)
└── scripts/
    ├── setup.sql                           ← Database, schemas, warehouse
    ├── teardown.sql                        ← Clean up all lab objects
    ├── 02_data_generation.sql              ← Synthetic dataset (~530k rows)
    ├── 03_file_load.sql                    ← Stage, file format, COPY INTO
    ├── 04_staging_pipeline.sql             ← Staging tables and cleansing views
    ├── 05_reporting_layer.sql              ← LCR, CAR, Large Exposures views
    ├── 06_stored_procedures.sql            ← SP_REFRESH_STAGING, SP_REFRESH_REPORTING
    ├── 07_tasks.sql                        ← Task DAG and scheduling
    └── lcr_runoff_rates.csv                ← PRA reference data (25 rows)
```

All data is synthetic, generated within Snowflake using `GENERATOR()` and `RANDOM()`: Products (20), Customers (10K), Accounts (15K), Loans (3K), Transactions (500K). The CSV contains 25 rows of PRA/Basel III run-off rates for the LCR calculation.

---

## Running the Lab

**Option A** — Open `uk-retail-bank-regulatory-reporting.md` and follow each step. The guide references each SQL script at the appropriate step.

**Option B** — Preview locally with [claat](https://github.com/googlecodelabs/tools/tree/main/claat): `claat export uk-retail-bank-regulatory-reporting.md && claat serve`, then open `http://localhost:9090`.

**Option C** — Run SQL files in `scripts/` directly in Snowsight, in order (setup → 02 → 07).

---

## Clean Up

Run `scripts/teardown.sql` or:

```sql
USE ROLE SYSADMIN;
ALTER TASK IF EXISTS NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE   SUSPEND;
ALTER TASK IF EXISTS NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_STAGING   SUSPEND;
ALTER TASK IF EXISTS NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_REPORTING SUSPEND;
DROP DATABASE  IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```

---

## Resources

[Snowflake Docs](https://docs.snowflake.com) · [Snowflake Scripting](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/index) · [Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro) · [Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui) · [Cloning](https://docs.snowflake.com/en/user-guide/object-clone) · [Cortex Code](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code) · [PRA LCR Rulebook](https://www.bankofengland.co.uk/prudential-regulation/rulebook/made-rules/liquidity) · [Basel III LCR (BIS)](https://www.bis.org/publ/bcbs238.htm)
