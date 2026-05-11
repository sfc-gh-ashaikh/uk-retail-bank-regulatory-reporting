# Step 4: Loading Reference Data from a CSV File

**Estimated time: 20 minutes**

This step loads the PRA LCR run-off rate reference file (`lcr_runoff_rates.csv`) into the RAW schema. You can use either the Snowsight UI wizard or the SQL path below.

Not all data can be generated in SQL. Reference data — like regulatory rate tables published by the PRA — arrives as files. This step shows two ways to load a CSV file into Snowflake.

The PRA has published updated **LCR run-off rates** for the new regulatory year. Your team has received `lcr_runoff_rates.csv` and needs to load it into Snowflake. [Download lcr_runoff_rates.csv](assets/lcr_runoff_rates.csv) to your local machine.

Under Basel III, each liability category is multiplied by a prescribed **run-off rate** — the assumed withdrawal percentage under a 30-day stress scenario (e.g. Retail Stable deposits at 5%, Wholesale Financial Institutions at 100%). We store these in a reference table rather than hard-coding them — making updates easy when the PRA revises rates.


## Path A: Snowsight Load Data Wizard (UI)

1. In the left nav, click **Data**
2. Navigate to **NORTHBRIDGE_BANK_HOL > RAW**
3. Click **+ Create** (top right) > **Table from file**
4. Upload `lcr_runoff_rates.csv`
5. Set the table name to `LCR_RUNOFF_RATES`
6. Review column mapping — Snowsight auto-detects types
7. Click **Load**

Alternatively, run the table creation SQL from Path B (Step 4A) first, then click on **Stages > NORTHBRIDGE_REF_STAGE** (create it via Step 4B SQL first), click the **+ Files** button in the top right, select `lcr_runoff_rates.csv` from your `assets/` folder, click **Upload**, and then run the COPY INTO statement from Path B (Step 4E) to load the data.

## Path B: SQL Path (Stages + COPY INTO)

Open your `03_FILE_LOAD` worksheet and run `scripts/03_file_load.sql` section by section.

This approach shows the underlying mechanics — stages, file formats and COPY INTO:

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Step 4 - Loading Reference Data from a CSV File
--
-- This script demonstrates the SQL path for loading the PRA LCR run-off
-- rate reference file into Snowflake using:
--   1. An internal named stage
--   2. A CSV file format
--   3. COPY INTO
--
-- The Snowsight Load Data wizard (UI path) is described in the guide.
-- Use this SQL path to understand the underlying mechanics.
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE SCHEMA RAW;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- STEP 4A: Create the target table for LCR run-off rates
-- =============================================================================
CREATE TABLE IF NOT EXISTS RAW.LCR_RUNOFF_RATES (
    rate_id                 NUMBER AUTOINCREMENT PRIMARY KEY,
    liability_category      VARCHAR(60)     NOT NULL,
    sub_category            VARCHAR(60)     NOT NULL,
    run_off_rate_pct        NUMBER(6,2)     NOT NULL,
    inflow_rate_pct         NUMBER(6,2),
    effective_date          DATE            NOT NULL,
    regulatory_basis        VARCHAR(100)    NOT NULL,
    notes                   VARCHAR(500),
    loaded_at               TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    loaded_by               VARCHAR(100)    DEFAULT CURRENT_USER()
);

-- =============================================================================
-- STEP 4B: Create an internal named stage
--
-- A stage is Snowflake's staging area — a landing zone where files are held
-- before being loaded into tables. An internal stage stores files within
-- your Snowflake account (no external cloud storage required).
-- =============================================================================
CREATE STAGE IF NOT EXISTS RAW.NORTHBRIDGE_REF_STAGE
    COMMENT = 'Internal stage for NorthBridge Bank reference data files';

-- =============================================================================
-- STEP 4C: Create a CSV file format
--
-- A file format tells Snowflake how to parse the uploaded file:
--   - What delimiter separates columns (comma)
--   - Whether there is a header row to skip
--   - How NULLs are represented in the file
--   - How to handle quoted strings
-- =============================================================================
CREATE FILE FORMAT IF NOT EXISTS RAW.CSV_HEADER_FORMAT
    TYPE                = 'CSV'
    FIELD_DELIMITER     = ','
    RECORD_DELIMITER    = '\n'
    SKIP_HEADER         = 1
    NULL_IF             = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE          = TRUE
    COMMENT             = 'Standard CSV format with header row — used for reference data files';

-- =============================================================================
-- STEP 4D: Upload the file via Snowsight (UI Path)
--
-- In Snowsight:
--   1. Click on the stage: NORTHBRIDGE_BANK_HOL > RAW > Stages > NORTHBRIDGE_REF_STAGE
--   2. Click the "+ Files" button in the top right
--   3. Select lcr_runoff_rates.csv from your assets folder
--   4. Click "Upload"
--
-- Alternatively, if using SnowSQL CLI:
--   PUT file:///path/to/lcr_runoff_rates.csv @RAW.NORTHBRIDGE_REF_STAGE;
--
-- You can verify the file is staged with:
-- =============================================================================
LIST @RAW.NORTHBRIDGE_REF_STAGE;

-- =============================================================================
-- STEP 4E: COPY INTO — load staged file into the table
--
-- COPY INTO reads the file(s) from the stage and loads them into the table
-- using the file format definition. ON_ERROR = 'ABORT_STATEMENT' means the
-- entire load is rolled back if any row fails to parse.
-- =============================================================================
COPY INTO RAW.LCR_RUNOFF_RATES (
    liability_category,
    sub_category,
    run_off_rate_pct,
    inflow_rate_pct,
    effective_date,
    regulatory_basis,
    notes
)
FROM @RAW.NORTHBRIDGE_REF_STAGE/lcr_runoff_rates.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW.CSV_HEADER_FORMAT')
ON_ERROR    = 'ABORT_STATEMENT';

-- =============================================================================
-- STEP 4F: Verify the loaded data
-- =============================================================================
SELECT
    liability_category,
    sub_category,
    run_off_rate_pct,
    effective_date,
    regulatory_basis
FROM RAW.LCR_RUNOFF_RATES
ORDER BY liability_category, sub_category;

-- How many rows loaded?
SELECT COUNT(*) AS rows_loaded FROM RAW.LCR_RUNOFF_RATES;

-- Check load history for this table
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME   => 'LCR_RUNOFF_RATES',
    START_TIME   => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
));

-- =============================================================================
-- STEP 4G: Reload scenario — truncate and reload when PRA updates rates
--
-- The PRA may issue updated run-off rates quarterly. The correct pattern
-- is to truncate the reference table and reload from the new file version:
-- =============================================================================

-- TRUNCATE TABLE RAW.LCR_RUNOFF_RATES;
-- Then re-upload the new version of lcr_runoff_rates.csv to the stage
-- Then run the COPY INTO statement above again
```

## Key Concepts

- **Stage** — a landing zone inside your Snowflake account where files are held before loading
- **File Format** — tells Snowflake how to parse the file (delimiter, header row, null handling)
- **COPY INTO** — the bulk loading command that reads from a stage into a table
- **ON_ERROR** — controls whether to abort or skip on row-level parsing errors

> **Note**: To upload the file to the stage via SQL (SnowSQL CLI): `PUT file:///path/to/lcr_runoff_rates.csv @RAW.NORTHBRIDGE_REF_STAGE;`
> For this lab, use the Snowsight stage UI to upload the file (click the stage object in Data browser > Upload button).

## Verify and Reload

You should see **25 rows**. When the PRA publishes revised rates, simply `TRUNCATE TABLE RAW.LCR_RUNOFF_RATES`, re-upload the new CSV to the stage, and re-run `COPY INTO`.
