# Step 1: Getting Familiar with the Snowsight UI

**Estimated time: 15 minutes**

Snowsight is Snowflake's web-based interface for querying data, managing objects and monitoring activity. Before writing any SQL, take a few minutes to orient yourself.

## Left Navigation

- **Worksheets** — where you write and run SQL queries
- **Dashboards** — build visual dashboards from query results
- **Data** — browse databases, schemas, tables and views (the Data Explorer)
- **Marketplace** — discover and access shared data sets
- **Activity** — view Query History, Copy History, Task History and more
- **Admin** — manage warehouses, resource monitors, users and roles

## Context Controls

In the top-right of any worksheet you will see two dropdowns:

1. **Role** — the active role determines what objects you can see and what operations you can perform
2. **Warehouse** — the compute resource that executes your queries

Always confirm these are set correctly before running SQL.

## Your First Query

Open a new worksheet and run the following to verify your session context:

```sql
SELECT
    CURRENT_USER()      AS my_user,
    CURRENT_ROLE()      AS my_role,
    CURRENT_WAREHOUSE() AS my_warehouse,
    CURRENT_DATABASE()  AS my_database,
    CURRENT_TIMESTAMP() AS current_time;
```

You should see your username, active role, warehouse, database and the current timestamp.

## Query History

Navigate to **Activity > Query History** in the left nav. Here you can:

- Search and filter past queries by user, warehouse, status or time range
- Click any query to see its full SQL, execution profile and statistics
- Identify slow-running queries and review their query plans

## Data Explorer

Navigate to **Data > Databases** to browse the object hierarchy:

- **Database > Schema > Tables / Views / Stages / File Formats**
- Click any table to see its columns, data types and preview data
- Use the search bar to quickly find objects across all databases

## Task History

Navigate to **Activity > Task History** to monitor scheduled task runs. You will use this in Step 7 when building the automated pipeline.

## Summary

You now know how to navigate Snowsight, set your session context, run queries and explore objects. In the next step you will learn how to use Worksheets as a development workspace.
