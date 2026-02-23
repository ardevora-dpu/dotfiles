# Snowflake Unused Tables Detection

Queries to find tables/views not accessed in production. Requires ACCOUNTADMIN or grants on ACCOUNT_USAGE.

**Note:** ACCESS_HISTORY is an **Enterprise Edition** feature. Standard Edition users should use the QUERY_HISTORY approach below.

---

## Enterprise Edition (ACCESS_HISTORY)

```sql
-- Tables not accessed in 90 days
-- Uses base_objects_accessed to catch indirect access through views
WITH accessed_tables AS (
  SELECT DISTINCT
    f.value:objectName::STRING AS fully_qualified_name
  FROM snowflake.account_usage.access_history ah,
  LATERAL FLATTEN(base_objects_accessed) f
  WHERE ah.query_start_time > DATEADD('day', -90, CURRENT_TIMESTAMP())
    AND f.value:objectDomain IN ('Table', 'View')
)
SELECT
  t.table_catalog AS database,
  t.table_schema AS schema,
  t.table_name,
  t.table_type,
  t.row_count,
  t.bytes / (1024*1024*1024) AS size_gb,
  t.last_altered
FROM snowflake.account_usage.tables t
LEFT JOIN accessed_tables at
  ON at.fully_qualified_name = t.table_catalog || '.' || t.table_schema || '.' || t.table_name
WHERE at.fully_qualified_name IS NULL
  AND t.deleted IS NULL
  AND t.table_catalog = 'QUINLAN'
  AND t.table_schema NOT IN ('INFORMATION_SCHEMA')
  AND t.table_schema NOT LIKE '_DBT%'  -- Exclude dbt ephemeral/temp schemas
ORDER BY t.bytes DESC NULLS LAST;
```

**Key distinction:** Use `base_objects_accessed` (not `direct_objects_accessed`) to capture indirect access through views.

---

## Standard Edition (QUERY_HISTORY tokenisation)

If you don't have Enterprise Edition, compare table names against tokenised query text:

```sql
-- Less accurate: may have false positives from table names in comments
WITH queried_tables AS (
  SELECT DISTINCT
    REGEXP_SUBSTR(query_text, 'FROM\\s+([A-Z0-9_\\.]+)', 1, 1, 'i', 1) AS table_ref
  FROM snowflake.account_usage.query_history
  WHERE start_time > DATEADD('day', -90, CURRENT_TIMESTAMP())
    AND query_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'MERGE')
)
SELECT t.table_name
FROM snowflake.account_usage.tables t
WHERE t.table_catalog = 'QUINLAN'
  AND t.deleted IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM queried_tables qt
    WHERE qt.table_ref ILIKE '%' || t.table_name || '%'
  );
```

**Limitations:**
- False positives from table names appearing in comments
- Misses indirect references through views
- Regex may not catch all query patterns

---

## dbt Model Correlation

Combine with dbt manifest to identify unused models:

```sql
-- After running dbt docs generate, load manifest.json and compare
-- Models in manifest but not in accessed_tables are candidates for removal
```

Use `dbt_snowflake_monitoring` package for automated correlation:
- https://github.com/get-select/dbt-snowflake-monitoring

---

## Safe Removal Workflow

1. **Identify candidates** — Run the queries above
2. **Cross-reference dbt** — Check if model is in manifest
3. **Check dependencies** — `dbt ls --select +model_name+`
4. **Add deprecation_date** — See `dbt-deprecation.md`
5. **Monitor for 30 days** — Confirm no access
6. **Drop** — `DROP TABLE IF EXISTS schema.table_name;`

---

## Notes

- `ACCOUNT_USAGE` views have 45-minute latency
- `QUERY_HISTORY` retains 14 days by default; `ACCOUNT_USAGE` retains 1 year
- Access history queries can be expensive — materialise incrementally
