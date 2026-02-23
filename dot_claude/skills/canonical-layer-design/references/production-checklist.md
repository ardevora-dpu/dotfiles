# Production Readiness Checklist

## Before a Data Product Goes to Screen/UI

### 1. Contract Definition

- [ ] Output schema documented (column names, types, semantics)
- [ ] `config_hash` column present (links to CONFIGS table)
- [ ] `run_id` column present (links to RUNS table for input watermarks)
- [ ] `computed_at` timestamp present
- [ ] Contract lives in `docs/platform/data-contracts/` or inline comments

### 2. Canonical Layer Compliance

- [ ] PIT semantics documented (what "as of" means)
- [ ] Calendar alignment explicit (which calendar? weekly end date?)
- [ ] Currency conventions stated (USD default? original currency preserved?)
- [ ] Joins use canonical IDs, not market identifiers (ticker, ISIN)
- [ ] No business logic in serving layer—it's all in canonical

### 3. Reproducibility

- [ ] Config stored in `CONFIGS` table with hash
- [ ] Run stored in `RUNS` table with input watermarks
- [ ] Code version tracked (git SHA or tag)
- [ ] Historical outputs preserved (don't overwrite with REPLACE)
- [ ] Can answer: "What config AND inputs produced this number on date X?"

### 4. Security & Access Control

- [ ] NOT running as ACCOUNTADMIN
- [ ] Dedicated deploy role with minimal grants
- [ ] Data-reader roles separate from deploy roles
- [ ] No secrets in SQL files or config tables

### 5. Performance & Cost

- [ ] Date filter required on time-series queries (enforced in serving layer)
- [ ] Table clustered appropriately (date first, then entity)
- [ ] Large window functions materialised, not run per-query
- [ ] Warehouse size appropriate (not XL for small queries)

### 6. Observability

- [ ] Refresh schedule documented (dynamic table lag or task frequency)
- [ ] Staleness alerts configured (if data older than X, notify)
- [ ] Query history tags set for traceability
- [ ] Row counts / null checks in place

---

## Role Setup Template

```sql
-- Create deployment role (one-time setup)
CREATE ROLE IF NOT EXISTS QUINLAN_DEPLOY;
GRANT USAGE ON DATABASE QUINLAN TO ROLE QUINLAN_DEPLOY;
GRANT USAGE ON SCHEMA QUINLAN.CANONICAL TO ROLE QUINLAN_DEPLOY;
GRANT USAGE ON SCHEMA QUINLAN.REFERENCE TO ROLE QUINLAN_DEPLOY;
GRANT USAGE ON SCHEMA QUINLAN.MART TO ROLE QUINLAN_DEPLOY;

-- Grant table/view creation
GRANT CREATE TABLE ON SCHEMA QUINLAN.CANONICAL TO ROLE QUINLAN_DEPLOY;
GRANT CREATE VIEW ON SCHEMA QUINLAN.CANONICAL TO ROLE QUINLAN_DEPLOY;
GRANT CREATE DYNAMIC TABLE ON SCHEMA QUINLAN.CANONICAL TO ROLE QUINLAN_DEPLOY;

-- Create reader role for UI/MCP
CREATE ROLE IF NOT EXISTS QUINLAN_READER;
GRANT USAGE ON DATABASE QUINLAN TO ROLE QUINLAN_READER;
GRANT USAGE ON SCHEMA QUINLAN.MART TO ROLE QUINLAN_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA QUINLAN.MART TO ROLE QUINLAN_READER;
GRANT SELECT ON ALL VIEWS IN SCHEMA QUINLAN.MART TO ROLE QUINLAN_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA QUINLAN.MART TO ROLE QUINLAN_READER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA QUINLAN.MART TO ROLE QUINLAN_READER;

-- Assign to service accounts / users
GRANT ROLE QUINLAN_DEPLOY TO USER deploy_service;
GRANT ROLE QUINLAN_READER TO USER mcp_service;
GRANT ROLE QUINLAN_READER TO USER ui_service;
```

---

## Config + Run Table Setup

### CONFIGS Table

```sql
CREATE TABLE IF NOT EXISTS CANONICAL.CONFIGS (
    config_name     STRING NOT NULL COMMENT 'Logical name (e.g., indicator_v2)',
    config_hash     STRING NOT NULL COMMENT 'MD5 of config_json for dedup',
    config_json     VARIANT NOT NULL COMMENT 'Full configuration as JSON',
    code_version    STRING COMMENT 'Git SHA or version tag',
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    description     STRING COMMENT 'Human-readable description',
    PRIMARY KEY (config_name, config_hash)
);

ALTER TABLE CANONICAL.CONFIGS CLUSTER BY (config_name);
```

### RUNS Table (Input Watermarks)

```sql
CREATE TABLE IF NOT EXISTS CANONICAL.RUNS (
    run_id              STRING NOT NULL PRIMARY KEY,
    started_at          TIMESTAMP_NTZ NOT NULL,
    finished_at         TIMESTAMP_NTZ,
    code_version        STRING,
    config_hash         STRING,
    input_watermarks    VARIANT COMMENT '{"prices_max_date": "2024-06-28", ...}',
    output_row_counts   VARIANT COMMENT '{"table_a": 12345, ...}',
    status              STRING DEFAULT 'running',
    error_message       STRING
);

ALTER TABLE CANONICAL.RUNS CLUSTER BY (started_at);
```

### Using Configs + Runs in Derived Tables

```sql
-- Step 1: Register config (if new)
INSERT INTO CANONICAL.CONFIGS (config_name, config_hash, config_json, code_version, description)
SELECT 'indicator_v1', MD5(config::STRING), config, 'git:abc123', 'Production indicator'
FROM (SELECT PARSE_JSON('{"period": 14, "method": "wilder"}') AS config)
WHERE NOT EXISTS (
    SELECT 1 FROM CANONICAL.CONFIGS
    WHERE config_name = 'indicator_v1'
      AND config_hash = MD5(PARSE_JSON('{"period": 14, "method": "wilder"}')::STRING)
);

-- Step 2: Create run record
INSERT INTO CANONICAL.RUNS (run_id, started_at, code_version, config_hash, input_watermarks, status)
SELECT
    'run_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'),
    CURRENT_TIMESTAMP(),
    'git:abc123',
    MD5(PARSE_JSON('{"period": 14, "method": "wilder"}')::STRING),
    OBJECT_CONSTRUCT(
        'prices_max_date', (SELECT MAX(date) FROM CANONICAL.PRICES_DAILY)
    ),
    'running';

-- Step 3: Reference in derived table
CREATE OR REPLACE TABLE CANONICAL.INDICATORS_WEEKLY AS
SELECT
    entity_id,
    week_end_date,
    indicator_value,
    'run_20240628_143022' AS run_id,  -- From step 2
    MD5('{"period": 14, "method": "wilder"}') AS config_hash,
    CURRENT_TIMESTAMP() AS computed_at
FROM ...;

-- Step 4: Mark run complete
UPDATE CANONICAL.RUNS
SET finished_at = CURRENT_TIMESTAMP(),
    status = 'completed',
    output_row_counts = OBJECT_CONSTRUCT('indicators_weekly', 12345)
WHERE run_id = 'run_20240628_143022';
```

---

## Staleness Monitoring

### Simple Alert Query

```sql
-- Run daily; alert if any canonical table is stale
SELECT
    table_name,
    MAX(computed_at) AS last_computed,
    DATEDIFF(hour, MAX(computed_at), CURRENT_TIMESTAMP()) AS hours_stale
FROM (
    SELECT 'PRICES_WEEKLY' AS table_name, computed_at FROM CANONICAL.PRICES_WEEKLY_TBL
    UNION ALL
    SELECT 'EST_NTM_WEEKLY', computed_at FROM CANONICAL.EST_NTM_WEEKLY
    UNION ALL
    SELECT 'ADX_DMI_WEEKLY', computed_at FROM CANONICAL.ADX_DMI_WEEKLY
)
GROUP BY table_name
HAVING hours_stale > 48  -- Alert if more than 48 hours stale
ORDER BY hours_stale DESC;
```

### Dynamic Table Lag Monitoring

```sql
-- Check dynamic table refresh status
SELECT
    name,
    target_lag,
    refresh_mode,
    scheduling_state,
    last_completed_refresh,
    DATEDIFF(minute, last_completed_refresh, CURRENT_TIMESTAMP()) AS minutes_since_refresh
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE schema_name = 'CANONICAL'
ORDER BY minutes_since_refresh DESC;
```

---

## Serving Layer Contract

### What Serving Views Must Provide

1. **Single `as_of` column**: `week_end_date` or `as_of_date`—never ambiguous
2. **Entity identifiers**: `company_id`, `trading_item_id` as appropriate
3. **Human-readable fields**: `company_name`, `ticker` (for display only)
4. **Config hash**: For any derived/computed columns
5. **No NULLs in critical paths**: Use COALESCE with sensible defaults, or filter

### Serving View Template

```sql
CREATE OR REPLACE VIEW MART.{DOMAIN}_LATEST AS
SELECT
    -- Identifiers (stable)
    u.company_id,
    u.trading_item_id,

    -- Display fields (for UI, not joins)
    u.company_name,
    u.ticker,
    u.gics_sector,

    -- Time anchor (explicit)
    p.week_end_date AS as_of_date,

    -- Domain data
    p.price_close,
    m.adx_14,
    m.dmi_plus,
    m.dmi_minus,
    e.ntm_eps,

    -- Metadata
    p.computed_at AS price_computed_at,
    m.config_hash AS momentum_config_hash

FROM CANONICAL.UNIVERSE_CURRENT u
JOIN CANONICAL.PRICES_WEEKLY_TBL p
  ON u.trading_item_id = p.trading_item_id
 AND p.week_end_date = (SELECT MAX(week_end_date) FROM CANONICAL.PRICES_WEEKLY_TBL)
LEFT JOIN CANONICAL.MOMENTUM_INDICATORS m
  ON u.trading_item_id = m.trading_item_id
 AND m.week_end_date = p.week_end_date
LEFT JOIN CANONICAL.EST_NTM_WEEKLY e
  ON u.company_id = e.company_id
 AND e.week_end_date = p.week_end_date
WHERE u.is_active = TRUE;

-- Grant to reader role
GRANT SELECT ON MART.{DOMAIN}_LATEST TO ROLE QUINLAN_READER;
```

---

## Pre-Launch Checklist (Copy & Use)

```markdown
## Data Product: _______________
## Launch Date: _______________

### Contract
- [ ] Schema documented in docs/platform/data-contracts/
- [ ] Tracking columns present: config_hash, run_id, computed_at
- [ ] Config registered in CONFIGS table
- [ ] Run workflow implemented (create run → compute → mark complete)

### Security
- [ ] Deploy role (not ACCOUNTADMIN) used for DDL
- [ ] Reader role granted to UI/MCP service accounts
- [ ] No secrets in config or SQL

### Performance
- [ ] Clustering key appropriate (date, entity)
- [ ] Date filter enforced in serving view
- [ ] Tested with realistic data volume

### Observability
- [ ] Staleness query added to monitoring
- [ ] Query tags set for traceability
- [ ] Can debug "why did this change?" via RUNS table

### Sign-off
- [ ] Reviewed by: _______________
- [ ] Tested in staging: [ ] Yes [ ] N/A
```
