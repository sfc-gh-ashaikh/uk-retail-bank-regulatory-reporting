# NorthBridge Bank: Building a Regulatory Reporting Pipeline on Snowflake

Welcome to the **NorthBridge Bank Hands-On Lab**.

You are a data engineer at **NorthBridge Bank**, a mid-size UK retail bank regulated by the Financial Conduct Authority (FCA) and the Prudential Regulation Authority (PRA). The bank's legacy on-premises regulatory reporting system is being decommissioned. Your team has been tasked with building a replacement pipeline on Snowflake to automate three critical regulatory reports:

| Report | Regulation | Purpose |
|---|---|---|
| **Liquidity Coverage Ratio (LCR)** | Basel III / CRD IV | Ensures the bank holds sufficient liquid assets to survive a 30-day stress scenario |
| **Capital Adequacy Report (CAR)** | Basel III Pillar 1 / CRR2 | Measures capital held against risk-weighted assets |
| **Large Exposures Register** | PRA Rulebook | Identifies any single counterparty exposure exceeding 25% of Tier 1 capital |

By the end of this lab, you will have built the full pipeline — from raw data ingest through to automated daily delivery — entirely on Snowflake.

### What You Will Learn

- How to navigate the Snowsight UI
- How to use worksheets and folders as a development workspace
- How to create and select databases, schemas and roles
- Core data engineering principles: tables, views, cloning and file-based ingest
- How to create stored procedures using Snowflake Scripting
- How to orchestrate a pipeline with Snowflake Tasks
- How to use Cortex Code to accelerate SQL development

### What You Will Need

- A Snowflake account with **SYSADMIN** role access
- A web browser (Chrome or Firefox recommended)
- Basic familiarity with SQL (SELECT, JOIN, GROUP BY)
- No prior Snowflake experience required

### What You Will Build

A three-layer regulatory reporting data pipeline:

```
RAW (ingest) → STAGING (cleanse) → REPORTING (regulatory views)
                    ↕
         Automated by a Task DAG (daily at 06:00 UTC)
```

> **Note**: All data used in this lab is entirely synthetic. No real customer data is used at any point.

---

## Running the Lab

Follow the step guides in `steps/` in order (01 → 09). Each file contains instructions and the full SQL — copy and paste directly into a Snowsight worksheet and run section by section.

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
| 9 | Clean Up | 5 min |

---

## Resources

[Snowflake Docs](https://docs.snowflake.com) · [Snowflake Scripting](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/index) · [Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro) · [Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui) · [Cloning](https://docs.snowflake.com/en/user-guide/object-clone) · [Cortex Code](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code) · [PRA LCR Rulebook](https://www.bankofengland.co.uk/prudential-regulation/rulebook/made-rules/liquidity) · [Basel III LCR (BIS)](https://www.bis.org/publ/bcbs238.htm)
