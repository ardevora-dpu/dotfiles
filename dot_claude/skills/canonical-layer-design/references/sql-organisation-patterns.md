# SQL Organisation Patterns for Small Teams

Practical patterns for organising SQL files in Snowflake projects. Designed for 0→1 stage teams who want structure without over-engineering.

> **Update (Dec 2025):** We have adopted **dbt-core** for dependency management.
> See `dbt-patterns.md` for the primary reference. This document remains useful for
> understanding raw SQL patterns and the context before dbt migration.

## 1. File/Folder Structure

### Recommended Layout

```
sql/
  canonical/                    # Layer 1: Truth layer (CANONICAL.*)
    est_sales_ntm_weekly.sql
    peer_benchmark_views.sql

  mart/                         # Layer 2: Serving layer (MART.*)
    regime_screen_latest.sql
    entity_series_weekly.sql

  migrations/                   # Optional: schemachange migrations
    V1.0.0__initial_schema.sql

packages/datasources/backends/
  <vendor>/sql/tables/<domain>/ # Layer 0: Vendor staging (STG_*.*)
    spglobal/sql/tables/prices/prices.sql
    reference/sql/tables/calendar/calendar_weekly.sql

scripts/snowflake/              # Ad-hoc scripts (not deployed)
  setup_pat_policy.sql
```

### Naming Conventions

| Pattern | Example | Use When |
|---------|---------|----------|
| `<object_name>.sql` | `est_sales_ntm_weekly.sql` | 1:1 file-to-object mapping (preferred) |
| `<domain>_<type>.sql` | `peer_benchmark_views.sql` | Multiple related objects |
| `V<version>__<desc>.sql` | `V1.0.1__add_peer_groups.sql` | Migration-based workflow |

**File names should match object names** for discoverability:
- `sql/canonical/est_sales_ntm_weekly.sql` → `QUINLAN.CANONICAL.EST_SALES_NTM_WEEKLY`

### What NOT to Do

- Don't organise by object type (`/views`, `/tables`)—organise by layer
- Don't split single objects across multiple files
- Don't use tags instead of folders
- Don't nest more than 2 levels deep in sql/

---

## 2. Version Control Patterns

### State-Based (Recommended for Small Teams)

Store the **complete object definition** in git. Deploy by running the file.

```sql
-- sql/canonical/est_sales_ntm_weekly.sql
CREATE OR ALTER VIEW QUINLAN.CANONICAL.EST_SALES_NTM_WEEKLY AS
-- entire definition here
;
```

**Advantages:**
- Simple mental model (file = object)
- Easy to review (see entire definition)
- Works with `CREATE OR REPLACE` / `CREATE OR ALTER`
- No migration tooling required

**When to use:** All views, UDFs, small tables, stored procedures.

### Migration-Based (Only When Needed)

Store **incremental changes** with version numbers. Tool tracks which ran.

```sql
-- sql/migrations/V1.0.1__add_currency_column.sql
ALTER TABLE QUINLAN.CANONICAL.MY_TABLE ADD COLUMN currency VARCHAR;
```

**When to use:**
- Large tables where rebuilds are expensive
- Complex data migrations
- Multiple developers making parallel schema changes

**Tools:** schemachange (Snowflake Labs), Flyway, or manual tracking.

### Hybrid Approach (What Most Teams Do)

- **Views**: State-based (CREATE OR ALTER)
- **Tables**: Migration-based (ALTER TABLE, or full refresh if small)
- **Functions/Procedures**: State-based (CREATE OR REPLACE)

---

## 3. Development Workflow

### Local Iteration Loop

```bash
# 1. Create dev clone (instant, zero storage cost)
snow sql -q "CREATE DATABASE quinlan_dev CLONE quinlan;"

# 2. Edit SQL locally
vim sql/canonical/new_view.sql

# 3. Apply to dev
snow sql -f sql/canonical/new_view.sql --database quinlan_dev

# 4. Verify
snow sql -q "SELECT * FROM quinlan_dev.canonical.new_view LIMIT 10;"

# 5. If satisfied, apply to prod
snow sql -f sql/canonical/new_view.sql --database quinlan

# 6. Cleanup dev clone
snow sql -q "DROP DATABASE quinlan_dev;"
```

### Snowflake Git Integration (Alternative)

GA July 2024. Execute SQL directly from your git repo:

```sql
-- Setup (one-time)
CREATE GIT REPOSITORY quinlan_repo ORIGIN = 'https://github.com/...';

-- Development
ALTER GIT REPOSITORY quinlan_repo FETCH;
EXECUTE IMMEDIATE FROM @quinlan_repo/branches/feat/new-view/sql/canonical/new_view.sql;
```

**When to use:** When you want zero deployment friction and to run SQL directly from branches.

---

## 4. Testing SQL (Without dbt)

### Pattern 1: Inline Assertions

Add verification queries at the bottom of your SQL files:

```sql
-- sql/canonical/est_sales_ntm_weekly.sql

CREATE OR ALTER VIEW ... AS SELECT ...;

--------------------------------------------------------------------------------
-- Verification (run after creating view)
--------------------------------------------------------------------------------
-- No future dates
-- SELECT COUNT(*) FROM quinlan.canonical.est_sales_ntm_weekly
-- WHERE as_of_date > CURRENT_DATE();  -- Should return 0

-- No nulls in key columns
-- SELECT COUNT(*) FROM quinlan.canonical.est_sales_ntm_weekly
-- WHERE company_id IS NULL;  -- Should return 0

-- Sample data for eyeball check
-- SELECT * FROM quinlan.canonical.est_sales_ntm_weekly
-- WHERE ticker_region = 'NVDA-US' LIMIT 10;
```

### Pattern 2: Snowflake ASSERT (For CI)

```sql
-- sql/tests/test_est_sales_ntm_weekly.sql
ASSERT (
  SELECT COUNT(*) FROM quinlan.canonical.est_sales_ntm_weekly
  WHERE as_of_date > CURRENT_DATE()
) = 0 AS 'No future dates allowed';

ASSERT (
  SELECT COUNT(*) FROM quinlan.canonical.est_sales_ntm_weekly
) > 1000 AS 'Minimum row count check';
```

### Pattern 3: pytest + Snowflake

```python
# tests/sql/test_canonical_views.py
def test_est_sales_ntm_no_future_dates(snowflake_conn):
    result = snowflake_conn.cursor().execute(
        "SELECT COUNT(*) FROM quinlan.canonical.est_sales_ntm_weekly "
        "WHERE as_of_date > CURRENT_DATE()"
    ).fetchone()[0]
    assert result == 0, f"Found {result} future-dated rows"
```

---

## 5. Schema Change Management

### CREATE OR ALTER (New Pattern, 2024)

**Idempotent, state-based** schema management. Safe to run multiple times.

```sql
-- This is safe to run repeatedly
CREATE OR ALTER VIEW quinlan.canonical.my_view AS
SELECT col1, col2, col3  -- Add col3 without breaking anything
FROM source;
```

**Advantages over CREATE OR REPLACE:**
- Preserves Time Travel history
- Doesn't invalidate streams
- Safer for tables with data

### Dependency Checking

Before schema changes, check what might break:

```sql
-- What depends on this view?
SELECT *
FROM snowflake.account_usage.object_dependencies
WHERE referenced_object_name = 'EST_SALES_NTM_WEEKLY'
  AND referenced_schema_name = 'CANONICAL';
```

### Breaking Change Pattern

When you need to change a column's semantics:

1. Create new view with `_v2` suffix
2. Update downstream consumers
3. Drop old view
4. Rename `_v2` to original (or leave it)

---

## 6. Simplicity Rules

### What to Avoid (Over-Engineering Traps)

| Trap | Why It's a Trap | Do Instead |
|------|-----------------|------------|
| **dbt for <10 views** | Setup/maintenance overhead exceeds benefit | Plain SQL files |
| **Enterprise catalogs** | Collibra/Alation are team tools, not solo dev tools | Snowflake COMMENT |
| **Complex CI/CD** | Adds friction to iteration loop | Simple shell scripts |
| **Future-proofing** | You'll never hit the scale you're designing for | Design for current needs |
| **Tool obsession** | Each tool is another point of failure | Master fundamentals |

### When to Upgrade

| Current Pain | Solution | When Worth It |
|-------------|----------|---------------|
| Manual deployment is error-prone | Deploy script or schemachange | >5 canonical views |
| Can't remember what exists | Views registry markdown | >10 canonical views |
| Want automatic lineage | dbt-core | >20 views and/or team growth |
| Need real-time refresh | Dynamic Tables | Query performance issues |

### The Golden Rule

> "Build incrementally. Only introduce new systems when current patterns demonstrably can't solve your problems."

---

## Sources

- [dbt Best Practices: How We Structure Projects](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview)
- [Snowflake Git Integration](https://docs.snowflake.com/en/developer-guide/git/git-overview)
- [schemachange (Snowflake Labs)](https://github.com/Snowflake-Labs/schemachange)
- [CREATE OR ALTER | Snowflake Documentation](https://docs.snowflake.com/en/sql-reference/sql/create-or-alter)
- [Zero-Copy Cloning for Dev/Test](https://www.phdata.io/blog/how-to-use-snowflake-zero-copy-cloning-in-your-ci-cd-pipelines/)
- [Feature Store Design Patterns for Small Data Teams](https://mljourney.com/feature-store-design-patterns-for-small-data-teams/)
- [Radical Simplicity in Data Engineering](https://towardsdatascience.com/radical-simplicity-in-data-engineering-86ec3d2bd71c/)
