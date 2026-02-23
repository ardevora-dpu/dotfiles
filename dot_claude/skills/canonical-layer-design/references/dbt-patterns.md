# dbt Patterns for Quinlan

dbt-core is the recommended tool for managing SQL dependencies, lineage, and documentation. This reference covers patterns specific to our Snowflake + dbt setup.

## Why dbt?

1. **Dependency management**: `ref()` creates explicit, verified dependencies
2. **AI agent integration**: dbt MCP Server exposes project structure to Claude/agents
3. **Lineage**: `dbt docs generate` creates interactive DAG visualisation
4. **Testing**: Declarative YAML tests for data quality

## Project Structure

```
warehouse/
├── dbt_project.yml           # Project config
├── profiles.yml              # Connection config
│
├── models/
│   ├── staging/              # LAYER 0: Vendor transforms
│   │   └── spglobal/
│   │       ├── _spglobal__sources.yml
│   │       ├── _spglobal__models.yml
│   │       └── stg_spglobal__*.sql
│   │
│   ├── intermediate/         # Building blocks, lookups
│   │   └── int_*.sql
│   │
│   └── marts/                # LAYER 1+2: Canonical + Serving
│       ├── canonical/
│       │   └── *.sql
│       └── serving/
│           └── *.sql
│
├── tests/                    # Custom SQL tests
├── macros/                   # Reusable Jinja macros
└── seeds/                    # Static CSV data
```

## Naming Conventions

| Layer | Prefix | Example | Schema |
|-------|--------|---------|--------|
| **Staging** | `stg_<source>__` | `stg_spglobal__prices` | `STG_SPG` |
| **Intermediate** | `int_` | `int_investable_universe_weekly` | `CANONICAL` |
| **Canonical** | (none) | `est_ntm_weekly`, `rel_returns_weekly` | `CANONICAL` |
| **Serving** | (none) | `screen_jeremy_v1` | `MART` |

**Why double underscore?** `stg_spglobal__prices` separates source (`spglobal`) from object (`prices`). Single underscore within each part.

## Core Functions

### `source()` — Reference External Tables

Use for vendor tables you read from but don't own:

```sql
-- models/staging/spglobal/stg_spglobal__prices.sql
SELECT *
FROM {{ source('spglobal', 'ciqPriceEquity') }}
```

Define sources in YAML:

```yaml
# models/staging/spglobal/_spglobal__sources.yml
version: 2
sources:
  - name: spglobal
    database: SPG_XPRESSFEED_SHARE
    schema: XPRESSFEED
    tables:
      - name: ciqPriceEquity
        description: Daily OHLCV prices (split-adjusted)
      - name: ciqTradingItem
        description: Trading item master
```

### `ref()` — Reference Other Models

Use for internal dependencies:

```sql
-- models/marts/canonical/rel_returns_weekly.sql
SELECT *
FROM {{ ref('int_weekly_returns_base') }} r
JOIN {{ ref('int_winsorisation_thresholds') }} w
  ON r.week_end_date = w.week_end_date
```

**Key benefit**: dbt builds the DAG from `ref()` calls. No manual dependency tracking.

## Model Configuration

### In-file Config Block

```sql
{{
  config(
    materialized='view',           -- or 'table', 'incremental', 'dynamic_table'
    schema='CANONICAL',            -- override default schema
    tags=['weekly', 'estimates']   -- for selective runs
  )
}}

SELECT ...
```

### Materialisation Types

| Type | When to Use | Snowflake Object |
|------|-------------|------------------|
| `view` | Cheap queries, composable logic | VIEW |
| `table` | Expensive transforms, needs materialisation | TABLE |
| `incremental` | Large fact tables, append-mostly | TABLE with merge/append |
| `dynamic_table` | Managed refresh by Snowflake | DYNAMIC TABLE |

### Dynamic Tables in dbt

```sql
{{
  config(
    materialized='dynamic_table',
    target_lag='1 hour',
    snowflake_warehouse='COMPUTE_WH'
  )
}}

SELECT ...
```

**Caveat**: Dynamic tables are refreshed by Snowflake, not dbt. Use for downstream serving, not mid-pipeline transforms.

## Testing

### Generic Tests (YAML)

```yaml
# models/marts/canonical/_canonical__models.yml
version: 2
models:
  - name: est_ntm_weekly
    description: Point-in-time NTM sales estimates
    columns:
      - name: company_id
        tests:
          - not_null
      - name: week_end_date
        tests:
          - not_null
      - name: company_id_week
        tests:
          - unique  # Composite key test
```

### Custom SQL Tests

```sql
-- tests/assert_no_future_dates.sql
SELECT *
FROM {{ ref('est_ntm_weekly') }}
WHERE week_end_date > CURRENT_DATE()
```

Test passes if query returns 0 rows.

## Run Order for Staging Changes

When you change a staging model that feeds downstream tables, rebuild upstream first so the new logic propagates:

```bash
# Rebuild upstream staging + intermediate
uv run dbt build --select +int_estimates_pit

# Then rebuild downstream consumers
uv run dbt build --select int_estimates_pit+
```

This avoids stale staging views when you run only downstream selectors.

## Documentation

### In-model Docs

```sql
{{
  config(
    materialized='view'
  )
}}

-- EST_NTM_WEEKLY: Point-in-time NTM Sales estimates
-- Grain: company_id × week_end_date
-- PIT: Uses estimate_date, not publish_date

SELECT ...
```

### YAML Docs (Richer)

```yaml
models:
  - name: est_ntm_weekly
    description: |
      Point-in-time NTM (next-twelve-months) sales estimates.

      **Grain**: company_id × week_end_date
      **PIT**: Uses estimate_date for no lookahead bias
      **NTM**: Time-weighted blend of FY1/FY2
    columns:
      - name: revision_ma_13w_26w
        description: 26-week MA of revision_ma_13w. Primary AB channel input.
```

## Common Commands

```bash
# Run all models
dbt run

# Run specific model + downstream
dbt run --select est_ntm_weekly+

# Run specific model + upstream
dbt run --select +est_ntm_weekly

# Run by tag
dbt run --select tag:weekly

# Test all
dbt test

# Generate docs
dbt docs generate
dbt docs serve

# Compile without running (see generated SQL)
dbt compile --select my_model
```

## Incremental Models

For large fact tables:

```sql
{{
  config(
    materialized='incremental',
    unique_key=['company_id', 'week_end_date'],
    incremental_strategy='merge'
  )
}}

SELECT ...
FROM {{ source('spglobal', 'ciqEstimatePeriod') }}

{% if is_incremental() %}
WHERE estimate_date > (SELECT MAX(week_end_date) FROM {{ this }})
{% endif %}
```

**Strategies**:
- `merge`: Upsert based on unique_key (default)
- `append`: Simple insert (fastest)
- `delete+insert`: Delete matching, then insert

## dbt MCP Server (AI Agent Integration)

The dbt MCP Server exposes project structure to AI agents:

```bash
# Install
pip install dbt-mcp

# Configure in Claude Desktop
# ~/.config/claude/mcp_servers.json
```

**What agents can query**:
- `list_models`: All models in project
- `get_model_details`: SQL, columns, dependencies, tests
- `get_model_parents`: Upstream dependencies
- `get_model_children`: Downstream impacts

**Why this matters**: Agents can understand lineage without parsing SQL.

## Migration Pattern (Existing SQL → dbt)

1. **Remove DDL wrapper**:
   ```sql
   -- Before
   CREATE OR REPLACE VIEW QUINLAN.STG_SPG.PRICES AS
   SELECT ...

   -- After (dbt model)
   SELECT ...
   ```

2. **Replace hard-coded sources**:
   ```sql
   -- Before
   FROM SPG_XPRESSFEED_SHARE.XPRESSFEED.ciqPriceEquity

   -- After
   FROM {{ source('spglobal', 'ciqPriceEquity') }}
   ```

3. **Replace hard-coded refs**:
   ```sql
   -- Before
   FROM QUINLAN.STG_SPG.FX

   -- After
   FROM {{ ref('stg_spglobal__fx') }}
   ```

4. **Add config block** if non-default materialisation needed.

## Anti-Patterns

| Anti-Pattern | Why Bad | Do Instead |
|--------------|---------|------------|
| Hard-coded schema names | Breaks dev/prod separation | Use `ref()` and `source()` |
| `SELECT *` in staging | Schema changes break downstream | Explicit column list |
| No unique key on incremental | Duplicates on rerun | Always define `unique_key` |
| Giant monolithic models | Hard to test, debug | Break into intermediate models |
| Tests only on final marts | Failures hard to trace | Test at each layer |

## Quinlan-Specific Patterns

### Vendor Data (S&P Global)

All S&P Global tables are defined as sources:
```yaml
sources:
  - name: spglobal
    database: SPG_XPRESSFEED_SHARE
    schema: XPRESSFEED
```

### Calendar Joins

Use the reference calendar for week alignment:
```sql
FROM {{ ref('int_calendar_weekly') }} cal
```

### PIT Semantics

Always use `estimate_date` (when estimate was made), not `publish_date`:
```sql
WHERE estimate_date <= cal.week_end_date
```

## Sources

- [dbt Best Practices: Project Structure](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview)
- [dbt Snowflake Configuration](https://docs.getdbt.com/reference/resource-configs/snowflake-configs)
- [dbt MCP Server](https://github.com/dbt-labs/dbt-mcp)
- [Incremental Models](https://docs.getdbt.com/docs/build/incremental-models)
