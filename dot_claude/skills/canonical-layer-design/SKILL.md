---
name: canonical-layer-design
description: Design, audit, and extend the canonical data layer (vendor → canonical → serving). Use when adding new data products, deciding SQL vs Python vs Snowpark, or designing screen-critical pipelines.
---

# Canonical Layer Design

Architectural patterns for a three-layer data model. Use this skill when:

- Designing new canonical data products
- Deciding where logic belongs (SQL vs Python vs Snowpark)
- Adding screen/UI dependencies
- Planning PIT (point-in-time) semantics
- Reviewing data pipeline architecture
- **Writing or modifying dbt models**

## Tooling: dbt-core

**We use dbt-core for SQL dependency management.** Key benefits:

1. **Explicit dependencies**: `ref()` and `source()` create verified DAG
2. **AI agent integration**: dbt MCP Server exposes lineage to Claude
3. **Automatic ordering**: `dbt run` executes models in dependency order
4. **Documentation**: `dbt docs generate` creates interactive lineage graphs

For dbt-specific patterns, see `references/dbt-patterns.md`.

## The Three-Layer Model

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 0: VENDOR / RAW / STAGING                                     │
│ Goal: Isolate vendor quirks, minimal transforms                     │
│ Contains: Column mapping, dedup, type casts, basic filters          │
│ Location: STG_*, vendor secure views, raw shares                    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 1: CANONICAL (the contract layer)                             │
│ Goal: Single source of truth for all consumers                      │
│ Contains: PIT semantics, calendar alignment, peer definitions,      │
│           sampling rules, staleness flags, currency conventions     │
│ Location: CANONICAL.*, REFERENCE.*                                  │
│ Objects: Dynamic tables, tables, views (choose intentionally)       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 2: SERVING / MART (screen reads)                              │
│ Goal: Fast, denormalised, obvious objects for UI/MCP                │
│ Contains: Pre-joined, pre-aggregated views for specific use cases   │
│ Location: MART.*                                                    │
│ Rule: UIs never join raw vendor; MCP has tiered access (see below)  │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Placement Across Stores

This skill is the reference for **where data lives** across the platform. Keep it simple and avoid dual sources of truth.

| Store | Owns | Write path | Read path | Notes |
| --- | --- | --- | --- | --- |
| **Snowflake (QUINLAN)** | Market data, canonical semantics, serving surfaces | dbt + Snowpark jobs | API, notebooks | UI reads `MART.*` only; business logic stays in `CANONICAL.*` / `REFERENCE.*` |
| **Neon (Postgres)** | Operational ledger + workflow state | API/CLI only | API/projections | Evidence events, workflow events, run metadata, projections |
| **Azure Blob** | Artefact bytes (charts, PDFs, exports) | Backend/CLI | API | Metadata in Neon; no binaries in Postgres |
| **Local debug** | Ephemeral run artefacts | Local scripts | Local | `data/debug/{feature}/{run_id}/` is regenerable only |
| **Telemetry (planned)** | Client interaction logs | Local SQLite -> Snowflake | Snowflake | Keep separate from the evidence ledger |
| **Legacy PDF vault** | External corpus | External pipelines | External | Out of scope until a dedicated integration decision |

### Boundary Rules

- **Snowflake is the source of truth for market data.** The app reads it; it does not write to it.
- **Neon is the source of truth for operational evidence.** Do not mirror market data into Neon.
- **Artefact bytes live in Blob, not Postgres.** Store references (paths/hashes) in Neon.
- **Screening results live in Snowflake.** Only run metadata and references live in Neon.
- **AlphaSense locators are deferred.** Store only locators in evidence events once a format is agreed.

**Review-mode exception (Jeremy, Jan 2026):** evidence capture is temporarily filesystem-first under `workspaces/jeremy/evidence/`. Treat this as migratable staging, not a second source of truth.

## Decision Rubric: Where Does Logic Belong?

### Put it in Snowflake (SQL / Dynamic Tables / Tables) when:

| Criterion | Examples |
|-----------|----------|
| **Defines reality for the product** | PIT rules, calendar alignment, currency conventions, cohorts, sampling, staleness |
| **Must be identical across many consumers** | If UI, MCP, pack generator all touch it → Snowflake contract |
| **Set-based and scalable** | Joins, filters, window functions, aggregations, ranking |
| **Needs governance + observability** | Access control, lineage, consistent refresh SLAs |

### Put it in Python (client-side) when:

| Criterion | Examples |
|-----------|----------|
| **Exploratory or research-only for now** | Promote to Snowflake when it becomes screen-critical |
| **Produces artifacts** | PDFs, charts, narrative summaries, uploads |
| **Algorithmic, not relational** | Segmentation, changepoints, state machines, iterative smoothing |

**Promotion rule**: Once Python computes something the screen depends on, **materialise the result** back into Snowflake with `config_hash` and `run_id`.

### Use Snowpark (in-warehouse Python) when:

| Criterion | Examples |
|-----------|----------|
| **Belongs in Snowflake** (scale/governance) | Cross-sectional across thousands of entities |
| **But hard to express in SQL** | Iterative smoothing, recursive algorithms |
| **Would be slow to pull all rows** | TB-scale time series per entity |

**Best fit**: Vectorised Python UDTFs with `PARTITION BY entity_id` for per-entity transforms.

## Team Rules

### 1. Canonical Layer Rule

> If it affects *point-in-time correctness*, *time alignment*, *currency*, *universe membership*, or *cohort context*, it must be defined in CANONICAL/REFERENCE (not in UI, not in notebooks).

### 2. Promotion Rule for Python

> Python is allowed to be messy **until** a feature becomes a screen dependency.
> Once it is a dependency, the output becomes a versioned Snowflake table with `config_hash` and `run_id`.

### 3. Consumer Access Tiers

Different consumers get different access levels:

| Consumer | Access | Guardrails |
|----------|--------|------------|
| **UI** | MART only | Strict—no joins, no business logic |
| **Pack generator** | MART + selected CANONICAL | Controlled |
| **MCP (exploration)** | MART + CANONICAL | Required date bounds, row limits |
| **Notebooks** | All layers | Research mode, no production dependency |

> **Rationale**: MCP's value is "rolling around"—asking ad-hoc questions. If MCP can only read MART, you've reduced it to canned reports. But raw vendor tables should still be blocked.

### 4. Computational Shape Rule

> **Set-based** = SQL / dynamic tables
> **Per-entity iterative** = Snowpark vectorised UDTF *or* batch Python that writes results back
> **Artifact generation** = Python outside

## Truth Contracts vs Performance Helpers

Not all objects have the same governance:

| Type | Purpose | Change Velocity | Governance |
|------|---------|-----------------|------------|
| **Truth contract** | Defines canonical meaning | Slow | Versioned, reviewed |
| **Performance helper** | Clustering, intermediate rollups, lookup tables | Fast | Can change freely if contract outputs preserved |

Both live in Snowflake, but the distinction matters for reviews and migrations.

## Config + Run Tracking (High Leverage)

Every screen-critical derived table should include:

| Column | Answers |
|--------|---------|
| `config_hash` | "Which logic/parameters produced this?" |
| `run_id` | "Which execution run produced this?" |
| `computed_at` | "When was this computed?" |
| `source_data_max_date` | "How fresh were the inputs?" |

### CONFIGS Table

```sql
CREATE TABLE CANONICAL.CONFIGS (
    config_name     STRING NOT NULL,
    config_hash     STRING NOT NULL,
    config_json     VARIANT NOT NULL,
    code_version    STRING,
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    description     STRING,
    PRIMARY KEY (config_name, config_hash)
);
```

### RUNS Table (Input Watermarks)

```sql
CREATE TABLE CANONICAL.RUNS (
    run_id              STRING NOT NULL PRIMARY KEY,
    started_at          TIMESTAMP_NTZ NOT NULL,
    finished_at         TIMESTAMP_NTZ,
    code_version        STRING,
    config_hash         STRING,
    input_watermarks    VARIANT,  -- {"prices_max_date": "2024-06-28", ...}
    output_row_counts   VARIANT,  -- {"table_a": 12345, ...}
    status              STRING DEFAULT 'running',
    FOREIGN KEY (config_hash) REFERENCES CONFIGS(config_hash)
);
```

This answers both "which logic?" (config) and "which inputs?" (run watermarks).

## Object Type Selection

| Object Type | When to Use | Caveats |
|-------------|-------------|---------|
| **Dynamic Table** | Managed refresh, incremental possible, pure SQL transforms | See "expensive upstream" below |
| **Table** | Query patterns demand materialisation, expensive window functions | Requires refresh scheduling |
| **View** | Query is cheap, composable | Runs per-read |

### Dynamic Tables: The "Expensive Upstream" Caveat

> Dynamic Tables don't magically make expensive upstream scans cheap.

If the upstream source has:
- **Secure views** that block predicate pushdown
- **Poor clustering** relative to your filter patterns
- **No partition pruning** on common predicates

...then a Dynamic Table refresh will still scan everything.

**Practical rule**:
- **Materialise early** (as a Table) when upstream is expensive/opaque
- **Dynamic Tables shine** when inputs are already your own clustered tables and incremental deltas are tractable

## Snowflake Features to Know

### ASOF JOIN

For PIT joins where you need "latest value as of timestamp":

```sql
SELECT t.*, q.price
FROM trades t
ASOF JOIN quotes q
  MATCH_CONDITION (t.trade_time >= q.quote_time)
  ON t.symbol = q.symbol;
```

**Caveat**: ASOF JOIN is semantically cleaner for new use cases, but don't rip out existing working patterns (pre-computed lookup tables, explicit validity windows) just because ASOF exists. Evaluate performance before migrating.

### Vectorised Python UDTFs

For per-entity iterative transforms (exponential smoothing, state machines, etc.):

```python
@udtf(output_schema=..., packages=["pandas", "numpy"])
class IterativeCalculator:
    def __init__(self):
        self.data = []
        self.entity_id = None

    def process(self, entity_id, date, value):
        self.entity_id = entity_id
        self.data.append({"date": date, "value": value})

    def end_partition(self):
        df = pd.DataFrame(self.data)
        result = your_iterative_algorithm(df)
        for row in result.itertuples():
            yield (self.entity_id, row.date, row.output)
```

Call with `PARTITION BY entity_id`:
```sql
SELECT * FROM source_table,
TABLE(calculator(entity_id, date, value) OVER (PARTITION BY entity_id ORDER BY date));
```

## Progressive Disclosure

Load these for detailed patterns:
- `references/dbt-patterns.md` — **dbt project structure, ref/source, testing, MCP Server**
- `references/layer-patterns.md` — Layer examples (genericised)
- `references/snowpark-udtf-patterns.md` — Iterative algorithm patterns
- `references/production-checklist.md` — Launch readiness checklist
- `references/sql-organisation-patterns.md` — File structure, naming, dev workflow, testing
- `references/documentation-patterns.md` — Inline docs, COMMENT, verification queries

## Anti-Patterns to Avoid

| Anti-Pattern | Why It's Bad | Do Instead |
|--------------|--------------|------------|
| Business logic in UI | Diverges from canonical, untestable | Query serving layer |
| Same KPI computed differently per consumer | Reproducibility chaos | Single canonical table |
| Python result not materialised | Screen depends on notebook state | Write back with config_hash + run_id |
| No date filter on time-series queries | Full scans, $$$ | Always filter on `as_of_date` |
| Running deployments as ACCOUNTADMIN | Security risk | Use dedicated deploy role |
| Dynamic Table on expensive upstream | Refresh still scans everything | Materialise upstream first |
| Ripping out working patterns for new features | Untested migration risk | Use new patterns for new cases |
| **Hard-coded schema in dbt models** | Breaks dev/prod, defeats ref() | Use `{{ ref() }}` and `{{ source() }}` |
| **SELECT * in staging models** | Schema changes break downstream | Explicit column list |
| **No tests on canonical models** | Silent data quality issues | Add not_null, unique tests |
| **Giant monolithic SQL files** | Hard to test, understand, debug | Break into intermediate models |

## Role Separation (Fix Before Production)

```sql
-- Deploy role: can create/modify objects
CREATE ROLE IF NOT EXISTS {PROJECT}_DEPLOY;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON SCHEMA ... TO ROLE {PROJECT}_DEPLOY;

-- Reader role: UI/MCP service accounts
CREATE ROLE IF NOT EXISTS {PROJECT}_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA MART TO ROLE {PROJECT}_READER;
GRANT SELECT ON ALL VIEWS IN SCHEMA MART TO ROLE {PROJECT}_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MART TO ROLE {PROJECT}_READER;

-- MCP can also read CANONICAL (with guardrails)
GRANT SELECT ON ALL TABLES IN SCHEMA CANONICAL TO ROLE {PROJECT}_READER;
```

Never deploy as ACCOUNTADMIN once you have any shared access.
