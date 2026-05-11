# Step 8: Accelerating Development with Cortex Code

**Estimated time: 15 minutes**

Cortex Code is Snowflake's AI-powered coding assistant. In this step you will use it to accelerate SQL development by describing what you want in natural language and letting Cortex Code generate the SQL.

## Exercise 1: Explore the Data Model

Ask Cortex Code to help you understand the tables you have built:

> "Describe the tables in the NORTHBRIDGE_BANK_HOL database across the RAW, STAGING and REPORTING schemas. Summarise what each table contains and how they relate to each other."

Verify the response against what you know from the previous steps.

## Exercise 2: Write an Analytical Query

Ask Cortex Code to generate a query you have not written yet:

> "Write a SQL query against NORTHBRIDGE_BANK_HOL that shows the top 10 customers by total transaction volume (sum of amount_gbp) in the last 90 days, including their name, segment, risk rating and total number of transactions. Use the staging views."

Run the generated SQL and verify it returns sensible results:

```sql
SELECT
    c.customer_id,
    c.full_name,
    c.segment,
    c.risk_rating,
    COUNT(t.transaction_id)             AS txn_count,
    ROUND(SUM(t.amount_gbp), 2)        AS total_volume_gbp
FROM STAGING.STG_CUSTOMERS_V        c
JOIN STAGING.STG_ACCOUNTS_V         a ON c.customer_id = a.customer_id
JOIN STAGING.STG_TRANSACTIONS_V     t ON a.account_id  = t.account_id
WHERE t.transaction_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY c.customer_id, c.full_name, c.segment, c.risk_rating
ORDER BY total_volume_gbp DESC
LIMIT 10;
```

## Exercise 3: Generate a Regulatory Summary

Ask Cortex Code to create a combined regulatory dashboard query:

> "Write a SQL query that produces a single-row regulatory summary for NORTHBRIDGE_BANK_HOL showing: LCR ratio and status, Tier 1 capital ratio and status, total number of large exposure breaches, and total number of large exposure warnings. Pull from the REPORTING views."

Expected output structure:

```sql
SELECT
    lcr.lcr_ratio_pct,
    lcr.lcr_status,
    car.tier1_ratio_pct,
    car.tier1_status,
    SUM(CASE WHEN le.large_exposure_flag = 'BREACH'  THEN 1 ELSE 0 END) AS breach_count,
    SUM(CASE WHEN le.large_exposure_flag = 'WARNING' THEN 1 ELSE 0 END) AS warning_count
FROM REPORTING.V_LCR_COMPONENTS     lcr
CROSS JOIN REPORTING.V_CAPITAL_ADEQUACY car
CROSS JOIN REPORTING.V_LARGE_EXPOSURES  le
GROUP BY lcr.lcr_ratio_pct, lcr.lcr_status, car.tier1_ratio_pct, car.tier1_status;
```

## Exercise 4: Debug and Optimise

Ask Cortex Code to help you understand query performance:

> "Look at the query profile for the V_LCR_COMPONENTS view and suggest ways to optimise it. Are there any joins or CTEs that could be simplified?"

This exercise demonstrates how Cortex Code can act as a pair-programming partner for performance tuning.

## Summary

Cortex Code can help you:

- Explore and understand unfamiliar schemas
- Generate analytical and reporting queries from natural language
- Debug SQL errors and suggest fixes
- Optimise query performance
- Write stored procedures and DDL from descriptions
