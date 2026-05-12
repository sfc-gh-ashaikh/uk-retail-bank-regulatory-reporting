# Step 8: Accelerating Development with Cortex Code

**Estimated time: 15 minutes**

Cortex Code is Snowflake's AI assistant built directly into the Snowsight SQL editor. It helps you generate, explain, and optimise SQL — without ever leaving your worksheet.

Open your `08_CORTEX_CODE` worksheet.

> **Data Residency**: Cortex Code runs entirely within your Snowflake account. Your SQL and schema metadata never leave your Snowflake environment.

Click the **Cortex Code** icon (✦) in the top-right corner of the worksheet editor, or type a natural language comment directly in the worksheet for inline completions.

## Exercise 1: Generate a Query

Type the following comment into your worksheet and invoke Cortex Code:

```
Show the top 10 customers by total loan exposure for the large exposures register including their risk rating and whether they are in breach of the PRA 25% limit
```

Cortex Code will suggest a SQL query. Review it, then run it. Compare the output with your `V_LARGE_EXPOSURES` view — do the results agree?

> **Best Practice**: Always validate AI-generated SQL against expected results. Cortex Code is a starting point, not a finished product.

You can also ask Cortex Code to help you understand the tables you have built:

> "Describe the tables in the NORTHBRIDGE_BANK_HOL database across the RAW, STAGING and REPORTING schemas. Summarise what each table contains and how they relate to each other."

Verify the response against what you know from the previous steps.

## Exercise 2: Explain Code

Highlight the entire body of `SP_REFRESH_STAGING` (copy it into your worksheet first).

In the Cortex Code chat panel, type:
```
Explain what this stored procedure does and what each section is responsible for
```

Read the explanation. Does it match your understanding from Step 7?

You can also ask Cortex Code to generate a query you have not written yet:

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

## Exercise 3: Refactor SQL

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

You can also ask Cortex Code to create a combined regulatory dashboard query:

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

## Exercise 4: Extend the Pipeline

Type the following comment and let Cortex Code generate the SQL:

```
Write a query to identify which LCR run-off rate categories have had no transactions in the last 30 days. This would indicate a potential gap in our run-off rate reference data.
```

This is a real data quality check a data engineer would want to build into the pipeline — Cortex Code can scaffold it in seconds.

You can also ask Cortex Code to help you understand query performance:

> "Look at the query profile for the V_LCR_COMPONENTS view and suggest ways to optimise it. Are there any joins or CTEs that could be simplified?"

This exercise demonstrates how Cortex Code can act as a pair-programming partner for performance tuning.

## When to Trust vs Validate

| Cortex Code is reliable for | Validate carefully when |
|---|---|
| Standard SQL patterns (GROUP BY, JOIN, aggregation) | Complex window function logic |
| Explaining well-structured stored procedures | Regulatory calculations with specific formula requirements |
| Scaffolding repetitive boilerplate | Any query that feeds a compliance submission |
| Suggesting optimisation approaches | Schema-specific column names (Cortex Code may hallucinate) |

## Summary

Cortex Code can help you:

- Explore and understand unfamiliar schemas
- Generate analytical and reporting queries from natural language
- Debug SQL errors and suggest fixes
- Optimise query performance
- Write stored procedures and DDL from descriptions


