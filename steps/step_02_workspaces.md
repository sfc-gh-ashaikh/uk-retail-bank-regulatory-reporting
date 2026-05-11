# Step 2: Using Workspaces for Code Development

**Estimated time: 15 minutes**

Snowsight Worksheets are your primary workspace for writing, running and organising SQL in Snowflake. This step covers essential workflow features.

## Creating a New Worksheet

Click **Worksheets** in the left nav, click **+** (top right), and rename it to `NORTHBRIDGE_HOL_SETUP`. Good names describe what the code does — not who wrote it or when.

1. Click the **+** button at the top of the left navigation panel
2. Select **SQL Worksheet**
3. A new untitled worksheet opens — give it a meaningful name by clicking the title

## Organising with Folders

Click the **+** folder icon, create a folder called **NorthBridge HOL**, and drag your worksheet into it. For this lab, create one worksheet per step:

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

## Context Bar

At the top of each worksheet you will see:

- **Role selector** — switch roles without leaving the worksheet
- **Warehouse selector** — choose compute for this worksheet
- **Database / Schema selector** — set the default namespace for unqualified object references

Setting the correct context avoids fully qualifying every table name in your SQL.

## Running Queries

- **Run all** — click the blue **Run** button (or press the keyboard shortcut) to execute the entire worksheet
- **Run selection** — highlight specific SQL statements and run only those
- **Run single statement** — place your cursor within a statement and use the shortcut to run just that one

## Keyboard Shortcuts and Tips

| Action | Mac | Windows |
|---|---|---|
| Run selected statement | `Cmd + Enter` | `Ctrl + Enter` |
| Run all statements | `Cmd + Shift + Enter` | `Ctrl + Shift + Enter` |
| Comment/uncomment selection | `Cmd + /` | `Ctrl + /` |
| Format SQL | `Cmd + Shift + F` | `Ctrl + Shift + F` |
| Find & Replace | `Cmd + H` | `Ctrl + H` |
| Toggle sidebar | `Cmd + B` | `Ctrl + B` |

> **Tip**: Highlight a single statement and press `Cmd/Ctrl + Enter` to run only that statement. This prevents accidentally running an entire file.

## Results Panel

After running a query, the results panel at the bottom lets you download results as CSV, switch to Chart view, or copy cells/rows.

- **Results tab** — the query output as a table with sorting, filtering and download options
- **Chart tab** — click to visualise query results as bar, line, scatter or heatmap charts
- **Query Profile** — a detailed execution plan showing operators, partitions scanned and bytes spilled

## Multi-Statement Worksheets

You can place multiple SQL statements in a single worksheet separated by semicolons. Use `USE DATABASE`, `USE SCHEMA` and `USE WAREHOUSE` statements at the top to set your context, then run the rest of the script.

## Summary

You now know how to create worksheets, organise them in folders, set context, run queries and inspect results. Create the remaining worksheets for the lab before proceeding to Step 3.
