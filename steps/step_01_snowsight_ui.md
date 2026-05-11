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

You now know how to navigate Snowsight, set your session context and run a query. In the next step you will set up your worksheet workspace.
