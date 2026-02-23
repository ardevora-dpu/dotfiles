# Layer Patterns: Detailed Examples

## Layer 0: Vendor / Staging

### What Belongs Here

Mechanical transforms only:
- Column mapping and renaming
- Deduplication (primary record selection)
- Type casts
- Basic filters (e.g., `price > 0`)

### Example: Vendor Price Staging

```sql
CREATE OR REPLACE VIEW STG_VENDOR.PRICES_DAILY AS
SELECT
    entity_id,
    price_date,
    price_close,
    price_open,
    price_high,
    price_low,
    volume,
    currency_id
FROM VENDOR_SHARE.RAW_PRICES
WHERE is_primary = TRUE
  AND price_close > 0;
```

**Key point**: No business logic. If you're tempted to add calendar alignment or PIT semantics here, move it to Layer 1.

---

## Layer 1: Canonical (Contract Layer)

### What Belongs Here

Everything that defines "truth" for the product:
- PIT semantics
- Calendar alignment
- Currency conventions
- Cohort/peer definitions
- Sampling rules (daily → weekly)
- Staleness / freshness flags

### Example: Weekly Sampling with PIT Semantics

```sql
CREATE OR REPLACE TABLE CANONICAL.PRICES_WEEKLY AS
WITH calendar AS (
    SELECT week_end_date, week_id
    FROM REFERENCE.TRADING_CALENDAR
    WHERE week_end_date BETWEEN '2010-01-01' AND CURRENT_DATE()
),
daily_with_week AS (
    SELECT
        p.*,
        c.week_end_date,
        c.week_id
    FROM STG_VENDOR.PRICES_DAILY p
    JOIN calendar c
      ON p.price_date <= c.week_end_date
     AND p.price_date > DATEADD(day, -7, c.week_end_date)
),
weekly_sampled AS (
    SELECT *
    FROM daily_with_week
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY entity_id, week_end_date
        ORDER BY price_date DESC  -- Latest available in week
    ) = 1
)
SELECT
    entity_id,
    week_end_date,
    week_id,
    price_date AS sampled_date,
    price_close,
    price_open,
    price_high,
    price_low,
    volume,
    CURRENT_TIMESTAMP() AS computed_at
FROM weekly_sampled;
```

### Example: Time-Weighted Forward Estimates

A common pattern for NTM (next-twelve-months) estimates using time-weighted interpolation:

```sql
CREATE OR REPLACE TABLE CANONICAL.FORWARD_ESTIMATES_WEEKLY AS
WITH period_estimates AS (
    SELECT
        entity_id,
        week_end_date,
        fiscal_period,
        estimate_value,
        period_end_date,
        DATEDIFF(day, week_end_date, period_end_date) AS days_to_end
    FROM STG_VENDOR.CONSENSUS_ESTIMATES e
    JOIN REFERENCE.TRADING_CALENDAR c ON e.effective_date = c.week_end_date
),
ntm_calc AS (
    SELECT
        entity_id,
        week_end_date,
        -- Current and next period based on days remaining
        MAX(CASE WHEN days_to_end > 0 AND days_to_end <= 365 THEN estimate_value END) AS period1_value,
        MAX(CASE WHEN days_to_end > 0 AND days_to_end <= 365 THEN days_to_end END) AS period1_days,
        MAX(CASE WHEN days_to_end > 365 AND days_to_end <= 730 THEN estimate_value END) AS period2_value
    FROM period_estimates
    GROUP BY entity_id, week_end_date
)
SELECT
    entity_id,
    week_end_date,
    -- Time-weighted interpolation
    (period1_value * period1_days + period2_value * (365 - period1_days)) / 365 AS ntm_value,
    period1_value,
    period2_value,
    period1_days,
    'forward_estimate_v1' AS config_name,
    MD5(OBJECT_CONSTRUCT('method', 'time_weighted', 'version', 'v1')::STRING) AS config_hash,
    CURRENT_TIMESTAMP() AS computed_at
FROM ntm_calc
WHERE period1_value IS NOT NULL;
```

### Object Type Selection

| Scenario | Object Type | Rationale |
|----------|-------------|-----------|
| Simple joins, cheap window functions | **View** | On-read execution is fine |
| Expensive window functions, many consumers | **Table** | Materialise to avoid recompute |
| Pipeline with upstream dependencies | **Dynamic Table** | Managed refresh, incremental if possible |
| Need incremental refresh + lineage | **Dynamic Table** | Snowflake handles scheduling |

---

## Layer 2: Serving / MART

### What Belongs Here

Denormalised, fast, obvious objects for UI/MCP:
- Pre-joined across canonical tables
- Pre-aggregated if needed
- Single "as of" timestamp per row
- No complex logic—just reads

### Example: Screen Serving View (Latest)

```sql
CREATE OR REPLACE VIEW MART.SCREEN_LATEST AS
SELECT
    -- Identifiers (stable)
    u.entity_id,

    -- Display fields (for UI, not joins)
    u.entity_name,
    u.ticker,
    u.sector,
    u.industry,

    -- Time anchor
    p.week_end_date AS as_of_date,

    -- Price data
    p.price_close,
    p.price_52w_high,
    p.price_52w_low,

    -- Indicators
    m.indicator_value,
    m.signal_direction,
    m.time_in_state_weeks,

    -- Estimates
    e.forward_estimate,

    -- Fundamentals
    f.metric_ltm,

    -- Labels/classifications
    l.label,
    l.confidence,
    l.config_hash AS label_config_hash

FROM CANONICAL.UNIVERSE_CURRENT u
JOIN CANONICAL.PRICES_WEEKLY p
  ON u.entity_id = p.entity_id
 AND p.week_end_date = (SELECT MAX(week_end_date) FROM CANONICAL.PRICES_WEEKLY)
LEFT JOIN CANONICAL.INDICATORS m
  ON u.entity_id = m.entity_id
 AND m.week_end_date = p.week_end_date
LEFT JOIN CANONICAL.FORWARD_ESTIMATES_WEEKLY e
  ON u.entity_id = e.entity_id
 AND e.week_end_date = p.week_end_date
LEFT JOIN CANONICAL.FUNDAMENTALS_LTM f
  ON u.entity_id = f.entity_id
 AND f.week_end_date = p.week_end_date
LEFT JOIN CANONICAL.LABELS l
  ON u.entity_id = l.entity_id
 AND l.week_end_date = p.week_end_date;
```

### Example: Historical As-Of View

```sql
CREATE OR REPLACE VIEW MART.SCREEN_ASOF AS
-- Same structure but allows filtering by week_end_date
-- Usage: SELECT * FROM MART.SCREEN_ASOF WHERE week_end_date = '2024-06-28'
SELECT
    week_end_date,
    entity_id,
    entity_name,
    -- ... all fields from SCREEN_LATEST ...
FROM CANONICAL.SCREEN_HISTORY
WHERE week_end_date >= DATEADD(year, -5, CURRENT_DATE());
```

### Minimum Viable MART

If you implement just two objects, start with:

1. **`MART.SCREEN_LATEST`** — One row per entity, latest week
2. **`MART.ENTITY_SERIES_WEEKLY`** — One row per entity-week for charting

These cover the two dominant UI patterns (table view, chart view).

---

## Cross-Cutting: Config + Run Tracking

### The Problem

When a number changes on a screen, you need to answer two questions:
1. **Which logic/parameters?** → `config_hash`
2. **Which inputs?** → `run_id` with input watermarks

### The CONFIGS Table

```sql
CREATE TABLE IF NOT EXISTS CANONICAL.CONFIGS (
    config_name     STRING NOT NULL,
    config_hash     STRING NOT NULL,
    config_json     VARIANT NOT NULL,
    code_version    STRING,
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    description     STRING,
    PRIMARY KEY (config_name, config_hash)
);

-- Example insert
INSERT INTO CANONICAL.CONFIGS (config_name, config_hash, config_json, code_version, description)
SELECT
    'indicator_v2',
    MD5(config_json::STRING),
    PARSE_JSON('{
        "period": 14,
        "min_run_weeks": 3,
        "threshold": 25,
        "smoothing": "exponential"
    }'),
    'git:abc123',
    'Production indicator config as of 2024-06';
```

### The RUNS Table (Input Watermarks)

```sql
CREATE TABLE IF NOT EXISTS CANONICAL.RUNS (
    run_id              STRING NOT NULL PRIMARY KEY,
    started_at          TIMESTAMP_NTZ NOT NULL,
    finished_at         TIMESTAMP_NTZ,
    code_version        STRING,
    config_hash         STRING,
    input_watermarks    VARIANT,      -- {"prices_max_date": "2024-06-28", ...}
    output_row_counts   VARIANT,      -- {"indicators": 12345, ...}
    status              STRING DEFAULT 'running',
    error_message       STRING
);

-- Example: start a run
INSERT INTO CANONICAL.RUNS (run_id, started_at, code_version, config_hash, input_watermarks, status)
SELECT
    'run_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'),
    CURRENT_TIMESTAMP(),
    'git:abc123',
    (SELECT config_hash FROM CANONICAL.CONFIGS WHERE config_name = 'indicator_v2' ORDER BY created_at DESC LIMIT 1),
    OBJECT_CONSTRUCT(
        'prices_max_date', (SELECT MAX(price_date) FROM CANONICAL.PRICES_WEEKLY),
        'estimates_max_date', (SELECT MAX(week_end_date) FROM CANONICAL.FORWARD_ESTIMATES_WEEKLY)
    ),
    'running';
```

### Linking Outputs to Configs + Runs

Every derived table that affects screens should include:

```sql
SELECT
    -- ... business columns ...
    :run_id AS run_id,
    :config_hash AS config_hash,
    CURRENT_TIMESTAMP() AS computed_at
FROM ...
```

This enables:
- **Reproducibility**: "Which config and inputs produced this number?"
- **Auditing**: "What changed between runs?"
- **Debugging**: "Did inputs change or did logic change?"
- **Rollback**: Recompute with previous config if needed
