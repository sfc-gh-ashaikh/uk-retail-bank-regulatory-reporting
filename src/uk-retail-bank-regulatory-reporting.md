author: NorthBridge Bank HOL Team
id: uk-retail-bank-regulatory-reporting
summary: Build a FCA/PRA regulatory reporting data pipeline on Snowflake for a UK retail bank. Covers Snowsight UI navigation, workspaces, databases/schemas/roles, file loading, staging, LCR/CAR/large exposures reporting, stored procedures, task orchestration, and Cortex Copilot.
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
- How to use Cortex Copilot to accelerate SQL development

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

### The Snowsight Interface

Snowsight is Snowflake's browser-based interface. Everything you need to build, run and monitor your pipeline lives here. Let's get oriented before writing any code.

Log in to your Snowflake account. You will land on the Snowsight home page.

### Left Navigation Panel

The left sidebar is your primary navigation. Each icon takes you to a different area:

| Icon / Label | What It Does |
|---|---|
| **Home** | Activity summary and recent objects |
| **Data** | Browse databases, schemas and tables. Load data, view column profiles |
| **Worksheets** | SQL and Python development environment |
| **Notebooks** | Interactive notebook-style development |
| **Monitoring** | Query History, Task History, Copy History, Activity |
| **Admin** | Warehouses, resource monitors, users, roles |

### Top Bar — Context Controls

The top bar of every worksheet shows your current execution context:

- **Role** — controls what objects you can see and what operations you can perform
- **Warehouse** — the compute cluster that executes your queries
- **Database / Schema** — the default namespace for unqualified object references

> **Key Point**: Changing your role changes what is visible in the object browser on the left. A data engineer's role may not see the same databases as a reporting analyst's role. This is Snowflake's role-based access control (RBAC) in action.

### Query History

Click **Monitoring > Query History** in the left nav. This shows every SQL statement executed in your account, with:

- Execution status (Succeeded / Failed / Queued)
- Duration and bytes scanned
- The warehouse used
- The full SQL text (click any row)

This is invaluable for debugging and auditing — especially important in a regulated bank environment where every query may need to be evidenced.

### Data Explorer

Click **Data** in the left nav. Expand your account's databases to browse schemas, tables and views. Click any table to see:

- Column names and data types
- A **Data Preview** tab showing sample rows
- A **Column** tab showing min/max/null statistics

### Task History

Click **Monitoring > Task History**. This is where you will monitor your automated pipeline in Step 7. You can see each task run, its duration, dependencies and any error messages.

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

### Creating and Naming a Worksheet

1. Click **Worksheets** in the left nav
2. Click **+** (top right) to create a new worksheet
3. Click the worksheet name (defaults to the current date/time) and rename it to:
   ```
   NORTHBRIDGE_HOL_SETUP
   ```

Good worksheet names describe what the code does — not who wrote it or when.

### Organising Worksheets into Folders

As a project grows, a flat list of worksheets becomes hard to navigate. Folders keep related worksheets together.

1. In the Worksheets panel, click the **+** folder icon or right-click in the left panel
2. Create a new folder called **NorthBridge HOL**
3. Drag your worksheet into that folder

For this lab, you will create one worksheet per step:

| Worksheet Name | Step |
|---|---|
| `01_SETUP` | Step 3: Environment Setup |
| `02_DATA_GENERATION` | Step 3: Data Loading |
| `03_FILE_LOAD` | Step 4: CSV Reference Data |
| `04_STAGING` | Step 5: Staging Layer |
| `05_REPORTING` | Step 6: Reporting Layer |
| `06_PROCEDURES` | Step 7: Stored Procedures |
| `07_TASKS` | Step 7: Task Orchestration |
| `08_COPILOT` | Step 8: Cortex Copilot |

### Running Code Efficiently

| Action | Mac | Windows |
|---|---|---|
| Run selected statement | `Cmd + Enter` | `Ctrl + Enter` |
| Run all statements | `Cmd + Shift + Enter` | `Ctrl + Shift + Enter` |
| Comment/uncomment selection | `Cmd + /` | `Ctrl + /` |
| Format SQL | `Cmd + Shift + F` | `Ctrl + Shift + F` |
| Open keyboard shortcut reference | `?` icon top right | `?` icon top right |

> **Tip**: Highlight a single statement and press `Cmd/Ctrl + Enter` to run only that statement. This is the most important habit to develop — it prevents accidentally running an entire file when you only want to test one query.

### The Worksheet Context Bar

At the top of every worksheet is a context bar showing:

```
Role: SYSADMIN  |  Warehouse: NORTHBRIDGE_WH  |  Database: NORTHBRIDGE_BANK_HOL  |  Schema: RAW
```

Setting this context means you can write `SELECT * FROM CUSTOMERS` instead of the fully qualified `SELECT * FROM NORTHBRIDGE_BANK_HOL.RAW.CUSTOMERS`. For this lab, always verify your context before running a script.

### Results Panel

After running a query, the results panel appears at the bottom of the worksheet. You can:

- **Download** results as CSV (cloud icon)
- **Switch to Chart view** to quickly visualise query output
- **Copy** individual cells or entire rows

Create the remaining worksheet folders and worksheets for the lab before proceeding to Step 3.

<!-- ------------------------ -->
## Step 3: Understanding Databases, Schemas and Roles
Duration: 25

In this step you will create the NorthBridge Bank environment and load the synthetic dataset.

### Snowflake Object Hierarchy

Every object in Snowflake exists within a hierarchy:

```
Organisation
    └── Account (your Snowflake account)
            └── Database  (e.g. NORTHBRIDGE_BANK_HOL)
                    └── Schema  (e.g. RAW, STAGING, REPORTING)
                            └── Tables, Views, Procedures, Stages...
```

When you write SQL without fully qualifying names, Snowflake uses your current **database** and **schema** context to resolve the reference.

### Why Three Schemas?

NorthBridge Bank uses a three-layer architecture — a standard pattern in regulated data environments:

| Schema | Purpose | Who Writes | Who Reads |
|---|---|---|---|
| **RAW** | Immutable ingest zone. Data lands here exactly as received from source systems. Never modified after load. | Ingest pipelines | Data engineers |
| **STAGING** | Cleansed, standardised, enriched data. PII is masked, data types are enforced. | Data engineers | Analytics engineers |
| **REPORTING** | Business-facing regulatory views and daily snapshots. | Analytics engineers | Risk & Compliance, regulators |

This separation means a bug in the reporting layer can never corrupt the raw source data.

### Open your `01_SETUP` worksheet

Copy and run the contents of `assets/01_setup.sql`.

This creates:
- The `NORTHBRIDGE_BANK_HOL` database
- Three schemas: `RAW`, `STAGING`, `REPORTING`
- The `NORTHBRIDGE_WH` warehouse (X-Small, auto-suspend after 60 seconds)
- The `STAGING.AUDIT_LOG` table used by stored procedures later

After running, verify in the left **Data** panel that the database and schemas are visible.

### Role-Based Access in Practice

Click the role selector in the top bar. Toggle between `SYSADMIN` and `PUBLIC`.

> **Observe**: As `PUBLIC`, the database browser may show fewer objects or none at all. This is RBAC — different roles see different objects. In a real bank, the ingest team would use a dedicated `INGEST_ROLE`, analysts would use an `ANALYST_ROLE`, and the compliance team would have read-only access to `REPORTING`.

Switch back to `SYSADMIN` before continuing.

### Load the Synthetic Dataset

Open your `02_DATA_GENERATION` worksheet and run `assets/02_data_generation.sql`.

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

### Explore the Data

Click on **Data > NORTHBRIDGE_BANK_HOL > RAW > CUSTOMERS** in the left panel. Click the **Data Preview** tab to see sample rows.

Notice the UK-specific data:
- `NI_NUMBER` — UK National Insurance number format (`XX 00 00 00 X`)
- `POSTCODE` — UK postcode format (e.g. `EC1A 1BB`)
- `SORT_CODE` — UK bank sort code format (`20-XX-XX`) in the ACCOUNTS table
- All monetary amounts are in GBP

<!-- ------------------------ -->
## Step 4: Loading Reference Data from a CSV File
Duration: 20

Not all data can be generated in SQL. Reference data — like regulatory rate tables published by the PRA — arrives as files. This step shows two ways to load a CSV file into Snowflake.

### The Scenario

The PRA has published updated **LCR run-off rates** for the new regulatory year. Your team has received the file `lcr_runoff_rates.csv` and needs to load it into Snowflake before the next reporting run.

Download `assets/lcr_runoff_rates.csv` from this repository to your local machine.

### What Are Run-Off Rates?

Under Basel III, the LCR calculation requires each liability category (e.g. retail deposits, wholesale funding) to be multiplied by a prescribed **run-off rate** — the assumed percentage of funds that would be withdrawn under a 30-day stress scenario.

| Liability Category | Sub-Category | Run-Off Rate |
|---|---|---|
| RETAIL_DEPOSIT | STABLE | 5% |
| RETAIL_DEPOSIT | LESS_STABLE | 10% |
| WHOLESALE_NON_OPERATIONAL | FINANCIAL_INSTITUTION | 100% |
| SECURED_FUNDING | HQLA_LEVEL1 | 0% |

Rather than hard-coding these rates in SQL, we store them in a reference table — making it easy to update when the PRA revises the rates.

### Path A — Snowsight Load Data Wizard (UI)

1. In the left nav, click **Data**
2. Navigate to **NORTHBRIDGE_BANK_HOL > RAW**
3. Click **+ Create** (top right) > **Table from file**
4. Upload `lcr_runoff_rates.csv`
5. Set the table name to `LCR_RUNOFF_RATES`
6. Review column mapping — Snowsight auto-detects types
7. Click **Load**

### Path B — SQL (Stages + COPY INTO)

Open your `03_FILE_LOAD` worksheet and run `assets/03_file_load.sql` section by section.

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

### Verify the Load

```sql
SELECT
    liability_category,
    sub_category,
    run_off_rate_pct,
    regulatory_basis
FROM RAW.LCR_RUNOFF_RATES
ORDER BY liability_category, sub_category;

SELECT COUNT(*) AS rows_loaded FROM RAW.LCR_RUNOFF_RATES;
```

You should see 25 rows covering all Basel III standardised run-off categories.

### Reload Pattern

When the PRA publishes revised rates:
```sql
TRUNCATE TABLE RAW.LCR_RUNOFF_RATES;
-- Re-upload new version of lcr_runoff_rates.csv to stage
-- Then re-run the COPY INTO statement
```

This pattern ensures the table always reflects the current regulatory rates without needing to delete individual rows.

<!-- ------------------------ -->
## Step 5: Core Data Engineering — Tables, Views and Staging
Duration: 30

In this step you will build the **STAGING layer**: cleansed, standardised and enriched data that the reporting layer will read from.

Open your `04_STAGING` worksheet and work through `assets/04_staging_pipeline.sql`.

### Part A: Creating Staging Tables

Staging tables provide physical snapshots of cleansed data. They are populated by stored procedures (Step 7) and provide a stable, performant foundation for downstream reporting.

Run Part A of the script to create the four staging tables. Observe the DDL patterns:

```sql
CREATE OR REPLACE TABLE STAGING.STG_CUSTOMERS (
    customer_id         NUMBER          NOT NULL,
    first_name          VARCHAR(50)     NOT NULL,
    ...
    ni_number_masked    VARCHAR(13)     NOT NULL,
    ...
    stg_loaded_at       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);
```

Key DDL conventions used throughout:
- **Explicit data types**: `NUMBER`, `VARCHAR(n)`, `DATE`, `TIMESTAMP_NTZ`
- **NOT NULL constraints**: applied to mandatory fields
- **DEFAULT values**: `CURRENT_TIMESTAMP()` stamps when each row was loaded
- `TIMESTAMP_NTZ`: timezone-naive timestamps — used in banking to avoid DST ambiguity in audit trails

### Part B: Creating Cleansing Views

Views are virtual tables — they store the query definition but not the data. Every time you query a view, it reads the latest data from the underlying tables.

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

### Tables vs Views — When to Use Each

| | Table | View |
|---|---|---|
| **Storage** | Stores data physically | Stores only the query definition |
| **Performance** | Fast reads (no re-computation) | Re-executes query on every access |
| **Freshness** | Snapshot at load time | Always current |
| **Use when** | Downstream consumers need stable, fast reads | Data must always reflect latest source |

For this pipeline: views feed the reporting layer at query time; staging tables are physical snapshots populated once per day by the task pipeline.

### Part C: Zero-Copy Cloning

Run Part C to clone the transactions table:

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

### Validate Your Work

Run the validation queries at the bottom of `04_staging_pipeline.sql` to confirm your views return clean, enriched data.

<!-- ------------------------ -->
## Step 6: Building the Regulatory Reporting Layer
Duration: 25

In this step you will create the three FCA/PRA regulatory reporting views in the `REPORTING` schema.

Open your `05_REPORTING` worksheet and work through `assets/05_reporting_layer.sql`.

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
LEFT JOIN RAW.LCR_RUNOFF_RATES r
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

The `V_CAPITAL_ADEQUACY` view aggregates risk-weighted assets from the loan book:

```sql
ROUND(l.outstanding_balance_gbp * (l.risk_weight_pct / 100), 2) AS risk_weighted_assets_gbp
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

Open your `06_PROCEDURES` worksheet and work through `assets/06_stored_procedures.sql`.

#### SP_REFRESH_STAGING

This procedure truncates and reloads all staging tables from the RAW layer. It uses **Snowflake Scripting** — a SQL-native procedural language that supports variables, control flow and exception handling.

Key structural elements:

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

Key language features used:
- `DECLARE` — variable declarations with default values
- `SQLROWCOUNT` — built-in variable returning rows affected by the last DML
- `BEGIN ... EXCEPTION WHEN OTHER THEN ... END` — inner exception blocks that handle errors per table without aborting the whole procedure
- `SQLERRM` — the error message from the most recent exception

#### SP_REFRESH_REPORTING

This procedure creates daily snapshot tables (`SNAP_LCR_COMPONENTS`, `SNAP_CAPITAL_ADEQUACY`, `SNAP_LARGE_EXPOSURES`) and inserts today's regulatory report data with a `snapshot_date` column. Each day's data is preserved — giving a full audit trail of regulatory positions.

#### Test the Procedures

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

Open your `07_TASKS` worksheet and work through `assets/07_tasks.sql`.

#### The Task DAG

A **task** is a Snowflake object that executes a SQL statement or stored procedure call, either on a schedule or when a predecessor task completes. A collection of tasks linked by dependencies forms a **DAG** (Directed Acyclic Graph).

NorthBridge Bank's pipeline DAG:

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

#### Resume Tasks (Leaf to Root)

Tasks are created in `SUSPENDED` state. Always resume leaf tasks before root tasks:

```sql
ALTER TASK STAGING.TASK_REFRESH_REPORTING RESUME;
ALTER TASK STAGING.TASK_REFRESH_STAGING   RESUME;
ALTER TASK STAGING.TASK_INGEST_COMPLETE   RESUME;
```

> **Why leaf first?** If you resume the root task before the children are active, the root task will complete and try to trigger suspended children — which won't run. Always work bottom-up.

#### Manually Trigger the Pipeline

Rather than waiting for 06:00 UTC, trigger the DAG manually:

```sql
EXECUTE TASK STAGING.TASK_INGEST_COMPLETE;
```

#### Monitor in Snowsight

Navigate to **Monitoring > Task History** in the left nav. You will see:

- Each task run with status (`Succeeded` / `Failed` / `Running`)
- Execution duration for each task
- The DAG run graph — visualising the dependency chain
- Error messages for any failed tasks (click the row to expand)

Give it 30–60 seconds, then refresh the Task History page to see all three tasks complete successfully.

#### Suspend Tasks After the Lab

When you are finished, suspend the tasks to avoid unnecessary compute charges:

```sql
ALTER TASK STAGING.TASK_INGEST_COMPLETE   SUSPEND;
ALTER TASK STAGING.TASK_REFRESH_STAGING   SUSPEND;
ALTER TASK STAGING.TASK_REFRESH_REPORTING SUSPEND;
```

<!-- ------------------------ -->
## Step 8: Accelerating Development with Cortex Copilot
Duration: 15

Cortex Copilot is Snowflake's AI assistant built directly into the Snowsight SQL editor. It helps you generate, explain, and optimise SQL — without ever leaving your worksheet.

Open your `08_COPILOT` worksheet.

> **Data Residency**: Cortex Copilot runs entirely within your Snowflake account. Your SQL and schema metadata never leave your Snowflake environment.

### Accessing Cortex Copilot

Click the **Cortex Copilot** icon (sparkle ✦) in the top-right corner of the worksheet editor. A chat panel opens alongside your worksheet.

Alternatively, type a natural language comment directly in the worksheet — Copilot will suggest completions.

### Exercise 1 — Generate a Query

Type the following comment into your worksheet and invoke Copilot:

```sql
-- Show the top 10 customers by total loan exposure for the large exposures register,
-- including their risk rating and whether they are in breach of the PRA 25% limit
```

Copilot will suggest a SQL query. Review it, then run it. Compare the output with your `V_LARGE_EXPOSURES` view — do the results agree?

> **Best Practice**: Always validate AI-generated SQL against expected results. Copilot is a starting point, not a finished product.

### Exercise 2 — Explain Code

Highlight the entire body of `SP_REFRESH_STAGING` (copy it into your worksheet first).

In the Copilot chat panel, type:
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

Ask Copilot:
```
Rewrite this query to eliminate the correlated subqueries using a JOIN and aggregation instead
```

Run both versions and compare execution plans. The rewritten version should scan fewer rows.

### Exercise 4 — Extend the Pipeline

Type the following comment and let Copilot generate the SQL:

```sql
-- Write a query to identify which LCR run-off rate categories
-- have had no transactions in the last 30 days.
-- This would indicate a potential gap in our run-off rate reference data.
```

This is a real data quality check a data engineer would want to build into the pipeline — Copilot can scaffold it in seconds.

### When to Trust vs Validate

| Copilot is reliable for | Validate carefully when |
|---|---|
| Standard SQL patterns (GROUP BY, JOIN, aggregation) | Complex window function logic |
| Explaining well-structured stored procedures | Regulatory calculations with specific formula requirements |
| Scaffolding repetitive boilerplate | Any query that feeds a compliance submission |
| Suggesting optimisation approaches | Schema-specific column names (Copilot may hallucinate) |

<!-- ------------------------ -->
## Conclusion and What You Learned
Duration: 5

Congratulations — you have built a complete FCA/PRA regulatory reporting pipeline on Snowflake for NorthBridge Bank.

### What You Built

```
RAW Schema                 STAGING Schema              REPORTING Schema
──────────────             ──────────────              ────────────────
CUSTOMERS (10k)  ────────► STG_CUSTOMERS_V  ─────────► V_LARGE_EXPOSURES
ACCOUNTS  (15k)  ────────► STG_ACCOUNTS_V   ─────────► V_LCR_COMPONENTS
TRANSACTIONS(500k)───────► STG_TRANSACTIONS_V ────────► V_LCR_COMPONENTS
LOANS     (3k)   ────────► STG_LOANS_V      ─────────► V_CAPITAL_ADEQUACY
LCR_RUNOFF_RATES ──────────────────────────────────────► V_LCR_COMPONENTS
                                ↕
                          AUDIT_LOG
                                ↕
        Task DAG: TASK_INGEST → SP_REFRESH_STAGING → SP_REFRESH_REPORTING
                  (Scheduled daily at 06:00 UTC)
```

### What You Learned

- **Snowsight UI**: Query History, Data Explorer, Task History monitoring
- **Workspaces**: Organising worksheets into folders, running selections, keyboard shortcuts
- **Databases, Schemas and Roles**: Three-layer architecture, RBAC context switching
- **Tables and Views**: DDL conventions, cleansing views, when to materialise vs keep as a view
- **File-based ingest**: Internal stages, file formats, COPY INTO — plus the Snowsight Load Data wizard
- **Zero-Copy Cloning**: Instant environment creation for dev/UAT
- **Stored Procedures**: Snowflake Scripting with variables, SQLROWCOUNT, exception handling, AUDIT_LOG
- **Task Orchestration**: DAG creation, CRON scheduling, leaf-to-root resume order, Snowsight monitoring
- **Cortex Copilot**: Generate, explain, refactor and extend SQL using AI assistance

### Clean Up (Optional)

To remove all lab objects from your account:

```sql
USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```

### Related Resources

- [Snowflake Scripting Developer Guide](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/index)
- [Introduction to Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Understanding Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui)
- [Cloning Considerations](https://docs.snowflake.com/en/user-guide/object-clone)
- [Cortex Copilot Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [PRA Rulebook — Liquidity (LCR)](https://www.bankofengland.co.uk/prudential-regulation/rulebook/made-rules/liquidity)
- [Basel III LCR Framework](https://www.bis.org/publ/bcbs238.htm)
