author: NorthBridge Bank HOL Team
id: uk-retail-bank-regulatory-reporting
summary: Build a FCA/PRA regulatory reporting data pipeline on Snowflake for a UK retail bank. Covers Snowsight UI navigation, workspaces, databases/schemas/roles, file loading, staging, LCR/CAR/large exposures reporting, stored procedures, task orchestration, and Cortex Code.
categories: snowflake-site:taxonomy/solution-center/data-engineering
environments: web
status: Published
feedback link: https://github.com/Snowflake-Labs/sfguides/issues
language: en

# NorthBridge Bank: Building a Regulatory Reporting Pipeline on Snowflake
<!-- ------------------------ -->
## Overview
Duration: 5

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
- The lab assets folder downloaded from this repository

### What You Will Build

A three-layer regulatory reporting data pipeline:

```
RAW (ingest) → STAGING (cleanse) → REPORTING (regulatory views)
                    ↕
         Automated by a Task DAG (daily at 06:00 UTC)
```

### Prerequisites

- Basic familiarity with SQL (SELECT, JOIN, GROUP BY)
- No prior Snowflake experience required

> **Note**: All data used in this lab is entirely synthetic. No real customer data is used at any point.

<!-- ------------------------ -->
## Step 1: Getting Familiar with the Snowsight UI
Duration: 15

Snowsight is Snowflake's browser-based interface. Log in to your Snowflake account and explore the key areas:

**Left Navigation Panel** — The sidebar gives you access to **Home** (activity summary), **Data** (browse databases/schemas/tables), **Worksheets** (SQL editor), **Notebooks**, **Monitoring** (Query History, Task History) and **Admin** (warehouses, users, roles).

**Top Bar Context Controls** — Every worksheet shows your current **Role**, **Warehouse** and **Database/Schema**. Changing your role changes what objects are visible — this is Snowflake's role-based access control (RBAC) in action.

**Key areas to explore now:**
- **Monitoring > Query History** — every SQL statement executed in your account, with status, duration and full SQL text. Invaluable for debugging and regulatory audit trails.
- **Data** — expand databases to browse schemas, tables and views. Click any table to see column types, data preview and statistics.
- **Monitoring > Task History** — where you will monitor your automated pipeline in Step 7.

### Your First Query

Click **Worksheets** in the left nav, then click **+** to open a new worksheet.

Run the following to confirm your connection context:

```sql
SELECT
    CURRENT_USER()      AS my_user,
    CURRENT_ROLE()      AS my_role,
    CURRENT_WAREHOUSE() AS my_warehouse,
    CURRENT_DATABASE()  AS my_database,
    CURRENT_TIMESTAMP() AS current_time;
```

Click the **Run** button (▶) or press **Cmd + Enter** (Mac) / **Ctrl + Enter** (Windows).

You should see your user, role and warehouse returned. If the warehouse shows `null`, select `NORTHBRIDGE_WH` from the warehouse dropdown in the top bar.

<!-- ------------------------ -->
## Step 2: Using Workspaces for Code Development
Duration: 15

Worksheets are Snowflake's primary code development environment. Used well, they provide a structured workspace for building and testing data pipelines.

**Create your first worksheet:** Click **Worksheets** in the left nav, click **+** (top right), and rename it to `NORTHBRIDGE_HOL_SETUP`. Good names describe what the code does — not who wrote it or when.

**Organise with folders:** Click the **+** folder icon, create a folder called **NorthBridge HOL**, and drag your worksheet into it. For this lab, create one worksheet per step:

| Worksheet Name | Step |
|---|---|
| `01_SETUP` | Step 3: Environment Setup |
| `02_DATA_GENERATION` | Step 3: Data Loading |
| `03_FILE_LOAD` | Step 4: CSV Reference Data |
| `04_STAGING` | Step 5: Staging Layer |
| `05_REPORTING` | Step 6: Reporting Layer |
| `06_PROCEDURES` | Step 7: Stored Procedures |
| `07_TASKS` | Step 7: Task Orchestration |
| `08_CORTEX_CODE` | Step 8: Cortex Code |

### Keyboard Shortcuts and Tips

| Action | Mac | Windows |
|---|---|---|
| Run selected statement | `Cmd + Enter` | `Ctrl + Enter` |
| Run all statements | `Cmd + Shift + Enter` | `Ctrl + Shift + Enter` |
| Comment/uncomment selection | `Cmd + /` | `Ctrl + /` |
| Format SQL | `Cmd + Shift + F` | `Ctrl + Shift + F` |

> **Tip**: Highlight a single statement and press `Cmd/Ctrl + Enter` to run only that statement. This prevents accidentally running an entire file.

The **context bar** at the top of every worksheet shows your current Role, Warehouse, Database and Schema. Setting this context lets you write `SELECT * FROM CUSTOMERS` instead of fully qualified names. Always verify your context before running a script.

The **results panel** at the bottom lets you download results as CSV, switch to Chart view, or copy cells/rows.

Create the remaining worksheets for the lab before proceeding to Step 3.

<!-- ------------------------ -->
## Step 3: Understanding Databases, Schemas and Roles
Duration: 25

In this step you will create the NorthBridge Bank environment and load the synthetic dataset.

Every object in Snowflake exists within a hierarchy: **Organisation > Account > Database > Schema > Tables/Views/Procedures**. When you write SQL without fully qualifying names, Snowflake uses your current database and schema context.

NorthBridge Bank uses a **three-layer architecture** — a standard pattern in regulated data environments:

| Schema | Purpose | Who Writes | Who Reads |
|---|---|---|---|
| **RAW** | Immutable ingest zone. Data lands here exactly as received from source systems. Never modified after load. | Ingest pipelines | Data engineers |
| **STAGING** | Cleansed, standardised, enriched data. PII is masked, data types are enforced. | Data engineers | Analytics engineers |
| **REPORTING** | Business-facing regulatory views and daily snapshots. | Analytics engineers | Risk & Compliance, regulators |

This separation means a bug in the reporting layer can never corrupt the raw source data.

### Create the Environment

Open your `01_SETUP` worksheet and run `scripts/setup.sql`. This creates the `NORTHBRIDGE_BANK_HOL` database, three schemas (`RAW`, `STAGING`, `REPORTING`), the `NORTHBRIDGE_WH` warehouse (X-Small, auto-suspend 60s), and the `STAGING.AUDIT_LOG` table. Verify in the left **Data** panel that the database and schemas are visible.

**Try RBAC:** Toggle between `SYSADMIN` and `PUBLIC` in the role selector. As `PUBLIC`, the database browser may show fewer objects — this is role-based access control in action. Switch back to `SYSADMIN` before continuing.

### Load the Synthetic Dataset

Open your `02_DATA_GENERATION` worksheet and run `scripts/02_data_generation.sql`.

> **Note**: The transactions table generates ~500,000 rows. This step takes approximately 60 seconds.

Once complete, verify the row counts:

```sql
SELECT 'PRODUCTS'     AS table_name, COUNT(*) FROM RAW.PRODUCTS     UNION ALL
SELECT 'CUSTOMERS'    AS table_name, COUNT(*) FROM RAW.CUSTOMERS    UNION ALL
SELECT 'ACCOUNTS'     AS table_name, COUNT(*) FROM RAW.ACCOUNTS     UNION ALL
SELECT 'LOANS'        AS table_name, COUNT(*) FROM RAW.LOANS        UNION ALL
SELECT 'TRANSACTIONS' AS table_name, COUNT(*) FROM RAW.TRANSACTIONS;
```

You should see approximately:

| Table | Expected Rows |
|---|---|
| PRODUCTS | 20 |
| CUSTOMERS | 10,000 |
| ACCOUNTS | 15,000 |
| LOANS | 3,000 |
| TRANSACTIONS | 500,000 |

**Explore the data:** Click **Data > NORTHBRIDGE_BANK_HOL > RAW > CUSTOMERS** and use the **Data Preview** tab. Notice the UK-specific fields: `NI_NUMBER` (National Insurance format), `POSTCODE` (UK format), `SORT_CODE` (bank sort code) and all amounts in GBP.

<!-- ------------------------ -->
## Step 4: Loading Reference Data from a CSV File
Duration: 20

Not all data can be generated in SQL. Reference data — like regulatory rate tables published by the PRA — arrives as files. This step shows two ways to load a CSV file into Snowflake.

The PRA has published updated **LCR run-off rates** for the new regulatory year. Your team has received `lcr_runoff_rates.csv` and needs to load it into Snowflake. Download `scripts/lcr_runoff_rates.csv` from this repository to your local machine.

Under Basel III, each liability category is multiplied by a prescribed **run-off rate** — the assumed withdrawal percentage under a 30-day stress scenario (e.g. Retail Stable deposits at 5%, Wholesale Financial Institutions at 100%). We store these in a reference table rather than hard-coding them — making updates easy when the PRA revises rates.

### Path A — Snowsight Load Data Wizard (UI)

1. In the left nav, click **Data**
2. Navigate to **NORTHBRIDGE_BANK_HOL > RAW**
3. Click **+ Create** (top right) > **Table from file**
4. Upload `lcr_runoff_rates.csv`
5. Set the table name to `LCR_RUNOFF_RATES`
6. Review column mapping — Snowsight auto-detects types
7. Click **Load**

### Path B — SQL (Stages + COPY INTO)

Open your `03_FILE_LOAD` worksheet and run `scripts/03_file_load.sql` section by section.

The key concepts:

**Stage** — a landing zone inside your Snowflake account where files are held before loading:
```sql
CREATE STAGE IF NOT EXISTS RAW.NORTHBRIDGE_REF_STAGE;
```

**File Format** — tells Snowflake how to parse the file (delimiter, header row, null handling):
```sql
CREATE FILE FORMAT IF NOT EXISTS RAW.CSV_HEADER_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE;
```

**COPY INTO** — loads the staged file into the target table:
```sql
COPY INTO RAW.LCR_RUNOFF_RATES (...)
FROM @RAW.NORTHBRIDGE_REF_STAGE/lcr_runoff_rates.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW.CSV_HEADER_FORMAT')
ON_ERROR = 'ABORT_STATEMENT';
```

> **Note**: To upload the file to the stage via SQL (SnowSQL CLI): `PUT file:///path/to/lcr_runoff_rates.csv @RAW.NORTHBRIDGE_REF_STAGE;`
> For this lab, use the Snowsight stage UI to upload the file (click the stage object in Data browser > Upload button).

### Verify and Reload

```sql
SELECT liability_category, sub_category, run_off_rate_pct, regulatory_basis
FROM RAW.LCR_RUNOFF_RATES ORDER BY liability_category, sub_category;

SELECT COUNT(*) AS rows_loaded FROM RAW.LCR_RUNOFF_RATES;
```

You should see 25 rows. When the PRA publishes revised rates, simply `TRUNCATE TABLE RAW.LCR_RUNOFF_RATES`, re-upload the new CSV to the stage, and re-run `COPY INTO`.

<!-- ------------------------ -->
## Step 5: Core Data Engineering — Tables, Views and Staging
Duration: 40

In this step you will build the **STAGING layer**: cleansed, standardised and enriched data that the reporting layer will read from.

Open your `04_STAGING` worksheet and work through `scripts/04_staging_pipeline.sql`.

### Parts A & B: Staging Tables and Cleansing Views

**Run Part A** to create four staging tables. Note the DDL conventions: explicit data types (`NUMBER`, `VARCHAR(n)`), `NOT NULL` constraints, `DEFAULT CURRENT_TIMESTAMP()` for load auditing, and `TIMESTAMP_NTZ` (timezone-naive — used in banking to avoid DST ambiguity).

**Run Part B** to create cleansing views. Views store a query definition, not data — every access reads the latest from the underlying tables.

**STG_CUSTOMERS_V** — applies two key transformations:

*NI Number masking:*
```sql
SUBSTRING(ni_number, 1, 2) || ' ** ** ** ' ||
    SUBSTRING(ni_number, LENGTH(ni_number), 1)  AS ni_number_masked
```
This exposes only the prefix and suffix — sufficient for reconciliation, not sufficient for identity theft.

*Postcode standardisation:*
```sql
UPPER(TRIM(postcode))  AS postcode_formatted
```
Ensures all postcodes are uppercase with no leading/trailing spaces — critical for address matching and geographic analysis.

**STG_ACCOUNTS_V** — enriches accounts with product details:
```sql
FROM RAW.ACCOUNTS  a
JOIN RAW.PRODUCTS  p ON a.product_id = p.product_id
WHERE a.status IN ('ACTIVE', 'DORMANT')
```
The JOIN to PRODUCTS adds `product_name`, `lcr_category` and `risk_weight_pct` — data needed by the LCR and CAR calculations.

**STG_TRANSACTIONS_V** — filters to only cleared transactions:
```sql
WHERE status = 'CLEARED'
  AND amount_gbp > 0
  AND amount_gbp < 10000000
```
Rejected and pending transactions are excluded from regulatory calculations. The amount bounds catch data quality issues (negative amounts, implausibly large values).

**STG_LOANS_V** — derives key risk metrics:
```sql
ROUND(l.outstanding_balance_gbp * (l.risk_weight_pct / 100), 2) AS risk_weighted_asset_gbp,

CASE
    WHEN l.collateral_value_gbp > 0
    THEN ROUND((l.outstanding_balance_gbp / l.collateral_value_gbp) * 100, 2)
    ELSE NULL
END  AS ltv_ratio_pct
```
Risk-weighted assets and Loan-to-Value ratios are derived at query time from the source data — no duplication of values.

For this pipeline: views feed the reporting layer at query time; staging tables are physical snapshots populated daily by the task pipeline.

### Part C: Warehouse Scaling

If a view query is slow, you scale compute — not restructure your pipeline. Snowflake lets you resize a warehouse instantly with `ALTER WAREHOUSE`.

Run Part C section by section: first disable caching (`ALTER SESSION SET USE_CACHED_RESULT = FALSE`), then run the benchmark query on X-SMALL:

```sql
SELECT
    a.account_type,
    t.debit_credit,
    t.merchant_category,
    COUNT(*)                            AS txn_count,
    ROUND(SUM(t.amount_gbp), 2)        AS total_amount_gbp,
    ROUND(AVG(t.amount_gbp), 2)        AS avg_amount_gbp
FROM STAGING.STG_TRANSACTIONS_V  t
JOIN STAGING.STG_ACCOUNTS_V      a ON t.account_id = a.account_id
WHERE t.transaction_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY a.account_type, t.debit_credit, t.merchant_category
ORDER BY total_amount_gbp DESC;
```

Note the execution time in the **Query History** panel or the results pane.

Then scale up to MEDIUM (`ALTER WAREHOUSE NORTHBRIDGE_WH SET WAREHOUSE_SIZE = 'MEDIUM'`), suspend/resume to clear cache, and re-run the same query. Compare execution times — MEDIUM has 4× the compute, with zero changes to your SQL.

Scale back down afterwards (`SET WAREHOUSE_SIZE = 'X-SMALL'` and re-enable caching). In production, the task DAG could automate this scale-up/scale-down pattern.

> **Key Takeaway**: Snowflake separates storage from compute. Scaling is instant and does not affect your data or other users.

### Parts D & E: Validate Views and Zero-Copy Cloning

**Run Part D** to confirm your views return clean, enriched data.

**Run Part E** to clone the transactions table:

```sql
CREATE TABLE IF NOT EXISTS RAW.TRANSACTIONS_DEV
    CLONE RAW.TRANSACTIONS;
```

This completes **instantly** — regardless of the table size — and uses **no additional storage** until data in the clone diverges from the original.

```sql
SELECT
    'RAW.TRANSACTIONS'     AS table_name, COUNT(*) FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'RAW.TRANSACTIONS_DEV' AS table_name, COUNT(*) FROM RAW.TRANSACTIONS_DEV;
```

Both tables show the same row count. The clone is a fully independent copy — modifications to `TRANSACTIONS_DEV` do not affect `TRANSACTIONS`. This is the recommended pattern for:

- Testing pipeline changes safely
- Creating development/UAT environments instantly
- Providing isolated environments for data analysis without impacting production

> **Snowflake Capability**: Zero-copy cloning works on databases, schemas and tables. Combined with Time Travel (which retains historical versions of data for up to 90 days), this gives data engineers powerful tools for safe development and data recovery.

<!-- ------------------------ -->
## Step 6: Building the Regulatory Reporting Layer
Duration: 25

In this step you will create the three FCA/PRA regulatory reporting views in the `REPORTING` schema.

Open your `05_REPORTING` worksheet and work through `scripts/05_reporting_layer.sql`.

### Report 1: Liquidity Coverage Ratio (LCR)

**Formula**: LCR = High Quality Liquid Assets / Net Cash Outflows (30-day stress) × 100

**Regulatory minimum**: 100% (PRA post-Brexit maintained from CRD IV)

The `V_LCR_COMPONENTS` view uses a multi-CTE structure to calculate LCR in stages:

```sql
WITH
hqla_stock AS (
    -- Sum HQLA Level 1 and Level 2A account balances
    ...
),
gross_outflows AS (
    -- Sum last 30 days of debit transactions
    -- Join to LCR_RUNOFF_RATES to apply the stress multiplier per liability category
    ...
),
gross_inflows AS (
    -- Sum last 30 days of credit transactions
    ...
),
lcr_calc AS (
    -- Net outflows = gross outflows minus inflows (capped at 75% of outflows)
    -- LCR = HQLA / Net outflows
    ...
)
SELECT ..., lcr_ratio_pct, lcr_status FROM lcr_calc;
```

The key join to the reference data loaded in Step 4:
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

### Report 2: Capital Adequacy Report (CAR)

**Formula**: Tier 1 Capital Ratio = Tier 1 Capital / Risk-Weighted Assets × 100

**Regulatory minimum**: Tier 1 ≥ 6.0%, Total Capital ≥ 8.0% (plus PRA buffers)

The `V_CAPITAL_ADEQUACY` view aggregates risk-weighted assets from the staged loan book:

```sql
ROUND(SUM(l.risk_weighted_asset_gbp), 2) AS risk_weighted_assets_gbp
```

Risk weights are defined in the PRODUCTS table per Basel III standardised approach:
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

### Report 3: Large Exposures Register

**Rule**: PRA Rulebook — Large Exposures 4.1. No single exposure may exceed **25% of Tier 1 capital**.

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

Run and check for any breaches:
```sql
SELECT large_exposure_flag, COUNT(*) AS customer_count
FROM REPORTING.V_LARGE_EXPOSURES
GROUP BY large_exposure_flag;
```

> With synthetic random data, you may see a small number of breaches — this is expected and realistic. In a real bank, breaches would trigger an immediate escalation to the risk team.

<!-- ------------------------ -->
## Step 7: Stored Procedures and Task Orchestration
Duration: 30

The reporting views built in Step 6 always reflect live data. For regulatory submissions, we also need **daily point-in-time snapshots** — a frozen copy of each report as at the submission date. This step automates that process.

### Part A: Stored Procedures

Open your `06_PROCEDURES` worksheet and work through `scripts/06_stored_procedures.sql`.

**SP_REFRESH_STAGING** truncates and reloads all staging tables from RAW using **Snowflake Scripting** — a SQL-native procedural language with variables, control flow and exception handling:

```sql
CREATE OR REPLACE PROCEDURE STAGING.SP_REFRESH_STAGING()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_proc_name     VARCHAR DEFAULT 'SP_REFRESH_STAGING';
    v_rows_affected NUMBER  DEFAULT 0;
BEGIN
    -- Truncate and reload STG_CUSTOMERS
    BEGIN
        TRUNCATE TABLE STAGING.STG_CUSTOMERS;
        INSERT INTO STAGING.STG_CUSTOMERS SELECT ... FROM STAGING.STG_CUSTOMERS_V;
        v_rows_affected := SQLROWCOUNT;

        INSERT INTO STAGING.AUDIT_LOG (...) VALUES (..., 'SUCCESS');

    EXCEPTION
        WHEN OTHER THEN
            INSERT INTO STAGING.AUDIT_LOG (...) VALUES (..., 'FAILED', SQLERRM);
            RETURN 'FAILED: ' || SQLERRM;
    END;

    -- Repeat for other tables...
    RETURN 'SUCCESS — ' || v_total_rows::VARCHAR || ' rows refreshed.';
END;
$$;
```

Key features: `DECLARE` (variables with defaults), `SQLROWCOUNT` (rows affected), `BEGIN ... EXCEPTION WHEN OTHER THEN ... END` (per-table error handling without aborting), and `SQLERRM` (error message).

**SP_REFRESH_REPORTING** creates daily snapshot tables (`SNAP_LCR_COMPONENTS`, `SNAP_CAPITAL_ADEQUACY`, `SNAP_LARGE_EXPOSURES`) with a `snapshot_date` column — preserving a full audit trail of regulatory positions.

**Test both procedures:**

```sql
CALL STAGING.SP_REFRESH_STAGING();
CALL STAGING.SP_REFRESH_REPORTING();
```

Verify the audit log:
```sql
SELECT procedure_name, step_name, rows_processed, status, executed_at
FROM STAGING.AUDIT_LOG
ORDER BY executed_at DESC
LIMIT 20;
```

### Part B: Task Orchestration

Open your `07_TASKS` worksheet and work through `scripts/07_tasks.sql`.

A **task** executes SQL on a schedule or when a predecessor completes. Tasks linked by dependencies form a **DAG** (Directed Acyclic Graph). NorthBridge Bank's pipeline DAG:

```
TASK_INGEST_COMPLETE          ← Root task (scheduled: 06:00 UTC daily)
     │
     └── TASK_REFRESH_STAGING  ← Calls SP_REFRESH_STAGING()
               │
               └── TASK_REFRESH_REPORTING  ← Calls SP_REFRESH_REPORTING()
```

The root task runs on a **CRON schedule** — at 06:00 UTC every day, before the London markets open and before the FCA's daily reporting window:

```sql
SCHEDULE = 'USING CRON 0 6 * * * UTC'
```

Child tasks use `AFTER` to declare their dependency:

```sql
CREATE OR REPLACE TASK STAGING.TASK_REFRESH_STAGING
    WAREHOUSE = NORTHBRIDGE_WH
    AFTER     STAGING.TASK_INGEST_COMPLETE
AS
CALL STAGING.SP_REFRESH_STAGING();
```

**Resume tasks leaf-to-root** (tasks are created `SUSPENDED`):

```sql
ALTER TASK STAGING.TASK_REFRESH_REPORTING RESUME;
ALTER TASK STAGING.TASK_REFRESH_STAGING   RESUME;
ALTER TASK STAGING.TASK_INGEST_COMPLETE   RESUME;
```

> **Why leaf first?** If you resume the root task before the children are active, the root task will complete and try to trigger suspended children — which won't run. Always work bottom-up.

**Manually trigger** rather than waiting for 06:00 UTC:

```sql
EXECUTE TASK STAGING.TASK_INGEST_COMPLETE;
```

**Monitor:** Navigate to **Monitoring > Task History** to see each task's status, duration, DAG graph and error messages. Give it 30–60 seconds, then refresh.

**Suspend tasks** when finished to avoid unnecessary compute:

```sql
ALTER TASK STAGING.TASK_INGEST_COMPLETE   SUSPEND;
ALTER TASK STAGING.TASK_REFRESH_STAGING   SUSPEND;
ALTER TASK STAGING.TASK_REFRESH_REPORTING SUSPEND;
```

<!-- ------------------------ -->
## Step 8: Accelerating Development with Cortex Code
Duration: 15

Cortex Code is Snowflake's AI assistant built directly into the Snowsight SQL editor. It helps you generate, explain, and optimise SQL — without ever leaving your worksheet.

Open your `08_CORTEX_CODE` worksheet.

> **Data Residency**: Cortex Code runs entirely within your Snowflake account. Your SQL and schema metadata never leave your Snowflake environment.

Click the **Cortex Code** icon (✦) in the top-right corner of the worksheet editor, or type a natural language comment directly in the worksheet for inline completions.

### Exercise 1 — Generate a Query

Type the following comment into your worksheet and invoke Cortex Code:

```sql
-- Show the top 10 customers by total loan exposure for the large exposures register,
-- including their risk rating and whether they are in breach of the PRA 25% limit
```

Cortex Code will suggest a SQL query. Review it, then run it. Compare the output with your `V_LARGE_EXPOSURES` view — do the results agree?

> **Best Practice**: Always validate AI-generated SQL against expected results. Cortex Code is a starting point, not a finished product.

### Exercise 2 — Explain Code

Highlight the entire body of `SP_REFRESH_STAGING` (copy it into your worksheet first).

In the Cortex Code chat panel, type:
```
Explain what this stored procedure does and what each section is responsible for
```

Read the explanation. Does it match your understanding from Step 7?

### Exercise 3 — Refactor SQL

Paste the following query into your worksheet:

```sql
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    (SELECT SUM(outstanding_balance_gbp)
     FROM RAW.LOANS l
     WHERE l.customer_id = c.customer_id) AS total_loan_exposure_gbp
FROM RAW.CUSTOMERS c
WHERE (SELECT SUM(outstanding_balance_gbp)
       FROM RAW.LOANS l
       WHERE l.customer_id = c.customer_id) > 100000
ORDER BY total_loan_exposure_gbp DESC;
```

Ask Cortex Code:
```
Rewrite this query to eliminate the correlated subqueries using a JOIN and aggregation instead
```

Run both versions and compare execution plans. The rewritten version should scan fewer rows.

### Exercise 4 — Extend the Pipeline

Type the following comment and let Cortex Code generate the SQL:

```sql
-- Write a query to identify which LCR run-off rate categories
-- have had no transactions in the last 30 days.
-- This would indicate a potential gap in our run-off rate reference data.
```

This is a real data quality check a data engineer would want to build into the pipeline — Cortex Code can scaffold it in seconds.

### When to Trust vs Validate

| Cortex Code is reliable for | Validate carefully when |
|---|---|
| Standard SQL patterns (GROUP BY, JOIN, aggregation) | Complex window function logic |
| Explaining well-structured stored procedures | Regulatory calculations with specific formula requirements |
| Scaffolding repetitive boilerplate | Any query that feeds a compliance submission |
| Suggesting optimisation approaches | Schema-specific column names (Cortex Code may hallucinate) |

<!-- ------------------------ -->
## Conclusion and What You Learned
Duration: 5

Congratulations — you have built a complete FCA/PRA regulatory reporting pipeline on Snowflake for NorthBridge Bank.

You built a complete three-layer regulatory reporting pipeline: RAW → STAGING (cleansing views) → REPORTING (LCR, CAR, Large Exposures), automated by a Task DAG running daily at 06:00 UTC with full audit logging.

You learned: Snowsight UI navigation, worksheet workspaces, databases/schemas/roles with RBAC, tables vs views, warehouse scaling, file-based ingest (stages + COPY INTO), zero-copy cloning, Snowflake Scripting stored procedures, task orchestration, and Cortex Code for AI-assisted SQL development.

### Clean Up (Optional)

To remove all lab objects from your account:

```sql
USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```

### Resources

[Snowflake Scripting](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/index) · [Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro) · [Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui) · [Cloning](https://docs.snowflake.com/en/user-guide/object-clone) · [Cortex Code](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code) · [PRA LCR Rulebook](https://www.bankofengland.co.uk/prudential-regulation/rulebook/made-rules/liquidity) · [Basel III LCR (BIS)](https://www.bis.org/publ/bcbs238.htm)
