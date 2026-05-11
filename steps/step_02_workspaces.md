# Step 2: Using Workspaces for Code Development

**Estimated time: 15 minutes**

Snowsight Worksheets are your primary workspace for writing, running and organising SQL in Snowflake. This step covers essential workflow features.

## Creating a New Worksheet

1. Click the **+** button at the top of the left navigation panel
2. Select **SQL Worksheet**
3. A new untitled worksheet opens — give it a meaningful name by clicking the title

## Organising with Folders

- Click the **...** menu next to Worksheets and select **New Folder**
- Drag worksheets into folders to group by project (e.g. "NorthBridge HOL")
- Folders help keep your workspace tidy as your project grows

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

## Keyboard Shortcuts

| Action | Mac | Windows/Linux |
|---|---|---|
| Run all / selection | Cmd + Enter | Ctrl + Enter |
| Run single statement | Cmd + Shift + Enter | Ctrl + Shift + Enter |
| Format SQL | Cmd + Shift + F | Ctrl + Shift + F |
| Comment / Uncomment | Cmd + / | Ctrl + / |
| Find & Replace | Cmd + H | Ctrl + H |
| Toggle sidebar | Cmd + B | Ctrl + B |

## Results Panel

After running a query, the results panel shows:

- **Results tab** — the query output as a table with sorting, filtering and download options
- **Chart tab** — click to visualise query results as bar, line, scatter or heatmap charts
- **Query Profile** — a detailed execution plan showing operators, partitions scanned and bytes spilled

## Multi-Statement Worksheets

You can place multiple SQL statements in a single worksheet separated by semicolons. Use `USE DATABASE`, `USE SCHEMA` and `USE WAREHOUSE` statements at the top to set your context, then run the rest of the script.

## Summary

You now know how to create worksheets, organise them in folders, set context, run queries and inspect results. In the next step you will create the database, schemas and tables for the NorthBridge Bank pipeline.
