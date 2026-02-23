# SQL Documentation Patterns for Small Teams

Lightweight documentation approaches that balance value against maintenance burden.

## Core Principle

> Document **why**, not **what**. The code shows what; comments explain the reasoning.

---

## 1. Inline SQL Documentation

### Header Template

Every canonical SQL file should have:

```sql
-- ============================================================================
-- EST_SALES_NTM_WEEKLY: Point-in-time NTM Sales estimates for regime screen
-- ============================================================================
-- Created: 2025-12-16
-- Updated: 2025-12-17 (FY1/FY2 blending per estimates.py pattern)
--
-- Purpose:
--   Weekly NTM (next-twelve-months) sales estimates with AB revision signals.
--   Primary input to regime screen's AB channel detection.
--
-- Grain: company_id × week_end_date
--
-- Dependencies:
--   - QUINLAN.STG_SPG.ESTIMATES_PIT (estimates)
--   - QUINLAN.REFERENCE.CALENDAR_WEEKLY (calendar)
--
-- Key Semantics:
--   - PIT: Uses estimate_date, not publish_date (no lookahead bias)
--   - NTM: Time-weighted blend of FY1/FY2, NOT vendor pre-computed
--   - Revisions: 4-week window, log-space, smoothed
--
-- Deployment:
--   snow sql -f warehouse/sql/canonical/estimates/est_ntm_weekly.sql
-- ============================================================================
```

### CTE Documentation

Explain non-obvious steps:

```sql
-- Step 1: Get calendar dates for join (Saturday week-ends only)
calendar AS (
    SELECT week_end_date FROM reference.calendar_weekly
    WHERE week_end_date BETWEEN '2010-01-01' AND CURRENT_DATE()
),

-- Step 2: Time-weight FY1/FY2 estimates
-- NOTE: We compute NTM ourselves because vendor pre-computed NTM
-- has inconsistent methodology across time periods
ntm_blended AS (
    ...
),
```

### What to Document vs Skip

| Document | Skip |
|----------|------|
| Business logic decisions | Obvious SQL syntax |
| Vendor quirks and workarounds | What the code literally does |
| PIT semantics and date handling | Standard transformations |
| Why a particular window/threshold | Column renamings |
| Data quality boundaries | JOIN conditions (usually obvious) |

---

## 2. Snowflake COMMENT (Object-Level)

Add `COMMENT ON VIEW` to every canonical view:

```sql
COMMENT ON VIEW QUINLAN.CANONICAL.EST_SALES_NTM_WEEKLY IS
'Point-in-time NTM sales estimates with 4-week revision signals.
Grain: company_id × week_end_date. Primary input to AB channel detection.
PIT: Uses estimate_date for no lookahead bias.';
```

**Why:** Comments are queryable via `INFORMATION_SCHEMA`, version-controlled in your DDL, and require no separate tools.

### Column Comments (Selective)

Only for non-obvious fields:

```sql
COMMENT ON COLUMN QUINLAN.CANONICAL.EST_SALES_NTM_WEEKLY.revision_ma_13w_26w IS
'26-week MA of revision_ma_13w. Primary AB channel input.';

COMMENT ON COLUMN QUINLAN.CANONICAL.EST_SALES_NTM_WEEKLY.is_forward_filled IS
'TRUE when estimate was carried forward (no update this week). ~90% of rows expected.';
```

**Skip columns like:** `company_id`, `week_end_date`, `ticker` (self-explanatory).

---

## 3. Data Dictionary (Keep It Simple)

**Don't build a separate data dictionary.** Your existing docs are sufficient:
- ADRs for architectural decisions
- Vendor guides in `docs/platform/data-sources/`
- SQL header comments

### Optional: Views Registry

If you need a quick reference (10+ views), create one markdown file:

```markdown
# Canonical Views Registry

| View | Purpose | Grain | Primary Use |
|------|---------|-------|-------------|
| EST_SALES_NTM_WEEKLY | NTM sales with AB revision | company × week | Regime screen |
| CLASSIFICATION_PEER_EDGES | Union-all peer mapping | focal × peer | Peer benchmark |
| PRICES_WEEKLY | Weekly sampled prices | trading_item × week | All screens |

## Conventions
- **PIT**: Point-in-time (no lookahead)
- **WEEKLY**: Saturday week-end date grain
- **NTM**: Next-twelve-months (computed, not vendor pre-computed)
```

---

## 4. Lineage Documentation

### Pattern 1: Dependency Comments (Lowest Effort)

Add to every SQL header:

```sql
-- Dependencies:
--   - QUINLAN.STG_SPG.ESTIMATES_PIT
--   - QUINLAN.REFERENCE.CALENDAR_WEEKLY
```

### Pattern 2: Query Dependencies (On Demand)

```sql
-- What does this view depend on?
SELECT *
FROM snowflake.account_usage.object_dependencies
WHERE referencing_object_name = 'EST_SALES_NTM_WEEKLY';

-- What depends on this view?
SELECT *
FROM snowflake.account_usage.object_dependencies
WHERE referenced_object_name = 'EST_SALES_NTM_WEEKLY';
```

### Pattern 3: dbt (Future, At Scale)

When you have 20+ views and want automatic lineage graphs:

```bash
uv add dbt-core dbt-snowflake
dbt init
dbt docs generate
dbt docs serve
```

---

## 5. Verification Queries

Add at the end of every canonical SQL file:

```sql
--------------------------------------------------------------------------------
-- Verification (run after creating view)
--------------------------------------------------------------------------------
/*
-- 1. No future dates (PIT check)
SELECT COUNT(*) FROM quinlan.canonical.est_sales_ntm_weekly
WHERE as_of_date > CURRENT_DATE();  -- Should be 0

-- 2. No nulls in key columns
SELECT
    SUM(CASE WHEN company_id IS NULL THEN 1 ELSE 0 END) as null_company,
    SUM(CASE WHEN week_end_date IS NULL THEN 1 ELSE 0 END) as null_date
FROM quinlan.canonical.est_sales_ntm_weekly;

-- 3. Sample data for known ticker
SELECT *
FROM quinlan.canonical.est_sales_ntm_weekly
WHERE ticker_region = 'NVDA-US'
ORDER BY week_end_date DESC
LIMIT 10;

-- 4. Row count sanity
SELECT COUNT(*), MIN(week_end_date), MAX(week_end_date)
FROM quinlan.canonical.est_sales_ntm_weekly;
*/
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Why It's Bad | Do Instead |
|--------------|--------------|------------|
| **Over-documentation** | Maintenance burden, stale comments | Document "why" only |
| **Separate wiki** | Drifts from code, no version control | Keep docs in SQL files |
| **Enterprise catalogs** | Overkill for solo dev, high cost | Snowflake COMMENT |
| **Documenting obvious code** | Noise, obscures important comments | Trust SQL readability |
| **Stale comments** | Worse than no comments | Update or delete |

---

## Checklist for New Canonical Views

Before merging:

- [ ] Header comment with purpose, dates, dependencies
- [ ] CTE comments explaining "why" (not "what")
- [ ] `COMMENT ON VIEW` with grain and use case
- [ ] Column comments for non-obvious fields (optional)
- [ ] Verification queries at end

---

## Sources

- [SQL Comment Best Practices (LinkedIn)](https://www.linkedin.com/advice/3/what-best-practices-writing-sql-documentation-comments)
- [Snowflake COMMENT Documentation](https://docs.snowflake.com/en/sql-reference/sql/comment)
- [Data Dictionary for Small Business (Brewster)](https://www.brewsterconsulting.io/building-a-data-dictionary-for-your-small-or-mid-sized-business)
