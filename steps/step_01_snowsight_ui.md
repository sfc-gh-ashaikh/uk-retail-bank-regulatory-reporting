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

## Top Bar Context Controls

Every worksheet shows your current **Role**, **Warehouse** and **Database/Schema**. Changing your role changes what objects are visible — this is Snowflake's role-based access control (RBAC) in action.

In the top-right of any worksheet you will see two dropdowns:

1. **Role** — the active role determines what objects you can see and what operations you can perform
2. **Warehouse** — the compute resource that executes your queries

Always confirm these are set correctly before running SQL.

## Your First Query

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

## Key Areas to Explore Now

### Query History

Navigate to **Monitoring > Query History** — every SQL statement executed in your account, with status, duration and full SQL text. Invaluable for debugging and regulatory audit trails. Here you can:

- Search and filter past queries by user, warehouse, status or time range
- Click any query to see its full SQL, execution profile and statistics
- Identify slow-running queries and review their query plans

### Data Explorer

Navigate to **Data** — expand databases to browse schemas, tables and views. Click any table to see column types, data preview and statistics.

- **Database > Schema > Tables / Views / Stages / File Formats**
- Click any table to see its columns, data types and preview data
- Use the search bar to quickly find objects across all databases

### Task History

Navigate to **Monitoring > Task History** — where you will monitor your automated pipeline in Step 7.

## Summary

You now know how to navigate Snowsight, set your session context, run queries and explore objects. In the next step you will learn how to use Worksheets as a development workspace.
