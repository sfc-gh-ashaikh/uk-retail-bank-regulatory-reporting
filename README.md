# NorthBridge Bank: Building a Regulatory Reporting Pipeline on Snowflake

A hands-on lab for data engineers and analytical application developers at UK retail banks. You play a data engineer at NorthBridge Bank — a mid-size UK retail bank regulated by the FCA and PRA — tasked with replacing a legacy on-premises reporting system with a modern pipeline on Snowflake.

---

## The Story

NorthBridge Bank's legacy regulatory reporting system is being decommissioned. The Risk & Compliance team needs three critical reports delivered daily before the London market opens: the Liquidity Coverage Ratio (LCR), Capital Adequacy Report (CAR), and Large Exposures Register. Your team has been given six weeks and a Snowflake account. This lab walks through everything you build — from standing up the environment to scheduling the daily pipeline.

---

## What Participants Will Learn

| Topic | What You Will Learn |
|---|---|
| Snowsight UI | Navigate the interface, Query History, Task History, Data Explorer |
| Workspaces | Organise worksheets and folders for structured pipeline development |
| Databases, Schemas & Roles | Three-layer architecture (RAW, STAGING, REPORTING), RBAC, context switching |
| File-Based Ingest | Internal stages, file formats, COPY INTO — loading PRA reference data |
| Tables & Views | DDL conventions, cleansing views, PII masking, zero-copy cloning |
| Warehouse Scaling | Instant resize to hit the 06:00 UTC reporting deadline |
| Regulatory Reporting Layer | LCR, CAR and Large Exposures views using Basel III / PRA logic |
| Stored Procedures | Snowflake Scripting with variables, exception handling, AUDIT_LOG |
| Task Orchestration | DAG creation, CRON scheduling, leaf-to-root resume, monitoring |
| Cortex Code | AI-assisted SQL generation, explanation and refactoring |

---

## What Participants Will Build

A three-layer data pipeline producing three regulatory reports:

| Report | Regulation | What It Measures |
|---|---|---|
| Liquidity Coverage Ratio (LCR) | Basel III / CRD IV | Liquid asset buffer vs 30-day stress outflows |
| Capital Adequacy Report (CAR) | Basel III Pillar 1 / CRR2 | Tier 1 capital vs risk-weighted assets |
| Large Exposures Register | PRA Rulebook 4.1 | Single counterparty concentration (25% Tier 1 limit) |

---

## Lab Structure

**Duration**: ~3 hours (half-day)  
**Audience**: Data engineers, analytical application developers  
**Snowflake Features**: Snowsight UI, worksheets, databases/schemas/roles, tables, views, internal stages, file formats, COPY INTO, zero-copy cloning, Snowflake Scripting stored procedures, tasks, Cortex Code

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

## Requirements Coverage

| Requirement | Step |
|---|---|
| Getting familiar with the Snowsight UI | Step 1 |
| How to use workspaces for code development | Step 2 |
| Understanding & selecting databases, schemas and roles | Step 3 |
| Core data engineering principles in Snowflake | Steps 4 & 5 |
| Creating tables and views | Step 5 |
| Creating stored procedures | Step 7 |
| How to use tasks for orchestration | Step 7 |
| Using Cortex Code to accelerate building data pipelines | Step 8 |

---

## Repository Structure

```
uk-retail-bank-regulatory-reporting/
├── README.md                                                    ← This file
└── site/
    └── sfguides/
        └── src/
            └── uk-retail-bank-regulatory-reporting/
                ├── uk-retail-bank-regulatory-reporting.md       ← Main guide (sfguides format)
                └── assets/
                    ├── 01_setup.sql                             ← Database, schemas, warehouse
                    ├── 02_data_generation.sql                   ← Synthetic dataset (~530k rows)
                    ├── lcr_runoff_rates.csv                     ← PRA reference data (25 rows)
                    ├── 03_file_load.sql                         ← Stage, file format, COPY INTO
                    ├── 04_staging_pipeline.sql                  ← Staging tables and cleansing views
                    ├── 05_reporting_layer.sql                   ← LCR, CAR, Large Exposures views
                    ├── 06_stored_procedures.sql                 ← SP_REFRESH_STAGING, SP_REFRESH_REPORTING
                    └── 07_tasks.sql                             ← Task DAG and scheduling
```

---

## Synthetic Dataset

All data is generated entirely within Snowflake using `GENERATOR()` and `RANDOM()`. No external files are needed for the core dataset. The data is entirely fictional.

| Table | Rows | Key UK Fields |
|---|---|---|
| `RAW.PRODUCTS` | 20 | LCR categories, Basel III risk weights |
| `RAW.CUSTOMERS` | 10,000 | NI numbers, UK postcodes, KYC status |
| `RAW.ACCOUNTS` | 15,000 | Sort codes, account numbers, GBP balances |
| `RAW.LOANS` | 3,000 | Mortgages, personal loans, auto finance |
| `RAW.TRANSACTIONS` | 500,000 | 6 months of card, BACS, CHAPS, standing order data |

The CSV file `lcr_runoff_rates.csv` contains 25 rows of PRA/Basel III prescribed run-off rates, used as reference data in the LCR calculation.

---

## Prerequisites

- A Snowflake account with `SYSADMIN` role access
- A web browser (Chrome or Firefox recommended)
- This repository downloaded locally

No prior Snowflake experience is required. Basic SQL familiarity (SELECT, JOIN, GROUP BY) is assumed.

---

## Running the Lab

### Option A — Follow the Guide

Open the main guide file and follow each step in sequence:

```
site/sfguides/src/uk-retail-bank-regulatory-reporting/uk-retail-bank-regulatory-reporting.md
```

The guide references each SQL asset file at the appropriate step.

### Option B — Preview Locally with claat

To render the guide as an interactive HTML tutorial (matching the Snowflake Guides website format):

1. Install the [claat tool](https://github.com/googlecodelabs/tools/tree/main/claat):
   ```bash
   go install github.com/googlecodelabs/tools/claat@latest
   ```

2. Export the markdown to HTML:
   ```bash
   cd site/sfguides/src/uk-retail-bank-regulatory-reporting
   claat export uk-retail-bank-regulatory-reporting.md
   ```

3. Serve locally:
   ```bash
   claat serve
   ```

4. Open `http://localhost:9090` in your browser.

### Option C — Run SQL Assets Directly

Each SQL file in the `assets/` folder can be run independently in Snowsight. Run them in order (01 → 07).

---

## Data Architecture

```
Data Ingest
  ├── SQL GENERATOR (inline) ──────────────────────────────────┐
  └── lcr_runoff_rates.csv → Internal Stage → COPY INTO ───────┤
                                                               ↓
RAW Schema                        STAGING Schema              REPORTING Schema
──────────────                    ──────────────              ────────────────
CUSTOMERS (10k)  ── view ──────► STG_CUSTOMERS_V             V_LCR_COMPONENTS
ACCOUNTS  (15k)  ── view ──────► STG_ACCOUNTS_V    ────────► V_CAPITAL_ADEQUACY
TRANSACTIONS(500k)─ view ──────► STG_TRANSACTIONS_V          V_LARGE_EXPOSURES
LOANS     (3k)   ── view ──────► STG_LOANS_V
LCR_RUNOFF_RATES ──────────────────────────────── joined in ──► V_LCR_COMPONENTS

Orchestration (daily at 06:00 UTC)
  TASK_INGEST_COMPLETE
       └── TASK_REFRESH_STAGING   → SP_REFRESH_STAGING()   → AUDIT_LOG
                └── TASK_REFRESH_REPORTING → SP_REFRESH_REPORTING() → AUDIT_LOG
                    └── Creates: SNAP_LCR_COMPONENTS
                                 SNAP_CAPITAL_ADEQUACY
                                 SNAP_LARGE_EXPOSURES
```

---

## Clean Up

To remove all lab objects from your Snowflake account after completing the lab:

```sql
USE ROLE SYSADMIN;
ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_INGEST_COMPLETE   SUSPEND;
ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_STAGING   SUSPEND;
ALTER TASK NORTHBRIDGE_BANK_HOL.STAGING.TASK_REFRESH_REPORTING SUSPEND;
DROP DATABASE  IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```

---

## Related Resources

- [Snowflake Documentation](https://docs.snowflake.com)
- [Snowflake Developer Guides](https://www.snowflake.com/en/developers/guides/)
- [Snowflake Scripting Reference](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/index)
- [Introduction to Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [PRA Rulebook — Liquidity (LCR)](https://www.bankofengland.co.uk/prudential-regulation/rulebook/made-rules/liquidity)
- [Basel III LCR Framework (BIS)](https://www.bis.org/publ/bcbs238.htm)
