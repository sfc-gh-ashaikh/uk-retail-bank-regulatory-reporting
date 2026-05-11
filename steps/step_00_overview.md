# NorthBridge Bank: Building a Regulatory Reporting Pipeline on Snowflake

**Estimated time: 5 minutes**

Welcome to the **NorthBridge Bank Hands-On Lab**.

You are a data engineer at **NorthBridge Bank**, a mid-size UK retail bank regulated by the Financial Conduct Authority (FCA) and the Prudential Regulation Authority (PRA). The bank's legacy on-premises regulatory reporting system is being decommissioned. Your team has been tasked with building a replacement pipeline on Snowflake to automate three critical regulatory reports:

| Report | Regulation | Purpose |
|---|---|---|
| **Liquidity Coverage Ratio (LCR)** | Basel III / CRD IV | Ensures the bank holds sufficient liquid assets to survive a 30-day stress scenario |
| **Capital Adequacy Report (CAR)** | Basel III Pillar 1 / CRR2 | Measures capital held against risk-weighted assets |
| **Large Exposures Register** | PRA Rulebook | Identifies any single counterparty exposure exceeding 25% of Tier 1 capital |

By the end of this lab, you will have built the full pipeline — from raw data ingest through to automated daily delivery — entirely on Snowflake.

## What You Will Learn

- How to navigate the Snowsight UI
- How to use worksheets and folders as a development workspace
- How to create and select databases, schemas and roles
- Core data engineering principles: tables, views, cloning and file-based ingest
- How to create stored procedures using Snowflake Scripting
- How to orchestrate a pipeline with Snowflake Tasks
- How to use Cortex Code to accelerate SQL development

## What You Will Need

- A Snowflake account with **SYSADMIN** role access
- A web browser (Chrome or Firefox recommended)
- The lab assets folder downloaded from this repository

## What You Will Build

A three-layer regulatory reporting data pipeline:

```
RAW (ingest) → STAGING (cleanse) → REPORTING (regulatory views)
                    ↕
         Automated by a Task DAG (daily at 06:00 UTC)
```

## Prerequisites

- Basic familiarity with SQL (SELECT, JOIN, GROUP BY)
- No prior Snowflake experience required

> **Note**: All data used in this lab is entirely synthetic. No real customer data is used at any point.
